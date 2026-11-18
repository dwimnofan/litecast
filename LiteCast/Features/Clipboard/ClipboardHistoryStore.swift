import AppKit
import CryptoKit
import Observation

/// Owns the clipboard history list. Newest items first.
///
/// ## Retention policy
/// - Maximum item count (default 200).
/// - Maximum age: 1 day, 7 days, 30 days, or forever.
/// - Pruning runs on every insert and on load.
///
/// ## Persistence
/// Metadata in `clipboard-history.json`; image PNGs in `clipboard-images/`.
/// If the JSON is corrupt the store logs the error and starts empty **without overwriting** the file.
@MainActor
@Observable
final class ClipboardHistoryStore {
    /// Retention-age options surfaced in Settings.
    enum RetentionAge: Int, CaseIterable, Sendable {
        case oneDay = 1
        case sevenDays = 7
        case thirtyDays = 30
        case forever = 0

        var label: String {
            switch self {
            case .oneDay: "1 day"
            case .sevenDays: "7 days"
            case .thirtyDays: "30 days"
            case .forever: "Forever"
            }
        }
    }

    /// Longest edge kept when storing clipboard images (screenshots stay usable, disk/RAM stay small).
    static let maxStoredImageEdge: CGFloat = 1600

    private(set) var items: [ClipboardItem] = []

    @ObservationIgnored private let store: JSONFileStore<[ClipboardItem]>
    @ObservationIgnored private let imagesDirectory: URL
    @ObservationIgnored private var corruptFileDetected = false
    @ObservationIgnored private var thumbnailCache: [UUID: NSImage] = [:]

    @ObservationIgnored private let defaults: UserDefaults

    var maxItemCount: Int {
        didSet {
            defaults.set(maxItemCount, forKey: "clipboardMaxItems")
            prune()
            saveToDisk()
        }
    }
    var retentionAge: RetentionAge {
        didSet {
            defaults.set(retentionAge.rawValue, forKey: "clipboardRetentionDays")
            prune()
            saveToDisk()
        }
    }

    init(store: JSONFileStore<[ClipboardItem]> = JSONFileStore(filename: "clipboard-history.json"),
         defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        self.imagesDirectory = store.url.deletingLastPathComponent().appendingPathComponent("clipboard-images", isDirectory: true)
        let count = defaults.integer(forKey: "clipboardMaxItems")
        maxItemCount = count > 0 ? count : 200
        retentionAge = RetentionAge(rawValue: defaults.object(forKey: "clipboardRetentionDays") as? Int ?? 7) ?? .sevenDays
        loadFromDisk()
    }

    // MARK: - Mutations

    /// Adds a text/link entry. De-duplicates: same text moves to the top.
    func add(text: String, sourceAppBundleID: String? = nil, date: Date = Date()) {
        items.removeAll { $0.kind != .image && $0.text == text }
        let item = ClipboardItem(text: text, date: date, sourceAppBundleID: sourceAppBundleID)
        items.insert(item, at: 0)
        prune(now: date)
        saveToDisk()
    }

