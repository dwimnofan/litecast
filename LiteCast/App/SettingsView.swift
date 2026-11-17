import SwiftUI

/// One tab per feature. Features add their own tab here.
struct SettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        TabView {
            GeneralSettingsView(preferences: environment.preferences)
                .tabItem { Label("General", systemImage: "gearshape") }
            NotchSettingsView(preferences: environment.preferences)
                .tabItem { Label("Notch", systemImage: "rectangle.topthird.inset.filled") }
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

struct NotchSettingsView: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        Form {
            Toggle("Enable notch", isOn: $preferences.notchEnabled)
            Section("Widgets") {
                Toggle("Now Playing (Music, Spotify)", isOn: $preferences.notchShowMedia)
                Toggle("Battery", isOn: $preferences.notchShowBattery)
                Toggle("File shelf", isOn: $preferences.notchShowShelf)
            }
            .disabled(!preferences.notchEnabled)
            Text("Now Playing asks for Automation permission the first time Music or Spotify is playing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
