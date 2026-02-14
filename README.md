# JiggyClipper

iOS Share Extension for clipping web pages to Obsidian, based on the [Obsidian Web Clipper](https://github.com/obsidianmd/obsidian-clipper).

## Setup

### 1. Open in Xcode

```bash
open JiggyClipper.xcodeproj
```

### 2. Configure Signing

1. Select the project in the navigator
2. Select the **JiggyClipper** target
3. Go to **Signing & Capabilities**
4. Select your Development Team
5. Repeat for the **ClipperExtension** target

### 3. Configure App Group (if needed)

The App Group `group.com.edequalsawesome.jiggyclipper` is already configured in the entitlements. If you need to change it:

1. Update both `.entitlements` files
2. Update `SharedConstants.swift`

### 4. Build & Run

1. Select an iOS Simulator or device
2. Build and run (Cmd+R)
3. The app will install with the Share Extension

## Usage

1. Open Safari and navigate to any webpage
2. Tap the Share button
3. Select "Clip to Obsidian" from the share sheet
4. Choose a template and preview the clip
5. Tap "Clip" to send to Obsidian

## Features

### Templates
- Import templates from the browser extension (JSON format)
- Create custom templates with variables:
  - `{{title}}` - Page title
  - `{{url}}` - Page URL
  - `{{content}}` - Article content (Markdown)
  - `{{author}}` - Author name
  - `{{description}}` - Meta description
  - `{{date}}` - Current date
  - `{{domain}}` - Website domain

### Filters
Basic filter support:
- `{{title | upper}}` - Uppercase
- `{{title | lower}}` - Lowercase
- `{{content | slice:0,500}}` - Truncate
- `{{date | date:"YYYY-MM-DD"}}` - Format date
- `{{title | wikilink}}` - Convert to `[[wikilink]]`
- `{{content | callout:note}}` - Wrap in callout

### AI Providers
Configure LLM providers for `{{prompt:...}}` variables:
- Anthropic (Claude)
- OpenAI
- Ollama (local)
- OpenRouter

## Bundling Full Clipper JS (Optional)

The app includes a basic JS implementation. For full feature parity with the browser extension:

```bash
./Scripts/bundle-js.sh
```

This clones obsidian-clipper and creates a webpack bundle with:
- Defuddle (content extraction)
- Turndown (HTML to Markdown)
- Full template engine
- All 48+ filters

## Project Structure

```
JiggyClipper/
├── JiggyClipper/           # Main app target
│   ├── App/                # App entry point
│   ├── Views/              # SwiftUI views
│   └── Services/           # Business logic
├── ClipperExtension/       # Share Extension target
│   ├── ClipperUI/          # Extension UI
│   ├── Engine/             # Clipping engine
│   └── Resources/          # JS bundle
└── Shared/                 # Shared code
    ├── Models/             # Data models
    └── Storage/            # App Group storage
```

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Obsidian for iOS (for receiving clips)

## License

Personal use. Based on [Obsidian Web Clipper](https://github.com/obsidianmd/obsidian-clipper) (MIT License).
