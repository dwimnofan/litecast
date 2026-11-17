import SwiftUI

struct LauncherView: View {
    @Bindable var model: LauncherModel
    @FocusState private var searchFocused: Bool

    private static let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().opacity(0.6)
            resultsList
            Divider().opacity(0.6)
            footer
        }
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { searchFocused = true }
    }

    private var searchField: some View {
        TextField("Search for apps and commands…", text: $model.query)
            .textFieldStyle(.plain)
            .font(.system(size: 20))
            .padding(.horizontal, 18)
            .frame(height: 58)
            .focused($searchFocused)
            .accessibilityLabel("Search")
            .onKeyPress(.upArrow) { model.moveSelection(by: -1); return .handled }
            .onKeyPress(.downArrow) { model.moveSelection(by: 1); return .handled }
            .onSubmit { model.executeSelected() }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !model.results.isEmpty {
                        Text(model.query.isEmpty ? "Applications" : "Results")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 6)
                    }
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                        ResultRow(result: result, isSelected: index == model.selectedIndex)
                            .id(result.id)
                            .contentShape(Rectangle())
                            .onTapGesture { model.execute(result) }
                            .onHover { if $0 { model.selectedIndex = index } }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
            .onChange(of: model.selectedIndex) { _, index in
                guard model.results.indices.contains(index) else { return }
                proxy.scrollTo(model.results[index].id)
            }
            .overlay {
                if model.results.isEmpty {
                    Text(model.query.isEmpty ? "Indexing apps…" : "No results")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footerLabel: String {
        guard model.results.indices.contains(model.selectedIndex) else { return "LiteCast" }
        return "LiteCast. Press Return to \(model.results[model.selectedIndex].action.title)"
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "command")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.tint, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text("LiteCast")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if model.results.indices.contains(model.selectedIndex) {
                Text(model.results[model.selectedIndex].action.title)
                    .font(.system(size: 12, weight: .medium))
                KeyCap("↵")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.black.opacity(0.08))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(footerLabel)
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let isSelected: Bool

    private var spokenLabel: String {
        var parts = [result.title]
        if let subtitle = result.subtitle { parts.append(subtitle) }
        if !result.accessory.isEmpty { parts.append(result.accessory) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                switch result.icon {
                case .file(let url):
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
                case .symbol(let name):
                    Image(systemName: name).font(.system(size: 14)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 22, height: 22)
            Text(result.title)
                .font(.system(size: 14))
                .lineLimit(1)
            if let subtitle = result.subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            Text(result.accessory)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.1) : .clear)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct KeyCap: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(minWidth: 20, minHeight: 20)
            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
