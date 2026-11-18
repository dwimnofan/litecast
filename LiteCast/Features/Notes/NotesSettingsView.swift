import AppKit
import SwiftUI

struct NotesSettingsView: View {
    @Bindable var preferences: PreferencesStore
    let store: NoteStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable Notes", isOn: $preferences.notesEnabled)
                Text("Plain Markdown files in a folder. No database — each note is one .md file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if preferences.notesEnabled {
                Section("Folder") {
                    LabeledContent("Notes folder") {
                        Text(store.directory.path)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Choose…") { chooseFolder() }
                        Button("Default") { store.useDefaultFolder() }
                            .disabled(store.isUsingDefaultFolder)
                        Button("Open in Finder") { NSWorkspace.shared.open(store.directory) }
                    }
                }

                Section("Commands") {
                    Text("In the launcher: Show Notes, Create Note, or search note titles. Autosave runs ~0.3s after you stop typing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                store.setFolder(url)
            }
        }
    }
}
