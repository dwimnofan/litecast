import SwiftUI

/// One tab per feature. Features add their own tab here.
struct SettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        TabView {
            GeneralSettingsView(preferences: environment.preferences)
                .tabItem { Label("General", systemImage: "gearshape") }
            QuicklinksSettingsView(store: environment.quicklinks)
                .tabItem { Label("Quicklinks", systemImage: "link") }
            SnippetsSettingsView(store: environment.snippets)
                .tabItem { Label("Snippets", systemImage: "text.quote") }
        }
        .frame(width: 560, height: 420)
    }
}

struct GeneralSettingsView: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        Form {
            Toggle("Show LiteCast in the Dock", isOn: $preferences.showInDock)
        }
        .formStyle(.grouped)
    }
}
