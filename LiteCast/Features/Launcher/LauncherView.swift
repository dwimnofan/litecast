import SwiftUI

struct LauncherView: View {
    @Bindable var model: LauncherModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Paper.rule.frame(height: 1)
            resultsList
            footer
        }
        .modifier(PaperSheet())
        .overlay(alignment: .bottomTrailing) {
            if model.isShowingActions, let result = model.selectedResult {
                ActionPanel(title: result.title, actions: result.availableActions, selection: model.actionIndex) {
                    model.actionIndex = $0
                    model.executeSelected()
                }
                .padding(.trailing, 12)
                .padding(.bottom, 52)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: model.isShowingActions)
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        .padding(LauncherWindowController.shadowMargin)
        .environment(\.colorScheme, .light)
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { searchFocused = true }
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Paper.icon)
            TextField("", text: $model.query, prompt: Text("Search for apps and commands…").foregroundStyle(Paper.placeholder))
                .textFieldStyle(.plain)
                .font(Paper.serif(21))
                .foregroundStyle(Paper.ink)
                .tint(Paper.ink)
                .focused($searchFocused)
                .accessibilityLabel("Search")
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    // MARK: Results

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                        if let title = model.sectionTitle(at: index) {
                            SectionHeader(title: title, isFirst: index == 0)
                        }
                        ResultRow(result: result, isSelected: index == model.selectedIndex)
                            .id(result.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { model.execute(result) }
                            .onTapGesture { model.selectedIndex = index }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.never)
            .onChange(of: model.selectedIndex) { _, index in
                guard model.results.indices.contains(index) else { return }
                proxy.scrollTo(model.results[index].id)
            }
            .overlay {
                if model.results.isEmpty {
                    Text(model.query.isEmpty ? "Indexing apps…" : "No results for “\(model.query)”")
                        .font(Paper.serif(15))
                        .italic()
                        .foregroundStyle(Paper.inkMuted)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Text("LiteCast")
                .font(Paper.serif(14, weight: .semibold))
                .foregroundStyle(Paper.ink)
            Spacer()
            if let result = model.selectedResult {
                Text(result.action.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Paper.ink)
                KeyCap("↵")
                Paper.rule.frame(width: 1, height: 16).padding(.horizontal, 4)
                Text("Actions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(model.isShowingActions ? Paper.ink : Paper.inkMuted)
                KeyCap("⌘")
                KeyCap("K")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Paper.chrome.opacity(0.85))
        .overlay(alignment: .top) { Paper.rule.frame(height: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(footerLabel)
    }

    private var footerLabel: String {
        guard let result = model.selectedResult else { return "LiteCast" }
        return "\(result.action.title), press Return. Actions, press Command K."
    }
}

// MARK: - Pieces

private struct SectionHeader: View {
    let title: String
    let isFirst: Bool

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(Paper.heading)
            .padding(.horizontal, 10)
            .padding(.top, isFirst ? 12 : 16)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ResultIcon(icon: result.icon)
            Text(result.title)
                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
            if let subtitle = result.subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Paper.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 12)
            Text(result.accessory)
                .font(.system(size: 12))
                .foregroundStyle(Paper.inkMuted)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(isSelected ? Paper.selected : .clear, in: RoundedRectangle(cornerRadius: Paper.radius))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.selectedFrame, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([result.title, result.subtitle, result.accessory].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ResultIcon: View {
    let icon: SearchIcon

    var body: some View {
        Group {
            switch icon {
            case .file(let url):
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Paper.icon)
                    .frame(width: 22, height: 22)
                    .background(Paper.raised, in: RoundedRectangle(cornerRadius: Paper.radius))
                    .overlay(RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.rule, lineWidth: 1))
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}

private struct ActionPanel: View {
    let title: String
    let actions: [ResultAction]
    let selection: Int
    let onRun: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(Paper.serif(13, weight: .semibold))
                .foregroundStyle(Paper.heading)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 4)
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                HStack(spacing: 10) {
                    Image(systemName: action.symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(Paper.icon)
                        .frame(width: 16)
                    Text(action.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Paper.ink)
                    Spacer()
                    if index == 0 { KeyCap("↵") }
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(index == selection ? Paper.selected : .clear, in: RoundedRectangle(cornerRadius: Paper.radius))
                .overlay {
                    if index == selection {
                        RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.selectedFrame, lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onRun(index) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(action.title)
                .accessibilityAddTraits(index == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(6)
        .frame(width: 290)
        .modifier(PaperSheet(fill: Paper.raised))
    }
}
