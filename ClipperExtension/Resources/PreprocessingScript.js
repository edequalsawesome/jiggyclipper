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

        if (mainContent) {
            // Clone the content and remove unwanted nested elements
            var contentClone = mainContent.cloneNode(true);
            var removeSelectors = [
                'nav', 'footer', 'aside', 'header',
                'script', 'style', 'noscript', 'iframe',
                '.sidebar', '.side-bar', '.widget', '.widgets',
                '.comments', '.comment-section', '#comments',
                '.advertisement', '.ad', '.ads', '[class*="advert"]',
                '.social-share', '.share-buttons', '.sharing',
                '.related-posts', '.related-articles', '.recommended',
                '.newsletter', '.subscribe', '.subscription',
                '.author-bio', '.author-box',
                '.navigation', '.nav', '.menu', '.breadcrumb',
                '.tags', '.categories', '.meta-info',
                '[role="complementary"]', '[role="navigation"]'
            ];
            removeSelectors.forEach(function(selector) {
                try {
                    var elements = contentClone.querySelectorAll(selector);
                    elements.forEach(function(el) { el.remove(); });
                } catch(e) {}
            });
            result.contentHtml = contentClone.innerHTML;
        } else {
            // Fallback: get body without nav, footer, aside, header
            var body = document.body.cloneNode(true);
            var removeSelectors = ['nav', 'footer', 'aside', 'header', 'script', 'style', '.sidebar', '.comments', '.advertisement'];
            removeSelectors.forEach(function(selector) {
                var elements = body.querySelectorAll(selector);
                elements.forEach(function(el) { el.remove(); });
            });
            result.contentHtml = body.innerHTML;
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
