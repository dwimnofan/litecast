# TinyCast — agent notes

Personal native macOS launcher + Dynamic Notch. Full blueprint: `docs/BLUEPRINT.md` (paste the handoff doc there).

## Hard rules
- Deployment target **macOS 14.0**, arm64, Swift 6 (strict concurrency complete). Don't raise it without asking.
- No private APIs. No third-party runtime deps without a written rationale + macOS 14 + license check.
- TinyCast (AGPL-3.0) and Boring Notch (GPL-3.0) are **references only**. Don't copy their code or assets.
- One milestone at a time. No placeholder features that pretend to work.
- Keep UI, domain logic (`Core/`), and platform code (`Platform/`) apart. Shell/exec only through the command executor.
- Ask for permissions only when a feature needs them.

## Build & test
```sh
xcodegen generate                      # project.yml -> TinyCast.xcodeproj (don't hand-edit the pbxproj)
xcodebuild -project TinyCast.xcodeproj -scheme TinyCast -derivedDataPath build test
open build/Build/Products/Debug/TinyCast.app
log show --info --last 5m --predicate 'subsystem == "com.dwimnofan.tinycast"'
```

## Layout
- `TinyCast/App/` — entry point (`MenuBarExtra` + `Settings` scene), `AppDelegate`, `AppEnvironment` (owns services).
- `TinyCast/Infrastructure/` — preferences (UserDefaults), logging (`os.Logger`).
- `Tests/TinyCastCoreTests/` — XCTest, hosted in the app.
Add other folders from the blueprint only when their feature starts.

## Status
- Milestone 0 done: app launches on macOS 14.6, menu bar item (Settings, Quit), Dock-visibility preference, clean quit.
- Next: Milestone 1 (launcher MVP).
