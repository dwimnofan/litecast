# LiteCast

Personal native macOS launcher + notch app (inspired by, but independent from, TinyCast and Boring Notch). macOS 14+, Apple Silicon, Swift 6 / SwiftUI / AppKit, no third-party packages.

## Features
- Launcher on a global hotkey (default ⌥Space, customizable): fuzzy app search and built-in commands, fully keyboard driven, VoiceOver labels.
- Menu bar item (Open Launcher, Settings, Quit); optional Dock icon.
- Settings > General: launcher on/off, shortcut recorder with reset, launch at login, Dock visibility.

## Build and run
Requirements: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -project LiteCast.xcodeproj -scheme LiteCast -derivedDataPath build test
open build/Build/Products/Debug/LiteCast.app
```

The build is ad-hoc signed and local only. See `docs/KNOWN_LIMITATIONS.md` and `AGENTS.md` (project rules, extension points).
