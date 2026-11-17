import SwiftUI

struct SnippetsSettingsView: View {
    @Bindable var store: SnippetStore
    @State private var editing: Draft?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(store.items) { snippet in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.name).font(.body.weight(.medium))
                            if !snippet.keyword.isEmpty {
                                Text(snippet.keyword)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(Snippet.subtitle(for: snippet.text))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Edit") { editing = Draft(snippet) }
                            .buttonStyle(.borderless)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button("Add Snippet") { editing = Draft() }
                Spacer()
            }
            .padding()
        }
        .sheet(item: $editing) { draft in
            SnippetEditorSheet(
                draft: draft,
                onCancel: { editing = nil },
                onSave: { saved in
                    if store.items.contains(where: { $0.id == saved.id }) {
                        store.update(saved)
                    } else {
                        store.add(saved)
                    }
                    editing = nil
                }
            )
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            store.delete(id: store.items[index].id)
        }
    }
}

private struct Draft: Identifiable {
    let id: UUID
    var name: String
    var keyword: String
    var text: String

    init() {
        id = UUID()
        name = ""
        keyword = ""
        text = ""
    }

    init(_ snippet: Snippet) {
        id = snippet.id
        name = snippet.name
        keyword = snippet.keyword
        text = snippet.text
    }

    var asSnippet: Snippet {
        Snippet(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines),
            text: text
        )
    }
}

private struct SnippetEditorSheet: View {
    @State private var draft: Draft
    let onCancel: () -> Void
    let onSave: (Snippet) -> Void

    init(draft: Draft, onCancel: @escaping () -> Void, onSave: @escaping (Snippet) -> Void) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.name.isEmpty && draft.text.isEmpty ? "Add Snippet" : "Edit Snippet")
                .font(.headline)
            Form {
                TextField("Name", text: $draft.name)
                TextField("Keyword (optional)", text: $draft.keyword)
                Text("Text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.text)
                    .font(.body.monospaced())
                    .frame(minHeight: 120)
                Text("Placeholders: {date}, {time}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(draft.asSnippet) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 480, height: 420)
    }
}