    /// Adds an image entry from PNG (or convertible) bytes. De-dupes by content hash.
    @discardableResult
    func addImage(pngData: Data, width: Int, height: Int, sourceAppBundleID: String? = nil, date: Date = Date()) -> ClipboardItem? {
        let hash = Self.sha256Hex(pngData)
        if let existing = items.first(where: { $0.contentHash == hash }) {
            items.removeAll { $0.id == existing.id }
            let moved = ClipboardItem(
                id: existing.id,
                kind: .image,
                text: "",
                imageFileName: existing.imageFileName,
                imageWidth: existing.imageWidth ?? width,
                imageHeight: existing.imageHeight ?? height,
                contentHash: hash,
                date: date,
                sourceAppBundleID: sourceAppBundleID ?? existing.sourceAppBundleID
            )
            items.insert(moved, at: 0)
            prune(now: date)
            saveToDisk()
            return moved
        }

        ensureImagesDirectory()
        let fileName = "\(UUID().uuidString).png"
        let url = imagesDirectory.appendingPathComponent(fileName)
        do {
            try pngData.write(to: url, options: .atomic)
        } catch {
            Log.app.error("Failed to write clipboard image: \(String(describing: error))")
            return nil
        }

        let item = ClipboardItem(
            kind: .image,
            text: "",
            imageFileName: fileName,
            imageWidth: width,
            imageHeight: height,
            contentHash: hash,
            date: date,
            sourceAppBundleID: sourceAppBundleID
        )
        items.insert(item, at: 0)
        prune(now: date)
        saveToDisk()
        return item
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        thumbnailCache.removeValue(forKey: item.id)
        if let name = item.imageFileName {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(name))
        }
        saveToDisk()
    }

    /// Removes all items and image files, persists immediately.
    func clearAll() {
        for item in items {
            if let name = item.imageFileName {
                try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(name))
            }
        }
        items.removeAll()
        thumbnailCache.removeAll()
        saveToDisk()
    }

    func imageURL(for item: ClipboardItem) -> URL? {
        guard let name = item.imageFileName else { return nil }
        let url = imagesDirectory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func imageData(for item: ClipboardItem) -> Data? {
        guard let url = imageURL(for: item) else { return nil }
        return try? Data(contentsOf: url)
    }

    func image(for item: ClipboardItem) -> NSImage? {
        guard let url = imageURL(for: item) else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Small cached preview for list rows — avoids decoding full screenshots while scrolling.
    func thumbnail(for item: ClipboardItem, maxEdge: CGFloat = 56) -> NSImage? {
        if let cached = thumbnailCache[item.id] { return cached }
        guard let image = image(for: item) else { return nil }
        let thumb = Self.resized(image, maxEdge: maxEdge)
        thumbnailCache[item.id] = thumb
        // Bound cache so a long session of browsing images can't grow forever.
        if thumbnailCache.count > 80 {
            thumbnailCache.removeAll(keepingCapacity: true)
            thumbnailCache[item.id] = thumb
        }
        return thumb
    }

    // MARK: - Pruning

    /// Prune by count and by age. Called on every insert.
    func prune(now: Date = Date()) {
        if items.count > maxItemCount {
            let dropped = items.suffix(from: maxItemCount)
            for item in dropped {
                thumbnailCache.removeValue(forKey: item.id)
                if let name = item.imageFileName {
                    try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(name))
                }
            }
            items = Array(items.prefix(maxItemCount))
        }
        if retentionAge != .forever {
            let cutoff = now.addingTimeInterval(-Double(retentionAge.rawValue) * 86400)
            let (kept, expired) = items.reduce(into: ([ClipboardItem](), [ClipboardItem]())) { result, item in
                if item.date < cutoff { result.1.append(item) } else { result.0.append(item) }
            }
            for item in expired {
                thumbnailCache.removeValue(forKey: item.id)
                if let name = item.imageFileName {
                    try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(name))
                }
            }
            items = kept
        }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        do {
            items = try store.load() ?? []
            prune()
        } catch {
            Log.app.error("Clipboard history file is corrupt — starting empty. Error: \(String(describing: error))")
            items = []
            corruptFileDetected = true
            // Do NOT overwrite the corrupt file.
        }
    }

    private func saveToDisk() {
        if corruptFileDetected {
            // First write after a corrupt load: keep the bad file aside instead of destroying it.
            let backup = store.url.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: store.url, to: backup)
            corruptFileDetected = false
        }
        do {
            try store.save(items)
        } catch {
            Log.app.error("Failed to save clipboard history: \(String(describing: error))")
        }
    }

    private func ensureImagesDirectory() {
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Converts TIFF/PNG pasteboard bytes to PNG for storage, downscaling huge screenshots.
    static func pngData(fromImageData data: Data) -> (Data, Int, Int)? {
        guard let image = NSImage(data: data) else { return nil }
        let fitted = resized(image, maxEdge: maxStoredImageEdge)
        guard let cgImage = fitted.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return (png, width, height)
    }

    /// Resize using pixel dimensions (not points) so Retina `lockFocus` bitmaps don't slip past the cap.
    static func resized(_ image: NSImage, maxEdge: CGFloat) -> NSImage {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let srcW = CGFloat(cg.width)
        let srcH = CGFloat(cg.height)
        let longest = max(srcW, srcH)
        guard longest > maxEdge, longest > 0 else {
            return NSImage(cgImage: cg, size: NSSize(width: srcW, height: srcH))
        }
        let scale = maxEdge / longest
        let targetW = max(1, Int((srcW * scale).rounded()))
        let targetH = max(1, Int((srcH * scale).rounded()))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: targetW, height: targetH, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
        guard let out = ctx.makeImage() else { return image }
        return NSImage(cgImage: out, size: NSSize(width: targetW, height: targetH))
    }
}
