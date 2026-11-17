# Dynamic Notch Geometry, Windowing, and Media Control on macOS 14 (Sonoma)

**Target Environment:** macOS 14.0+ (Sonoma), Apple Silicon (M2), Swift 6 (Strict Concurrency).  
**Strict Constraint:** Public Apple APIs only — zero private frameworks/SPI, zero third-party dependencies.

---

## 1. Notch Geometry Detection & Screen Handling

### 1.1 Detection and Rect Computation via Public API
Introduced in macOS 12.0 Monterey ([WWDC21 Session 10047: What's new in AppKit](https://developer.apple.com/videos/play/wwdc2021/10047/)), `NSScreen` exposes safe area insets and auxiliary bounding areas flanking the camera housing:

- [`safeAreaInsets: NSEdgeInsets`](https://developer.apple.com/documentation/appkit/nsscreen/3882855-safeareainsets) (macOS 12.0+): Top inset `> 0` indicates camera housing obstruction (typically 32–44 pt). On screens without a cutout, all insets are `0`.
- [`auxiliaryTopLeftArea: NSRect?`](https://developer.apple.com/documentation/appkit/nsscreen/3882853-auxiliarytopleftarea) & [`auxiliaryTopRightArea: NSRect?`](https://developer.apple.com/documentation/appkit/nsscreen/3882854-auxiliarytoprightarea) (macOS 12.0+): Bounding boxes of usable screen real estate to the left and right of the notch in screen coordinates. Return `nil` (or zero rect) when no cutout exists.

```swift
import AppKit

extension NSScreen {
    var hasNotch: Bool { safeAreaInsets.top > 0 }

    /// Computed notch frame in AppKit coordinates (bottom-left origin).
    var notchFrame: NSRect? {
        guard safeAreaInsets.top > 0,
              let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea else { return nil }
        let notchX = left.maxX
        let notchWidth = right.minX - left.maxX
        let notchHeight = safeAreaInsets.top
        let notchY = frame.maxY - notchHeight
        return NSRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
    }
}
```

### 1.2 Identifying Built-in Displays
Avoid parsing `screen.localizedName` (unreliable across system languages/display configs). Use CoreGraphics display query:
- [`CGDisplayIsBuiltin(_:)`](https://developer.apple.com/documentation/coregraphics/1454526-cgdisplayisbuiltin):
  ```swift
  extension NSScreen {
      var isBuiltIn: Bool {
          guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
          return CGDisplayIsBuiltin(screenNumber) != 0
      }
  }
  ```

### 1.3 Display Edge Cases
- **External Displays:** `safeAreaInsets.top == 0` and `auxiliaryTop*Area == nil`. The app must fall back to a floating pill (see Section 5).
- **Clamshell Mode:** When a MacBook lid is closed with external monitors attached, the internal screen is powered down and omitted from `NSScreen.screens`.
- **Auto-Hiding Menu Bar:** `safeAreaInsets.top` remains constant (> 0) because hardware notch dimensions never change. However, `screen.visibleFrame.maxY` extends up to `screen.frame.maxY`.
- **Fullscreen Apps & Compatibility Mode:** In `Info.plist`, set `NSPrefersDisplaySafeAreaCompatibilityMode` to `false` to prevent the OS from letterboxing windows below the notch.

---

## 2. Notch Panel Windowing Architecture

### 2.1 Recommended `NSPanel` Setup
The floating notch overlay must draw above the menu bar, survive Space switches, and avoid stealing focus:

```swift
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        // Level above status bar and menu bar (level 25 or popUpMenu 101)
        self.level = .statusBar
        // Maintain presence across fullscreen apps and Spaces
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isMovable = false
        self.isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { false } // Prevent stealing focus unless typing is active
    override var canBecomeMain: Bool { false }
}
```

### 2.2 Mouse Tracking & Hover Expansion
- **Collapsed state:** Set `ignoresMouseEvents = false` only over the notch pill. Using a custom root view with `NSTrackingArea(rect:options:owner:userInfo:)` (`[.mouseEnteredAndExited, .activeAlways, .inVisibleRect]`) triggers expansion on hover and collapses on exit with a ~200ms debounce.
- **Pass-through on flanks:** Subclass `NSView` and override `hitTest(_:)` to return `nil` for coordinates outside the dynamic pill, allowing clicks to pass through to status icons / menu bar beneath.

### 2.3 Screen Parameter Notifications
Observe [`NSApplication.didChangeScreenParametersNotification`](https://developer.apple.com/documentation/appkit/nsapplication/1428728-didchangescreenparametersnotific) to adjust geometry on display connect/disconnect, resolution/scaling changes, or clamshell transitions.

---

## 3. Media & "Now Playing" on macOS 14 (Public vs Private APIs)

### 3.1 What Public APIs Can and Cannot Do
| API / Mechanism | Read Metadata (Title, Artist, Artwork) | Transport Control (Play/Pause/Skip) | System-Wide? | Public Status & Permissions |
| :--- | :--- | :--- | :--- | :--- |
| **MediaPlayer (`MPNowPlayingInfoCenter`)** | ❌ No (returns `nil` for other apps) | ❌ No | N/A | **Public** (macOS 10.12.2+). For *publishing* host app state only. |
| **MediaPlayer (`MPRemoteCommandCenter`)** | ❌ No | ❌ No | N/A | **Public** (macOS 10.12.2+). For *receiving* commands only. |
| **MediaRemote.framework** | ✅ Yes (`MRMediaRemoteGetNowPlayingInfo`) | ✅ Yes | ✅ System-wide | **PRIVATE SPI**. Banned for LiteCast. Broken in macOS 15.4. |
| **AppleScript / ScriptingBridge** | ✅ Yes (Music.app & Spotify) | ✅ Yes | ❌ Per-app | **Public**. Needs `NSAppleEventsUsageDescription`. |
| **Synthetic Media Keys (`CGEvent`/`NSEvent`)** | ❌ No | ✅ Yes (Blind toggle) | ✅ System-wide | **Public**. Needs Accessibility permission. |

### 3.2 The MediaRemote.framework Reality Check
- `MediaRemote.framework` has **always been private SPI**.
- **What happened in macOS 15.4:** Apple enforced strict entitlement checks on the `mediaremoted` daemon, breaking `MRMediaRemoteGetNowPlayingInfo` in unprivileged third-party apps (impacting Boring Notch, `nowplaying-cli`, etc.). Boring Notch patched this via a helper adapter (`MediaRemoteAdapter`) and per-app AppleScript fallbacks.
- **macOS 14 Impact:** While `MediaRemote` SPI worked without 15.4's entitlement restrictions on macOS 14, **it is strictly prohibited** by LiteCast's public API mandate and would fail App Store review / future OS compatibility.

### 3.3 Public Solution: ScriptingBridge / AppleScript for Music & Spotify
To read track information and control playback without private SPI:
- **Apple Music (`com.apple.Music`):**
  - Read: `current track` properties: `name`, `artist`, `album`, `player state`, `playerPosition`, `artwork 1`.
  - Commands: `playpause`, `next track`, `previous track`.
- **Spotify (`com.spotify.client`):**
  - Read: `current track` properties: `name`, `artist`, `album`, `player state`, `artwork url` (fetched asynchronously).
  - Commands: `playpause`, `next track`, `previous track`.
- **Permissions:** Must include `NSAppleEventsUsageDescription` in `Info.plist`. First invocation triggers a TCC prompt. If denied, calls fail with error `-1743` (`errAEEventNotPermitted`), which must be caught gracefully.
- **Performance:** Check `NSRunningApplication.runningApplications(withBundleIdentifier:)` *before* issuing AppleEvents to avoid launching closed apps.

### 3.4 Blind System-Wide Media Keys (Fallback Control)
If no metadata is needed or permissions are missing, an app with **Accessibility permission** can dispatch synthetic hardware media keys:
```swift
import Cocoa

func postMediaKey(key: Int32) { // 16 = NX_KEYTYPE_PLAY, 17 = NEXT, 18 = PREVIOUS
    for down in [true, false] {
        let state = down ? 0xA : 0xB
        let data1 = (Int(key) << 16) | (state << 8)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(down ? 0xA00 : 0xB00)),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: data1, data2: -1
        )?.cgEvent else { return }
        event.post(tap: .cghidEventTap) // Requires Accessibility (AXIsProcessTrusted)
    }
}
```

---

## 4. Battery Status via IOKit (Zero-Polling Notifications)

Querying battery health and observing power changes on macOS requires **no polling** and **no private APIs**. Use [`IOKit.ps`](https://developer.apple.com/documentation/iokit/iopowersources_h):

```swift
import Foundation
import IOKit.ps

final class BatteryMonitor: @unchecked Sendable {
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.updateState()
        }, context)?.takeRetainedValue() else { return }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        updateState()
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
    }

    private func updateState() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return }

        for src in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, src)?.takeUnretainedValue() as? [String: Any] else { continue }
            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let percent = max > 0 ? (current * 100) / max : 0
            // Dispatch to UI / State publisher
        }
    }
}
```
*Note on memory management:* `IOPSNotificationCreateRunLoopSource`, `IOPSCopyPowerSourcesInfo`, and `IOPSCopyPowerSourcesList` follow Create/Copy rules (`takeRetainedValue()`), whereas `IOPSGetPowerSourceDescription` follows Get rules (`takeUnretainedValue()`).

---

## 5. Architectural Recommendations

### 5.1 Milestone 2: Dynamic Notch MVP
1. **Geometry Provider:**
   - Detect built-in screen via `CGDisplayIsBuiltin`.
   - If `hasNotch`: Anchor panel to `screen.notchFrame`.
   - **Fallback (Non-notch screen / External display):** Render a top-centered floating pill (`NSRect(x: screen.frame.midX - 100, y: screen.frame.maxY - 32, width: 200, height: 32)`) attached to the screen top edge or tucked immediately below the menu bar.
2. **Panel Configuration:**
   - Single borderless `NSPanel` at level `.statusBar`, `.canJoinAllSpaces`, `.fullScreenAuxiliary`.
   - Hover expansion driven by `NSTrackingArea`, animating SwiftUI content height from 32 pt (collapsed) to ~160 pt (expanded).

### 5.2 Milestone 4: Media Architecture
1. **Provider Strategy:**
   - Do **not** attempt universal media capture via `MediaRemote.framework`.
   - Build a `MediaProvider` protocol implemented by `MusicMediaProvider` and `SpotifyMediaProvider` via `ScriptingBridge` / AppleScript.
2. **Permissions & Graceful Degradation:**
   - Declare `NSAppleEventsUsageDescription` in `Info.plist`.
   - Check `NSRunningApplication` before querying to prevent opening dormant apps.
   - If permissions are not granted, notch displays a clean, minimal battery/launcher idle state instead of an error banner.
   - Optional: Provide blind hardware Play/Pause via `.cghidEventTap` if the user grants Accessibility.

---

## 6. Verification Status & Source Citations

- **Verified:**
  - `NSScreen.safeAreaInsets` and `auxiliaryTop*Area` correctly yield the exact notch rect on Apple Silicon Macs running macOS 12+ ([Apple Docs: NSScreen](https://developer.apple.com/documentation/appkit/nsscreen)).
  - `IOPSNotificationCreateRunLoopSource` is 100% public, stable C API since macOS 10.2 ([Apple Docs: IOPowerSources.h](https://developer.apple.com/documentation/iokit/iopowersources_h)).
  - `MPNowPlayingInfoCenter` does not expose foreign app playback metadata on macOS ([Apple Docs: MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)).
  - `MediaRemote.framework` is private SPI; macOS 15.4 broke metadata inspection for third-party tools.
- **Uncertain / Implementation Nuances:**
  - In auto-hide menu bar mode on macOS 14, an `NSPanel` at `.statusBar` level may compete with the system menu bar drop-down gesture if mouse hover is placed too close to the upper edge; setting window level to `.popUpMenu` (level 101) or leaving a 1 pt gap mitigates this.
