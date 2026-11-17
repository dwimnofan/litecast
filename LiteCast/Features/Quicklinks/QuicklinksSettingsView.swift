import SwiftUI

struct QuicklinksSettingsView: View {
    @Bindable var store: QuicklinkStore
    @State private var editing: Draft?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(store.items) { link in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.name).font(.body.weight(.medium))
                            Text(link.urlTemplate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Edit") { editing = Draft(link) }
                            .buttonStyle(.borderless)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button("Add Quicklink") { editing = Draft() }
                Spacer()
            }
            .padding()
        }
        .sheet(item: $editing) { draft in
            QuicklinkEditorSheet(
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
    var urlTemplate: String

    init() {
        id = UUID()
        name = ""
        urlTemplate = "https://"
    }

    init(_ link: Quicklink) {
        id = link.id
        name = link.name
        urlTemplate = link.urlTemplate
    }

    var asQuicklink: Quicklink {
        Quicklink(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), urlTemplate: urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct QuicklinkEditorSheet: View {
    @State private var draft: Draft
    @State private var validationMessage: String?
    let onCancel: () -> Void
    let onSave: (Quicklink) -> Void

    init(draft: Draft, onCancel: @escaping () -> Void, onSave: @escaping (Quicklink) -> Void) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.name.isEmpty && draft.urlTemplate == "https://" ? "Add Quicklink" : "Edit Quicklink")
                .font(.headline)
            Form {
                TextField("Name", text: $draft.name)
                TextField("URL template", text: $draft.urlTemplate)
                Text("Use {query} for the text after the name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    let link = draft.asQuicklink
                    guard Quicklink.isValidURLTemplate(link.urlTemplate) else {
                        validationMessage = "URL must start with http:// or https://"
                        return
                    }
                    onSave(link)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
