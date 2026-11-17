import Foundation

/// Constructs and owns app-wide services.
@MainActor
final class AppEnvironment {
    let preferences: PreferencesStore

    init(defaults: UserDefaults = .standard) {
        preferences = PreferencesStore(defaults: defaults)
    }
}
