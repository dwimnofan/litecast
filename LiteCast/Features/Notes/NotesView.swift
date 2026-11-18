import SwiftUI

struct NotesView: View {
    @Bindable var model: NotesModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Paper.rule.frame(height: 1)
            if model.isBrowsing {
                browser
            } else {
                editor
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(PaperSheet())
        .padding(LauncherWindowController.shadowMargin)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button { model.create() } label: {
                Image(systemName: "square.and.pencil")
            }
            .help("New Note (⌘N)")
            .keyboardShortcut("n", modifiers: .command)

            Button { model.toggleBrowser() } label: {
                Image(systemName: "list.bullet")
            }
            .help("Browse Notes (⌘P)")
            .keyboardShortcut("p", modifiers: .command)

            Button { model.revealFolder() } label: {
                Image(systemName: "folder")
            }
            .help("Open Notes Folder")

            Spacer(minLength: 0)

            if let note = model.selectedNote {
                Text(NoteStore.displayTitle(for: note))
                    .font(Paper.serif(14, weight: .semibold))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
            } else {
                Text("Notes")
                    .font(Paper.serif(14, weight: .semibold))
                    .foregroundStyle(Paper.inkMuted)
            }

            Spacer(minLength: 0)

            Text("\(model.draft.count)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Paper.inkMuted)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Paper.icon)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Paper.chrome.opacity(0.9))
    }

    private var editor: some View {
        Group {
            if model.selectedNote == nil && model.draft.isEmpty {
                VStack(spacing: 8) {
                    Text("No notes yet")
                        .font(Paper.serif(16))
                        .foregroundStyle(Paper.ink)
                    Text("Create a note to start writing Markdown.")
                        .font(.system(size: 12))
                        .foregroundStyle(Paper.inkMuted)
                    Button("Create Note") { model.create() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextEditor(text: $model.draft)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .onChange(of: model.draft) { model.draftChanged() }
            }
        }
    }

    private var browser: some View {
        VStack(spacing: 0) {
            TextField("Search notes…", text: $model.query)
                .textFieldStyle(.plain)
                .font(Paper.serif(15))
                .foregroundStyle(Paper.ink)
                .padding(12)
            Paper.rule.frame(height: 1)
            if model.filteredNotes.isEmpty {
                Text("No matches")
                    .foregroundStyle(Paper.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.filteredNotes, selection: Binding(
                    get: { model.selectedURL },
                    set: { url in
                        if let url, let note = model.filteredNotes.first(where: { $0.url == url }) {
                            model.select(note)
                        }
                    }
                )) { note in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NoteStore.displayTitle(for: note))
                            .foregroundStyle(Paper.ink)
                            .lineLimit(1)
                        Text(note.modified.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(Paper.inkMuted)
                    }
                    .tag(note.url)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
