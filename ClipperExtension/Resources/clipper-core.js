// clipper-core.js - Placeholder until bundle-js.sh is run
// This provides basic functionality for testing

var ObsidianClipper = {
    extractContent: function(html, url) {
        // Basic content extraction
        var titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
        var title = titleMatch ? titleMatch[1].trim() : 'Untitled';

        // Extract meta description
        var descMatch = html.match(/<meta[^>]*name=["']description["'][^>]*content=["']([^"']+)["']/i);
        if (!descMatch) {
            descMatch = html.match(/<meta[^>]*content=["']([^"']+)["'][^>]*name=["']description["']/i);
        }
        var description = descMatch ? descMatch[1] : '';

        // Extract author
        var authorMatch = html.match(/<meta[^>]*name=["']author["'][^>]*content=["']([^"']+)["']/i);
        var author = authorMatch ? authorMatch[1] : '';

        // Extract OG image
        var imageMatch = html.match(/<meta[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']/i);
        var image = imageMatch ? imageMatch[1] : '';

        // Basic body extraction (strip scripts and styles)
        var bodyMatch = html.match(/<body[^>]*>([\s\S]*)<\/body>/i);
        var bodyHtml = bodyMatch ? bodyMatch[1] : html;

        // Remove scripts, styles, and common non-content elements
        bodyHtml = bodyHtml.replace(/<script[\s\S]*?<\/script>/gi, '');
        bodyHtml = bodyHtml.replace(/<style[\s\S]*?<\/style>/gi, '');
        bodyHtml = bodyHtml.replace(/<nav[\s\S]*?<\/nav>/gi, '');
        bodyHtml = bodyHtml.replace(/<footer[\s\S]*?<\/footer>/gi, '');
        bodyHtml = bodyHtml.replace(/<header[\s\S]*?<\/header>/gi, '');
        bodyHtml = bodyHtml.replace(/<aside[\s\S]*?<\/aside>/gi, '');
        bodyHtml = bodyHtml.replace(/<!--[\s\S]*?-->/g, '');

        // Try to find main content
        var mainMatch = bodyHtml.match(/<main[^>]*>([\s\S]*)<\/main>/i);
        var articleMatch = bodyHtml.match(/<article[^>]*>([\s\S]*)<\/article>/i);

        if (articleMatch) {
            bodyHtml = articleMatch[1];
        } else if (mainMatch) {
            bodyHtml = mainMatch[1];
        }

        // Convert to markdown
        var content = this.htmlToMarkdown(bodyHtml);

        // Parse URL for domain
        var domain = '';
        try {
            var urlObj = new URL(url);
            domain = urlObj.hostname;
        } catch (e) {
            domain = url.replace(/^https?:\/\//, '').split('/')[0];
        }

        var now = new Date().toISOString();

        return {
            title: title,
            url: url,
            content: content,
            contentHtml: bodyHtml,
            author: author,
            description: description,
            domain: domain,
            image: image,
            date: now,
            time: now,
            words: content.split(/\s+/).filter(function(w) { return w.length > 0; }).length,
            noteName: title.replace(/[\\/:*?"<>|]/g, '').trim()
        };
    },

    htmlToMarkdown: function(html) {
        var md = html;

        // Headers
        md = md.replace(/<h1[^>]*>([\s\S]*?)<\/h1>/gi, '\n# $1\n');
        md = md.replace(/<h2[^>]*>([\s\S]*?)<\/h2>/gi, '\n## $1\n');
        md = md.replace(/<h3[^>]*>([\s\S]*?)<\/h3>/gi, '\n### $1\n');
        md = md.replace(/<h4[^>]*>([\s\S]*?)<\/h4>/gi, '\n#### $1\n');
        md = md.replace(/<h5[^>]*>([\s\S]*?)<\/h5>/gi, '\n##### $1\n');
        md = md.replace(/<h6[^>]*>([\s\S]*?)<\/h6>/gi, '\n###### $1\n');

        // Paragraphs and divs
        md = md.replace(/<p[^>]*>([\s\S]*?)<\/p>/gi, '\n$1\n');
        md = md.replace(/<div[^>]*>([\s\S]*?)<\/div>/gi, '\n$1\n');

        // Bold and italic
        md = md.replace(/<strong[^>]*>([\s\S]*?)<\/strong>/gi, '**$1**');
        md = md.replace(/<b[^>]*>([\s\S]*?)<\/b>/gi, '**$1**');
        md = md.replace(/<em[^>]*>([\s\S]*?)<\/em>/gi, '*$1*');
        md = md.replace(/<i[^>]*>([\s\S]*?)<\/i>/gi, '*$1*');

        // Highlights
        md = md.replace(/<mark[^>]*>([\s\S]*?)<\/mark>/gi, '==$1==');

        // Links
        md = md.replace(/<a[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi, '[$2]($1)');

        // Images
        md = md.replace(/<img[^>]*src=["']([^"']+)["'][^>]*alt=["']([^"']*)["'][^>]*\/?>/gi, '![$2]($1)');
        md = md.replace(/<img[^>]*alt=["']([^"']*)["'][^>]*src=["']([^"']+)["'][^>]*\/?>/gi, '![$1]($2)');
        md = md.replace(/<img[^>]*src=["']([^"']+)["'][^>]*\/?>/gi, '![]($1)');

        // Lists
        md = md.replace(/<li[^>]*>([\s\S]*?)<\/li>/gi, '- $1\n');
        md = md.replace(/<ul[^>]*>([\s\S]*?)<\/ul>/gi, '\n$1');
        md = md.replace(/<ol[^>]*>([\s\S]*?)<\/ol>/gi, '\n$1');

        // Blockquotes
        md = md.replace(/<blockquote[^>]*>([\s\S]*?)<\/blockquote>/gi, function(match, content) {
            return '\n> ' + content.trim().replace(/\n/g, '\n> ') + '\n';
        });

        // Code
        md = md.replace(/<code[^>]*>([\s\S]*?)<\/code>/gi, '`$1`');
        md = md.replace(/<pre[^>]*>([\s\S]*?)<\/pre>/gi, '\n```\n$1\n```\n');

        // Line breaks and horizontal rules
        md = md.replace(/<br\s*\/?>/gi, '\n');
        md = md.replace(/<hr\s*\/?>/gi, '\n---\n');

        // Remove remaining HTML tags
        md = md.replace(/<[^>]+>/g, '');

        // Decode HTML entities
        md = md.replace(/&nbsp;/g, ' ');
        md = md.replace(/&amp;/g, '&');
        md = md.replace(/&lt;/g, '<');
        md = md.replace(/&gt;/g, '>');
        md = md.replace(/&quot;/g, '"');
        md = md.replace(/&#39;/g, "'");
        md = md.replace(/&rsquo;/g, "'");
        md = md.replace(/&lsquo;/g, "'");
        md = md.replace(/&rdquo;/g, '"');
        md = md.replace(/&ldquo;/g, '"');
        md = md.replace(/&mdash;/g, '—');
        md = md.replace(/&ndash;/g, '–');
        md = md.replace(/&hellip;/g, '...');

        // Clean up whitespace
        md = md.replace(/\n{3,}/g, '\n\n');
        md = md.replace(/[ \t]+\n/g, '\n');
        md = md.trim();

        return md;
    },

    renderTemplate: function(templateContent, variables) {
        var result = templateContent;

        // Replace simple variables like {{title}}, {{url}}, etc.
        for (var key in variables) {
            if (variables.hasOwnProperty(key)) {
                var value = variables[key];
                if (value === null || value === undefined) {
                    value = '';
                } else if (typeof value === 'object') {
                    value = JSON.stringify(value);
                }
                var regex = new RegExp('\\{\\{\\s*' + key + '\\s*\\}\\}', 'g');
                result = result.replace(regex, String(value));
            }
        }

        // Handle basic filters
        // Format: {{variable|filter}} or {{variable|filter:arg}}
        result = result.replace(/\{\{([^|}]+)\|([^}]+)\}\}/g, function(match, varName, filterChain) {
            var value = variables[varName.trim()];
            if (value === null || value === undefined) {
                return '';
            }

            var filters = filterChain.split('|');
            for (var i = 0; i < filters.length; i++) {
                var filterParts = filters[i].trim().split(':');
                var filterName = filterParts[0].trim();
                var filterArg = filterParts[1] ? filterParts[1].trim().replace(/^["']|["']$/g, '') : null;

                value = ObsidianClipper.applyFilter(value, filterName, filterArg);
            }

            return String(value);
        });

        // Handle conditionals: {% if variable %}...{% endif %}
        result = result.replace(/\{%\s*if\s+(\w+)\s*%\}([\s\S]*?)\{%\s*endif\s*%\}/g, function(match, varName, content) {
            var value = variables[varName];
            if (value && value !== '' && value !== '0' && value !== 'false') {
                return content;
            }
            return '';
        });

        // Handle for loops: {% for item in array %}...{% endfor %}
        result = result.replace(/\{%\s*for\s+(\w+)\s+in\s+(\w+)\s*%\}([\s\S]*?)\{%\s*endfor\s*%\}/g, function(match, itemVar, arrayVar, content) {
            var arr = variables[arrayVar];
            if (!Array.isArray(arr)) {
                return '';
            }

            var output = '';
            for (var i = 0; i < arr.length; i++) {
                var itemContent = content;
                var item = arr[i];

                if (typeof item === 'object') {
                    for (var prop in item) {
                        var propRegex = new RegExp('\\{\\{\\s*' + itemVar + '\\.' + prop + '\\s*\\}\\}', 'g');
                        itemContent = itemContent.replace(propRegex, String(item[prop]));
                    }
                } else {
                    var itemRegex = new RegExp('\\{\\{\\s*' + itemVar + '\\s*\\}\\}', 'g');
                    itemContent = itemContent.replace(itemRegex, String(item));
                }

                output += itemContent;
            }
            return output;
        });

        return result;
    },

    applyFilter: function(value, filterName, arg) {
        if (value === null || value === undefined) {
            return '';
        }

        var strValue = String(value);

        switch (filterName) {
            case 'upper':
                return strValue.toUpperCase();
            case 'lower':
                return strValue.toLowerCase();
            case 'capitalize':
                return strValue.charAt(0).toUpperCase() + strValue.slice(1);
            case 'title':
                return strValue.replace(/\b\w/g, function(c) { return c.toUpperCase(); });
            case 'trim':
                return strValue.trim();
            case 'slice':
                if (arg) {
                    var parts = arg.split(',');
                    var start = parseInt(parts[0]) || 0;
                    var end = parts[1] ? parseInt(parts[1]) : undefined;
                    return strValue.slice(start, end);
                }
                return strValue;
            case 'replace':
                if (arg) {
                    var replaceParts = arg.split(':');
                    if (replaceParts.length >= 2) {
                        var search = replaceParts[0].replace(/^["']|["']$/g, '');
                        var replacement = replaceParts[1].replace(/^["']|["']$/g, '');
                        return strValue.replace(new RegExp(search, 'g'), replacement);
                    }
                }
                return strValue;
            case 'date':
                try {
                    var date = new Date(value);
                    if (arg === 'YYYY-MM-DD' || !arg) {
                        return date.toISOString().split('T')[0];
                    }
                    // Basic format support
                    return date.toLocaleDateString();
                } catch (e) {
                    return strValue;
                }
            case 'wikilink':
                return '[[' + strValue + ']]';
            case 'link':
                return '[' + strValue + ']';
            case 'blockquote':
                return '> ' + strValue.replace(/\n/g, '\n> ');
            case 'callout':
                var calloutType = arg || 'info';
                return '> [!' + calloutType + ']\n> ' + strValue.replace(/\n/g, '\n> ');
            case 'safe_name':
                return strValue.replace(/[\\/:*?"<>|]/g, '');
            case 'kebab':
                return strValue.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
            case 'snake':
                return strValue.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '');
            case 'camel':
                return strValue.replace(/(?:^\w|[A-Z]|\b\w)/g, function(word, index) {
                    return index === 0 ? word.toLowerCase() : word.toUpperCase();
                }).replace(/\s+/g, '');
            case 'length':
                return strValue.length;
            default:
                return strValue;
        }
    },

    renderString: function(templateString, variables) {
        return this.renderTemplate(templateString, variables);
    }
};
