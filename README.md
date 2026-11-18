# LiteCast

**A light native launcher for macOS — search, snap windows, take notes, and peek the notch.**

Built from scratch in Swift 6 / SwiftUI / AppKit. No Electron, no accounts, no telemetry, no third-party runtime deps. Paper & Ink UI, Apple Silicon, macOS 14+.

<p align="center">
  <img src="LiteCast/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" alt="LiteCast icon">
</p>

## What it does

| Area | Highlights |
| --- | --- |
| **Launcher** | ⌥Space (customizable) · fuzzy app search · calculator · quicklinks · snippets · ⌘K actions |
| **Clipboard** | Opt-in history · text / link / image · ⇧⌘V panel · paste to the frontmost app |
| **Windows** | Opt-in snap · halves / thirds / quarters · maximize · center · restore (Accessibility) |
| **Notes** | Opt-in Markdown files · floating editor · plain `.md` on disk, no database |
| **Notch** | Hover expand · Now Playing · battery · file shelf |
| **Settings** | Hotkeys · launch at login · Dock / menu bar · per-feature toggles |

Most power features stay **off until you enable them**, so idle LiteCast stays light (~40 MB Release).

## Brand

LiteCast is its own product — not a fork or rebrand of anyone else’s launcher.

- **Paper / Ink** palette (warm paper, charcoal ink, sage accent)
- **⌘ + notch pill** app icon
- Bundle ID `com.dwimnofan.litecast`

## Build

Requirements: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -project LiteCast.xcodeproj -scheme LiteCast -configuration Release -derivedDataPath build build
open build/Build/Products/Release/LiteCast.app
```

Tests:

```sh
xcodebuild -project LiteCast.xcodeproj -scheme LiteCast -derivedDataPath build test
```

Local builds are ad-hoc signed. See [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md).

## License

[MIT](LICENSE) © 2026 dwimnofan
