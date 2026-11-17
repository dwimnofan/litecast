import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NowPlayingWidget: View {
    let service: NowPlayingService

    var body: some View {
        HStack(spacing: 10) {
            artwork
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                if let info = service.info {
                    Text(info.title).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(info.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("Nothing playing").font(.callout).foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    control("backward.fill", "Previous track") { service.previous() }
                    control(service.info?.isPlaying == true ? "pause.fill" : "play.fill", "Play or pause") { service.playPause() }
                    control("forward.fill", "Next track") { service.next() }
                }
                .padding(.top, 2)
                .opacity(service.info == nil ? 0.35 : 1)
                .disabled(service.info == nil)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: 190, alignment: .leading)
        }
    }

    @ViewBuilder private var artwork: some View {
        if let image = service.artwork {
            Image(nsImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Color.white.opacity(0.1)
                Image(systemName: "music.note").foregroundStyle(.secondary)
            }
        }
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }
}

struct BatteryWidget: View {
    let status: BatteryStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(status.isCharging ? .green : (status.level <= 20 ? .red : .white))
            Text("\(status.level)%").font(.caption.monospacedDigit())
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(status.level) percent\(status.isCharging ? ", charging" : "")")
    }

    private var symbol: String {
        if status.isCharging { return "battery.100.bolt" }
        switch status.level {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}

struct ShelfWidget: View {
    let store: ShelfStore
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(isTargeted ? 0.7 : 0.2), style: StrokeStyle(lineWidth: 1, dash: [4]))
            if store.items.isEmpty {
                Text("Drop files here to keep them").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.items) { item in
                            ShelfItemView(item: item, url: store.resolve(item)) { store.remove(item) }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(height: 56)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in store.add([url]) }
                }
            }
            return !providers.isEmpty
        }
    }
}

private struct ShelfItemView: View {
    let item: ShelfItem
    let url: URL? // nil when the file is gone
    let remove: () -> Void

    var body: some View {
        let name = url?.lastPathComponent ?? (item.path as NSString).lastPathComponent
        VStack(spacing: 2) {
            Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) }
                  ?? NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Missing file") ?? NSImage())
                .resizable()
                .frame(width: 28, height: 28)
            Text(name).font(.system(size: 9)).lineLimit(1).frame(width: 56)
        }
        .foregroundStyle(.white)
        .opacity(url == nil ? 0.4 : 1)
        .overlay(alignment: .topTrailing) {
            Button(action: remove) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityLabel("Remove \(name) from shelf")
        }
        .onTapGesture { if let url { NSWorkspace.shared.open(url) } }
        .onDrag { url.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider() }
        .help(url == nil ? "File no longer exists" : name)
    }
}
