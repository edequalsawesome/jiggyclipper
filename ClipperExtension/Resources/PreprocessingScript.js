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

        // Try to extract main content (basic heuristics)
        var mainContent = document.querySelector('article') ||
                          document.querySelector('main') ||
                          document.querySelector('[role="main"]') ||
                          document.querySelector('.post-content') ||
                          document.querySelector('.article-content') ||
                          document.querySelector('.entry-content');

        if (mainContent) {
            result.contentHtml = mainContent.innerHTML;
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
