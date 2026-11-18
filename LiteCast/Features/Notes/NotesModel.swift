import AppKit
import Observation

@MainActor
@Observable
final class NotesModel {
    var selectedURL: URL?
    var draft: String = ""
    var query: String = ""
    var isBrowsing = false
    var statusMessage: String?

    @ObservationIgnored private let store: NoteStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var lastSaved: String = ""
    @ObservationIgnored var onHide: () -> Void = {}

    init(store: NoteStore) {
        self.store = store
    }

    var filteredNotes: [Note] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return store.notes }
        return store.notes.filter {
            $0.title.lowercased().contains(term)
                || $0.preview.lowercased().contains(term)
        }
    }

    var selectedNote: Note? {
        guard let selectedURL else { return nil }
        return store.notes.first { $0.url == selectedURL }
    }

    func openLastOrEmpty() {
        store.refresh()
        if let selectedURL, let match = store.notes.first(where: { $0.url == selectedURL }) {
            select(match)
        } else if let first = store.notes.first {
            select(first)
        } else {
            selectedURL = nil
            draft = ""
            lastSaved = ""
        }
        isBrowsing = false
    }

    func toggleBrowser() {
        flushSave()
        isBrowsing.toggle()
        if isBrowsing {
            store.refresh()
            query = ""
        }
    }

    func select(_ note: Note) {
        flushSave()
        selectedURL = note.url
        draft = (try? store.read(note)) ?? ""
        lastSaved = draft
        isBrowsing = false
        query = ""
    }

    func create() {
        flushSave()
        do {
            let note = try store.createNote()
            select(note)
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteSelected() {
        guard let note = selectedNote else { return }
        flushSave()
        do {
            try store.delete(note)
            selectedURL = nil
            openLastOrEmpty()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func draftChanged() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            flushSave()
        }
    }

    func flushSave() {
        saveTask?.cancel()
        saveTask = nil
        guard let note = selectedNote, draft != lastSaved else { return }
        do {
            try store.write(note, content: draft)
            lastSaved = draft
            // If first line looks like a title and file is still Untitled, rename.
            maybeRenameFromFirstLine(note)
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func maybeRenameFromFirstLine(_ note: Note) {
        guard note.title.lowercased().hasPrefix("untitled") else { return }
        let line = draft.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let cleaned = line.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
        guard cleaned.count >= 2, cleaned.count <= 60 else { return }
        if let renamed = try? store.rename(note, to: cleaned) {
            selectedURL = renamed.url
        }
    }

    func revealFolder() {
        NSWorkspace.shared.open(store.directory)
    }
}
