import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    func applicationDidFinishLaunching(_ notification: Notification) {
        environment.preferences.applyActivationPolicy()
        Log.app.info("TinyCast launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Hotkeys and owned windows get torn down here once they exist (Milestone 1+).
        Log.app.info("TinyCast terminating")
    }
}
