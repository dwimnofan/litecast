# LiteCast — agent notes

Personal native macOS launcher + Dynamic Notch. Full blueprint: `docs/BLUEPRINT.md` (paste the handoff doc there).

## Hard rules
- Deployment target **macOS 14.0**, arm64, Swift 6 (strict concurrency complete). Don't raise it without asking.
- No private APIs. No third-party runtime deps without a written rationale + macOS 14 + license check.
- TinyCast by abue-ammar (AGPL-3.0) and Boring Notch (GPL-3.0) are **references only**. Don't copy their code or assets.
- One milestone at a time. No placeholder features that pretend to work.
- Keep UI, domain logic (`Core/`), and platform code (`Platform/`) apart. Shell/exec only through the command executor.
- Ask for permissions only when a feature needs them.

## Build & test
```sh
xcodegen generate                      # project.yml -> LiteCast.xcodeproj (don't hand-edit the pbxproj)
xcodebuild -project LiteCast.xcodeproj -scheme LiteCast -derivedDataPath build test
open build/Build/Products/Debug/LiteCast.app
log show --info --last 5m --predicate 'subsystem == "com.dwimnofan.litecast"'
```

## Layout
- `LiteCast/App/` — entry point (`MenuBarExtra` + `Settings` scene), `AppDelegate`, `AppEnvironment` (owns services).
- `LiteCast/Infrastructure/` — preferences (UserDefaults), logging (`os.Logger`).
- `Tests/LiteCastCoreTests/` — XCTest, hosted in the app.
Add other folders from the blueprint only when their feature starts.

## Status
- Milestone 0 done: app launches on macOS 14.6, menu bar item (Settings, Quit), Dock-visibility preference, clean quit.
- Milestone 1 code done (⌥Space launcher, app search, fuzzy ranking); awaiting manual keyboard test.
- Research for Milestone 2/4: docs/research/notch-and-media-macos14.md (unverified).

## Extension points (read before adding a feature)
- **Search results:** implement `SearchProvider` (`Core/Search/SearchResult.swift`), return `[]` for queries you don't handle, add it to the `providers` array in `AppEnvironment`. Score with `FuzzyMatcher`/`SearchEngine.rank`; > 1000 pins to top.
- **Actions:** results carry a `SearchAction`; only `CommandExecutor` executes them. Built-in commands: add a case to `BuiltinCommand`, `executor.register(...)` it in `AppEnvironment`; it appears in search only once registered.
- **Persistence:** `JSONFileStore<T>` (Application Support/LiteCast/*.json).
- **Settings:** add a tab in `App/SettingsView.swift`.
- **Tests:** the app is the test host; `AppDelegate.isRunningTests` skips hotkey/alerts. Agents must not drive keyboard/mouse on this Mac (the owner is using it) — verify with build + unit tests.
