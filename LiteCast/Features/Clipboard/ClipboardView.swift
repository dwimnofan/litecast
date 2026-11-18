import AppKit
import SwiftUI

struct ClipboardView: View {
    @Bindable var model: ClipboardModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Paper.rule.frame(height: 1)
            if model.filteredItems.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    listPane
                        .frame(width: 320)
                    Paper.rule.frame(width: 1)
                    detailPane
                }
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(PaperSheet())
        .padding(LauncherWindowController.shadowMargin)
        .onChange(of: model.query) { model.syncSelectionAfterFilterChange() }
        .onChange(of: model.typeFilter) { model.syncSelectionAfterFilterChange() }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Paper.icon)
            TextField("", text: $model.query, prompt: Text("Type to filter entries…").foregroundStyle(Paper.placeholder))
                .textFieldStyle(.plain)
                .font(Paper.serif(18))
                .foregroundStyle(Paper.ink)
                .tint(Paper.ink)
                .id(model.focusToken)
            Picker("", selection: $model.typeFilter) {
                ForEach(ClipboardTypeFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .labelsHidden()
            .frame(width: 110)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28))
                .foregroundStyle(Paper.icon)
            Text(model.historyIsEmpty ? "No clipboard history yet" : "No matches")
                .font(Paper.serif(16))
                .foregroundStyle(Paper.ink)
            Text(model.historyIsEmpty
                 ? "Copy text or an image — LiteCast will keep it here."
                 : "Try another filter or search.")
                .font(.system(size: 12))
                .foregroundStyle(Paper.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var listPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(model.sections, id: \.title) { section in
                        Section {
                            ForEach(section.items) { item in
                                ClipboardRow(
                                    item: item,
                                    isSelected: model.selectedItem?.id == item.id,
                                    thumbnail: model.thumbnail(for: item)
                                )
                                .id(item.id)
                                .onTapGesture(count: 2) { model.pasteSelected() }
                                .onTapGesture(count: 1) { model.select(item) }
                            }
                        } header: {
                            Text(section.title.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(Paper.heading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Paper.chrome.opacity(0.95))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: model.selectedItem?.id) { _, newID in
                if let newID { withAnimation(nil) { proxy.scrollTo(newID, anchor: .center) } }
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let item = model.selectedItem {
            ZStack(alignment: .topTrailing) {
                ClipboardDetail(item: item, model: model)
                if model.isShowingActions {
                    actionsMenu
                        .padding(12)
                }
            }
        } else {
            Color.clear
        }
    }

    private var actionsMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ACTIONS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Paper.heading)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)
            ForEach(Array(model.selectedActions.enumerated()), id: \.element.id) { index, action in
                HStack(spacing: 8) {
                    Image(systemName: action.symbol)
                        .frame(width: 14)
                        .foregroundStyle(Paper.icon)
                    Text(action.title)
                        .foregroundStyle(Paper.ink)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(index == model.actionIndex ? Paper.selected : .clear, in: RoundedRectangle(cornerRadius: Paper.radius))
                .overlay {
                    if index == model.actionIndex {
                        RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.selectedFrame, lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { model.runAction(action) }
            }
        }
        .frame(width: 200)
        .padding(.bottom, 8)
        .modifier(PaperSheet(fill: Paper.raised))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let item = model.selectedItem {
                Text("Paste")
                    .foregroundStyle(Paper.inkMuted)
                KeyCap("↵")
                Text(item.title)
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("Actions")
                .foregroundStyle(model.isShowingActions ? Paper.ink : Paper.inkMuted)
            KeyCap("⌘")
            KeyCap("K")
            Paper.rule.frame(width: 1, height: 16).padding(.horizontal, 4)
            Text("Clipboard History")
                .font(Paper.serif(13, weight: .semibold))
                .foregroundStyle(Paper.ink)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Paper.chrome.opacity(0.85))
        .overlay(alignment: .top) { Paper.rule.frame(height: 1) }
    }
}

private extension ClipboardModel {
    var historyIsEmpty: Bool {
        // Access via filtered with all + empty query approximation: if filter is all and query empty and filtered empty → store empty
        query.isEmpty && typeFilter == .all && filteredItems.isEmpty
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                Text(ClipboardHistoryProvider.subtitle(for: item))
                    .font(.system(size: 11))
                    .foregroundStyle(Paper.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Paper.selected : .clear, in: RoundedRectangle(cornerRadius: Paper.radius))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.selectedFrame, lineWidth: 1)
            }
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var icon: some View {
        if item.kind == .image, let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: Paper.radius))
                .overlay(RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.rule, lineWidth: 1))
        } else {
            Image(systemName: item.kind.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Paper.icon)
                .frame(width: 28, height: 28)
                .background(Paper.raised, in: RoundedRectangle(cornerRadius: Paper.radius))
                .overlay(RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.rule, lineWidth: 1))
        }
    }
}

private struct ClipboardDetail: View {
    let item: ClipboardItem
    let model: ClipboardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                contentPreview
                infoSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.kind {
        case .text, .link:
            Text(item.text)
                .font(Paper.serif(15))
                .foregroundStyle(Paper.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image:
            if let image = model.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: Paper.radius))
                    .overlay(RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.rule, lineWidth: 1))
            } else {
                Text("Image file missing")
                    .foregroundStyle(Paper.inkMuted)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INFORMATION")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Paper.heading)

            infoRow(label: "Source") {
                HStack(spacing: 6) {
                    if let icon = model.sourceAppIcon(for: item) {
                        Image(nsImage: icon).resizable().frame(width: 14, height: 14)
                    }
                    Text(model.sourceAppName(for: item) ?? "Unknown")
                }
            }
            infoRow(label: "Content type") {
                Text(item.kind.label)
            }
            if item.kind != .image {
                infoRow(label: "Characters") {
                    Text("\(item.characterCount)")
                }
            } else if let w = item.imageWidth, let h = item.imageHeight {
                infoRow(label: "Size") {
                    Text("\(w)×\(h)")
                }
            }
            infoRow(label: "Copied") {
                Text(item.date.formatted(date: .abbreviated, time: .standard))
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Paper.ink)
    }

    private func infoRow<Content: View>(label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Paper.inkMuted)
                .frame(width: 100, alignment: .leading)
            value()
            Spacer(minLength: 0)
        }
    }
}
