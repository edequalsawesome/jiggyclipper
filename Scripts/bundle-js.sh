#!/bin/bash

# bundle-js.sh - Bundles the obsidian-clipper JavaScript for iOS
#
# This script:
# 1. Clones/updates the obsidian-clipper repo
# 2. Installs dependencies
# 3. Creates a webpack bundle optimized for JavaScriptCore
# 4. Copies the bundle to the extension resources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CLIPPER_DIR="$PROJECT_DIR/.clipper-source"
OUTPUT_FILE="$PROJECT_DIR/ClipperExtension/Resources/clipper-core.js"

echo "=== JiggyClipper JS Bundle Script ==="

# Clone or update obsidian-clipper
if [ -d "$CLIPPER_DIR" ]; then
    echo "Updating obsidian-clipper..."
    cd "$CLIPPER_DIR"
    git pull
else
    echo "Cloning obsidian-clipper..."
    git clone https://github.com/obsidianmd/obsidian-clipper.git "$CLIPPER_DIR"
    cd "$CLIPPER_DIR"
fi

# Install dependencies
echo "Installing dependencies..."
npm install

# Create iOS-specific webpack config
cat > webpack.ios.config.js << 'EOF'
const path = require('path');

module.exports = {
    mode: 'production',
    entry: './src/ios-entry.ts',
    output: {
        filename: 'clipper-core.js',
        path: path.resolve(__dirname, 'dist-ios'),
        library: {
            name: 'ObsidianClipper',
            type: 'var',
            export: 'default'
        }
    },
    resolve: {
        extensions: ['.ts', '.js'],
        fallback: {
            // Browser APIs not available in JavaScriptCore
            'fs': false,
            'path': false
        }
    },
    module: {
        rules: [
            {
                test: /\.ts$/,
                use: 'ts-loader',
                exclude: /node_modules/
            }
        ]
    },
    optimization: {
        minimize: true
    }
};
EOF

# Create iOS entry point that exports the needed functions
cat > src/ios-entry.ts << 'EOF'
// iOS entry point for JiggyClipper
// This bundles only the functions needed for the Share Extension

import Defuddle from 'defuddle';
import TurndownService from 'turndown';
import { gfm } from 'turndown-plugin-gfm';

// Import template system
// Note: These paths may need adjustment based on actual clipper structure
// import { compileTemplate } from './utils/template-compiler';
// import { applyFilters } from './utils/filters';

// Configure Turndown
const turndownService = new TurndownService({
    headingStyle: 'atx',
    bulletListMarker: '-',
    codeBlockStyle: 'fenced'
});
turndownService.use(gfm);

// Add custom rules similar to the extension
turndownService.addRule('highlight', {
    filter: 'mark',
    replacement: (content) => `==${content}==`
});

export interface ExtractedContent {
    title: string;
    url: string;
    content: string;
    contentHtml: string;
    author?: string;
    description?: string;
    domain: string;
    favicon?: string;
    image?: string;
    site?: string;
    date: string;
    time: string;
    published?: string;
    words: number;
    noteName: string;
}

export function extractContent(html: string, url: string): ExtractedContent {
    // Create a DOM parser (this may need polyfill in JSC)
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');

    // Use Defuddle to extract main content
    const defuddled = new Defuddle(doc, { url }).parse();

    // Convert to markdown
    const content = turndownService.turndown(defuddled.content || '');

    const parsedUrl = new URL(url);
    const now = new Date().toISOString();

    return {
        title: defuddled.title || doc.title || 'Untitled',
        url: url,
        content: content,
        contentHtml: defuddled.content || '',
        author: defuddled.author,
        description: defuddled.description,
        domain: parsedUrl.hostname,
        favicon: defuddled.favicon,
        image: defuddled.image,
        site: defuddled.site,
        date: now,
        time: now,
        published: defuddled.published,
        words: content.split(/\s+/).length,
        noteName: (defuddled.title || 'Untitled').replace(/[\\/:*?"<>|]/g, '')
    };
}

export function htmlToMarkdown(html: string): string {
    return turndownService.turndown(html);
}

export function renderTemplate(template: string, variables: Record<string, any>): string {
    let result = template;

    // Basic variable replacement
    for (const [key, value] of Object.entries(variables)) {
        const regex = new RegExp(`\\{\\{${key}\\}\\}`, 'g');
        const stringValue = value === null || value === undefined ? '' : String(value);
        result = result.replace(regex, stringValue);
    }

    // TODO: Add filter support
    // TODO: Add conditional support
    // TODO: Add loop support

    return result;
}

export function renderString(template: string, variables: Record<string, any>): string {
    return renderTemplate(template, variables);
}

export default {
    extractContent,
    htmlToMarkdown,
    renderTemplate,
    renderString
};
EOF

# Build the bundle
echo "Building iOS bundle..."
npx webpack --config webpack.ios.config.js

# Copy to extension resources
echo "Copying bundle to extension..."
cp dist-ios/clipper-core.js "$OUTPUT_FILE"

echo "=== Bundle complete ==="
echo "Output: $OUTPUT_FILE"
