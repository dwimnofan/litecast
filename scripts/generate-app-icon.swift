#!/usr/bin/env swift
import AppKit
import Foundation

/// Regenerates `LiteCast/Assets.xcassets/AppIcon.appiconset` (Paper / Ink ⌘ + notch pill).
/// Run from repo root: `swift scripts/generate-app-icon.swift`
///
/// Filenames avoid `@2x` — on case-insensitive APFS, `wendy.h@example.net`
/// and `wendy.h@example.net` collapse to the same file.

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("LiteCast/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let masterSize = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: masterSize, height: masterSize, bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fputs("no ctx\n", stderr); exit(1) }

ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

let S = CGFloat(masterSize)
let paper = CGColor(srgbRed: 0xF3 / 255, green: 0xF1 / 255, blue: 0xE9 / 255, alpha: 1)
let ink = CGColor(srgbRed: 0x29 / 255, green: 0x2A / 255, blue: 0x26 / 255, alpha: 1)
let sage = CGColor(srgbRed: 0x65 / 255, green: 0x7B / 255, blue: 0x68 / 255, alpha: 1)
let rule = CGColor(srgbRed: 0x85 / 255, green: 0x87 / 255, blue: 0x7B / 255, alpha: 1)
let shadowCol = CGColor(srgbRed: 0x29 / 255, green: 0x2A / 255, blue: 0x26 / 255, alpha: 0.18)

let inset = S * 0.08
let tile = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let radius = tile.width * 0.2237

func roundPath(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}

ctx.clear(CGRect(x: 0, y: 0, width: S, height: S))

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: S * 0.012, height: -S * 0.012), blur: 0, color: shadowCol)
ctx.setFillColor(paper)
ctx.addPath(roundPath(tile, radius))
ctx.fillPath()
ctx.restoreGState()

ctx.setFillColor(paper)
ctx.addPath(roundPath(tile, radius))
ctx.fillPath()

ctx.saveGState()
ctx.addPath(roundPath(tile, radius))
ctx.clip()
if let wash = CGGradient(
    colorsSpace: colorSpace,
    colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.4),
             CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
    locations: [0, 1]
) {
    ctx.drawRadialGradient(
        wash,
        startCenter: CGPoint(x: tile.midX, y: tile.maxY - tile.height * 0.12),
        startRadius: 0,
        endCenter: CGPoint(x: tile.midX, y: tile.midY),
        endRadius: tile.width * 0.55,
        options: []
    )
}
ctx.restoreGState()

ctx.setStrokeColor(rule)
ctx.setLineWidth(S * 0.008)
ctx.addPath(roundPath(tile.insetBy(dx: S * 0.004, dy: S * 0.004), radius * 0.96))
ctx.strokePath()

let markBox = tile.insetBy(dx: tile.width * 0.22, dy: tile.height * 0.22)
let stroke = max(S * 0.055, 8)
let arm = markBox.width * 0.22
let gap = markBox.width * 0.14
let cx = markBox.midX, cy = markBox.midY

ctx.setStrokeColor(ink)
ctx.setLineWidth(stroke)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

let loop = arm
for c in [
    CGPoint(x: cx - gap - loop / 2, y: cy + gap + loop / 2),
    CGPoint(x: cx + gap + loop / 2, y: cy + gap + loop / 2),
    CGPoint(x: cx - gap - loop / 2, y: cy - gap - loop / 2),
    CGPoint(x: cx + gap + loop / 2, y: cy - gap - loop / 2),
] {
    let r = CGRect(x: c.x - loop / 2, y: c.y - loop / 2, width: loop, height: loop)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: loop * 0.35, cornerHeight: loop * 0.35, transform: nil))
    ctx.strokePath()
}
ctx.move(to: CGPoint(x: cx - gap - loop / 2, y: cy))
ctx.addLine(to: CGPoint(x: cx + gap + loop / 2, y: cy))
ctx.move(to: CGPoint(x: cx, y: cy - gap - loop / 2))
ctx.addLine(to: CGPoint(x: cx, y: cy + gap + loop / 2))
ctx.strokePath()

let pillW = tile.width * 0.28
let pillH = tile.height * 0.055
let pill = CGRect(x: tile.midX - pillW / 2, y: tile.maxY - tile.height * 0.16 - pillH,
                  width: pillW, height: pillH)
ctx.setFillColor(sage)
ctx.addPath(CGPath(roundedRect: pill, cornerWidth: pillH / 2, cornerHeight: pillH / 2, transform: nil))
ctx.fillPath()

guard let master = ctx.makeImage() else { fputs("no image\n", stderr); exit(1) }

func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    try data.write(to: url)
}

func scaled(_ image: CGImage, to px: Int) -> CGImage {
    guard let c = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return image }
    c.interpolationQuality = .high
    c.draw(image, in: CGRect(x: 0, y: 0, width: px, height: px))
    return c.makeImage() ?? image
}

// Pixel size → unambiguous filename (no @2x).
let outputs: [(String, Int)] = [
    ("icon_16.png", 16),
    ("icon_32.png", 32),
    ("icon_64.png", 64),
    ("icon_128.png", 128),
    ("icon_256.png", 256),
    ("icon_512.png", 512),
    ("icon_1024.png", 1024),
]

for (name, px) in outputs {
    let img = px == masterSize ? master : scaled(master, to: px)
    try writePNG(img, to: iconset.appendingPathComponent(name))
    print("wrote \(name) \(px)x\(px)")
}

let contents = """
{
  "images" : [
    { "size" : "16x16", "idiom" : "mac", "filename" : "icon_16.png", "scale" : "1x" },
    { "size" : "16x16", "idiom" : "mac", "filename" : "icon_32.png", "scale" : "2x" },
    { "size" : "32x32", "idiom" : "mac", "filename" : "icon_32.png", "scale" : "1x" },
    { "size" : "32x32", "idiom" : "mac", "filename" : "icon_64.png", "scale" : "2x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128.png", "scale" : "1x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_256.png", "scale" : "2x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256.png", "scale" : "1x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_512.png", "scale" : "2x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512.png", "scale" : "1x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_1024.png", "scale" : "2x" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
"""
try contents.write(to: iconset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

let catalog = root.appendingPathComponent("LiteCast/Assets.xcassets/Contents.json")
try """
{ "info" : { "author" : "xcode", "version" : 1 } }
""".write(to: catalog, atomically: true, encoding: .utf8)

print("AppIcon.appiconset ready")
