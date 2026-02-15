// PreprocessingScript.js
// This runs in Safari's page context and can access the full DOM
// including content behind authentication

var JiggyClipperPreprocessor = function() {};

JiggyClipperPreprocessor.prototype = {
    run: function(arguments) {
        // Extract content from the current page
        var result = {
            url: document.URL,
            title: document.title,
            html: document.documentElement.outerHTML,
            selectedHtml: ""
        };

        // Get selected text if any
        var selection = window.getSelection();
        if (selection && selection.rangeCount > 0) {
            var container = document.createElement("div");
            for (var i = 0; i < selection.rangeCount; i++) {
                container.appendChild(selection.getRangeAt(i).cloneContents());
            }
            result.selectedHtml = container.innerHTML;
        }

        // Extract metadata
        var metaTags = document.querySelectorAll('meta');
        var meta = {};
        metaTags.forEach(function(tag) {
            var name = tag.getAttribute('name') || tag.getAttribute('property');
            var content = tag.getAttribute('content');
            if (name && content) {
                meta[name] = content;
            }
        });
        result.meta = meta;

        // Extract author
        result.author = meta['author'] ||
                        meta['article:author'] ||
                        meta['og:article:author'] ||
                        '';

        // Extract description
        result.description = meta['description'] ||
                             meta['og:description'] ||
                             meta['twitter:description'] ||
                             '';

        // Extract published date
        result.published = meta['article:published_time'] ||
                           meta['og:article:published_time'] ||
                           meta['datePublished'] ||
                           '';

        // Extract image
        result.image = meta['og:image'] ||
                       meta['twitter:image'] ||
                       '';

        // Extract site name
        result.site = meta['og:site_name'] || '';

        // Try to extract main content with better heuristics
        // Priority order: most specific content classes first
        var contentSelectors = [
            // Specific content container classes (highest priority)
            '.post-content',
            '.article-content',
            '.entry-content',
            '.content-body',
            '.article-body',
            '.post-body',
            '.story-body',
            '.main-content',
            '.page-content',
            '.single-content',
            // WordPress specific
            '.wp-block-post-content',
            '.hentry .entry-content',
            // Medium
            'article section',
            // Substack
            '.post-content-wrapper',
            '.body.markup',
            // Daring Fireball and similar blogs
            '.article',
            '.linkedlist',
            '#Main',
            // Generic article within main
            'main article',
            'article[role="article"]',
            // Then try broader selectors
            'article',
            'main',
            '[role="main"]',
            '#content',
            '#main-content',
            '.content'
        ];

        var mainContent = null;
        for (var i = 0; i < contentSelectors.length; i++) {
            var el = document.querySelector(contentSelectors[i]);
            if (el) {
                mainContent = el;
                break;
            }
        }

        // Comprehensive list of elements to remove
        var removeSelectors = [
            'nav', 'footer', 'aside', 'header',
            'script', 'style', 'noscript', 'iframe', 'svg',
            '.sidebar', '.side-bar', '.widget', '.widgets',
            '.comments', '.comment-section', '#comments',
            '.advertisement', '.ad', '.ads', '[class*="advert"]', '[id*="advert"]',
            '.social-share', '.share-buttons', '.sharing',
            '.related-posts', '.related-articles', '.recommended',
            '.newsletter', '.subscribe', '.subscription',
            '.author-bio', '.author-box',
            '.navigation', '.nav', '.menu', '.breadcrumb',
            '.tags', '.categories', '.meta-info',
            '[role="complementary"]', '[role="navigation"]', '[role="banner"]',
            // Common header/footer/nav elements
            '#header', '#footer', '#nav', '#navigation', '#sidebar',
            '.header', '.footer', '.nav', '.navigation',
            // Sponsorship and ads
            '[class*="sponsor"]', '[id*="sponsor"]', '.martini',
            // Links that are likely navigation
            '[class*="menu"]', '[class*="Menu"]',
            // Display preferences and such
            '[class*="preference"]', '[id*="preference"]',
            // Copyright notices (usually in footer)
            '.copyright', '#copyright',
            // Logo containers
            '.logo', '#logo', '[class*="logo"]'
        ];

        function cleanElement(element) {
            removeSelectors.forEach(function(selector) {
                try {
                    var elements = element.querySelectorAll(selector);
                    elements.forEach(function(el) { el.remove(); });
                } catch(e) {}
            });

            // Remove elements that are mostly links (likely navigation)
            var allDivs = element.querySelectorAll('div, ul, section');
            allDivs.forEach(function(div) {
                var links = div.querySelectorAll('a');
                var textLength = (div.textContent || '').trim().length;
                var linkTextLength = 0;
                links.forEach(function(a) { linkTextLength += (a.textContent || '').length; });
                // If more than 80% of text is links and it's small, it's probably nav
                if (textLength < 500 && linkTextLength > textLength * 0.8 && links.length > 3) {
                    div.remove();
                }
            });

            // Remove elements with copyright text
            var allElements = element.querySelectorAll('*');
            allElements.forEach(function(el) {
                var text = (el.textContent || '').toLowerCase();
                if (text.includes('copyright ©') || text.includes('all rights reserved') ||
                    text.match(/^©\s*\d{4}/) || text.includes('display preferences')) {
                    if ((el.textContent || '').length < 200) {
                        el.remove();
                    }
                }
            });

            return element;
        }

        if (mainContent) {
            // Clone and clean the content
            var contentClone = mainContent.cloneNode(true);
            cleanElement(contentClone);
            result.contentHtml = contentClone.innerHTML;
        } else {
            // Fallback: Try to find the element with the most paragraph content
            var candidates = document.querySelectorAll('div, section');
            var bestCandidate = null;
            var bestScore = 0;

            candidates.forEach(function(candidate) {
                var paragraphs = candidate.querySelectorAll('p, blockquote');
                var textLength = 0;
                paragraphs.forEach(function(p) { textLength += (p.textContent || '').length; });
                // Penalize elements with lots of nav-like children
                var navElements = candidate.querySelectorAll('nav, .nav, .menu, header, footer');
                var score = textLength - (navElements.length * 500);
                if (score > bestScore) {
                    bestScore = score;
                    bestCandidate = candidate;
                }
            });

            if (bestCandidate && bestScore > 500) {
                var contentClone = bestCandidate.cloneNode(true);
                cleanElement(contentClone);
                result.contentHtml = contentClone.innerHTML;
            } else {
                // Last resort: clean the body
                var body = document.body.cloneNode(true);
                cleanElement(body);
                result.contentHtml = body.innerHTML;
            }
        }

        // Pass the result back to the extension
        arguments.completionFunction(result);
    },

    finalize: function(arguments) {
        // Called after the extension processes the data
        // We don't need to do anything here
    }
};

var ExtensionPreprocessingJS = new JiggyClipperPreprocessor();
