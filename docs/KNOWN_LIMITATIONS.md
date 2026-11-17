# Known limitations

- **Media (notch):** on macOS 14 the public APIs only allow controlling Music and Spotify (via scripting). System-wide Now Playing needs private APIs, which this project does not use.
- **Hotkeys use Carbon `RegisterEventHotKey`:** no Accessibility permission needed, but a combo already taken by the system or another app fails to register (LiteCast shows an error and keeps the previous shortcut). Shortcuts need at least one of ⌘ ⌥ ⌃. macOS reserves some combos (e.g. ⌘Space for Spotlight).
- **Unsigned local build:** ad-hoc signed, no notarization; Gatekeeper may warn if the app is copied elsewhere. No App Sandbox.
- **Launch at login:** uses `SMAppService.mainApp`; it works best from a stable location (e.g. /Applications). Ad-hoc signed builds may land in `requiresApproval` and need a toggle in System Settings > Login Items.
- **No auto-update:** no Sparkle; rebuild and replace the app manually.
- **JSON persistence:** user data lives in Application Support/LiteCast/*.json with no migration or sync; preferences are in UserDefaults.
- **Not covered by automated tests:** global hotkey registration and the shortcut recorder UI are verified only manually.
