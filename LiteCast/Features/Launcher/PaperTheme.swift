import AppKit
import SwiftUI

/// Paper / Ink palette (matches the owner's T3 Code theme).
enum Paper {
    static let canvas = Color(hex: 0xF3F1E9)
    static let raised = Color(hex: 0xF8F6EF)
    static let chrome = Color(hex: 0xECEAE2)
    static let ink = Color(hex: 0x292A26)
    static let inkMuted = Color(hex: 0x585E51)
    static let placeholder = Color(hex: 0x626959)
    static let heading = Color(hex: 0x48523F)
    static let icon = Color(hex: 0x5B6254)
    static let rule = Color(hex: 0xC6C5BA)
    static let ruleStrong = Color(hex: 0x85877B)
    static let selected = Color(hex: 0xE5EADF)
    static let selectedFrame = Color(hex: 0x657B68)
    static let hardShadow = Color(red: 41 / 255, green: 42 / 255, blue: 38 / 255).opacity(0.12)

    static let radius: CGFloat = 2
    /// Charter for the brand and typed query; falls back to the system serif design.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        NSFont(name: "Charter", size: size) != nil
            ? .custom("Charter", size: size).weight(weight)
            : .system(size: size, weight: weight, design: .serif)
    }

    /// Tileable grain, generated once (no bundled asset).
    @MainActor static let grain: NSImage = {
        let side = 128
        var state: UInt32 = 0x9E37_79B9
        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            state = state &* 1_664_525 &+ 1_013_904_223 // LCG: deterministic, cheap
            let v = UInt8(truncatingIfNeeded: state >> 24)
            pixels[i] = v; pixels[i + 1] = v; pixels[i + 2] = v
        }
        let image = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        return image.map { NSImage(cgImage: $0, size: NSSize(width: side, height: side)) } ?? NSImage()
    }()
}

/// Paper sheet: canvas colour, grain, soft top highlight, ink border, hard offset shadow.
struct PaperSheet: ViewModifier {
    var fill: Color = Paper.canvas

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    fill
                    Image(nsImage: Paper.grain)
                        .resizable(resizingMode: .tile)
                        .blendMode(.multiply)
                        .opacity(0.06)
                    RadialGradient(colors: [.white.opacity(0.45), .clear],
                                   center: UnitPoint(x: 0.48, y: 0.2), startRadius: 0, endRadius: 520)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Paper.radius))
            .overlay(RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.ruleStrong, lineWidth: 1))
            .shadow(color: Paper.hardShadow, radius: 0, x: 2, y: 2)
    }
}

struct KeyCap: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Paper.ink)
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 2)
            .background(Paper.raised, in: RoundedRectangle(cornerRadius: Paper.radius))
            .overlay(RoundedRectangle(cornerRadius: Paper.radius).strokeBorder(Paper.ruleStrong, lineWidth: 1))
            .shadow(color: Paper.hardShadow, radius: 0, x: 1, y: 1)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
