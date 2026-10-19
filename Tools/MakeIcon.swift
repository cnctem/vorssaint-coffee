// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// Generates the app iconset and .icns. The artwork is drawn here so the icon
// has no binary masters to keep in sync: a warm coffee cup on a dark espresso
// squircle, the same glyph the menu bar offers.
import AppKit

// Current macOS misreads PNG payloads in the legacy small chunks. It downsamples
// ic07 for 1x and uses the explicit ic11/ic12 representations on Retina displays.
let iconSizes: [(name: String, px: Int, icnsType: String?)] = [
    ("icon_16x16", 16, nil), ("icon_16x16@2x", 32, "ic11"),
    ("icon_32x32", 32, nil), ("icon_32x32@2x", 64, "ic12"),
    ("icon_128x128", 128, "ic07"), ("icon_128x128@2x", 256, "ic13"),
    ("icon_256x256", 256, "ic08"), ("icon_256x256@2x", 512, "ic14"),
    ("icon_512x512", 512, "ic09"), ("icon_512x512@2x", 1024, "ic10"),
]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"

func bitmapCanvas(_ px: Int, _ py: Int) -> NSBitmapImageRep? {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: py,
                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                     isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)
}

private let cream = NSColor(srgbRed: 0.965, green: 0.905, blue: 0.805, alpha: 1)
private let creamShade = NSColor(srgbRed: 0.885, green: 0.795, blue: 0.665, alpha: 1)
private let espresso = NSColor(srgbRed: 0.235, green: 0.135, blue: 0.080, alpha: 1)
private let backgroundTop = NSColor(srgbRed: 0.420, green: 0.270, blue: 0.180, alpha: 1)
private let backgroundBottom = NSColor(srgbRed: 0.150, green: 0.085, blue: 0.055, alpha: 1)

/// Draws one icon on a 1024-unit canvas, scaled to `rect`.
func drawCoffeeIcon(in rect: NSRect) {
    let unit = rect.width / 1024

    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
    }
    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: rect.minX + x * unit, y: rect.minY + y * unit,
               width: w * unit, height: h * unit)
    }

    // The squircle: the standard Big Sur grid, 824 of 1024 with a 185 radius.
    let squircle = NSBezierPath(roundedRect: box(100, 100, 824, 824),
                                xRadius: 185 * unit, yRadius: 185 * unit)
    NSGradient(colors: [backgroundTop, backgroundBottom])?.draw(in: squircle, angle: -90)

    // A hairline of light along the top edge gives the body a rounded feel.
    let highlight = NSBezierPath(roundedRect: box(108, 108, 808, 808),
                                 xRadius: 178 * unit, yRadius: 178 * unit)
    NSColor.white.withAlphaComponent(0.10).setStroke()
    highlight.lineWidth = 5 * unit
    highlight.stroke()

    // Saucer: an ellipse with a shaded lower rim and a cream top.
    let saucerShadow = NSBezierPath(ovalIn: box(236, 236, 552, 96))
    NSColor.black.withAlphaComponent(0.22).setFill()
    saucerShadow.fill()
    let saucer = NSBezierPath(ovalIn: box(240, 252, 544, 88))
    creamShade.setFill()
    saucer.fill()
    let saucerTop = NSBezierPath(ovalIn: box(272, 268, 480, 58))
    cream.setFill()
    saucerTop.fill()

    // Handle first, so the cup body hides the part that meets it.
    let handle = NSBezierPath(ovalIn: box(664, 366, 214, 196))
    handle.lineWidth = 48 * unit
    cream.setStroke()
    handle.stroke()

    // Cup body: a gently tapered vessel with rounded corners.
    let body = NSBezierPath()
    body.move(to: point(314, 560))
    body.line(to: point(344, 348))
    body.curve(to: point(392, 304), controlPoint1: point(346, 318), controlPoint2: point(366, 304))
    body.line(to: point(632, 304))
    body.curve(to: point(680, 348), controlPoint1: point(658, 304), controlPoint2: point(678, 318))
    body.line(to: point(710, 560))
    body.close()
    cream.setFill()
    body.fill()

    // Rim and the coffee inside it.
    let rim = NSBezierPath(ovalIn: box(302, 516, 420, 88))
    cream.setFill()
    rim.fill()
    let coffee = NSBezierPath(ovalIn: box(332, 534, 360, 54))
    espresso.setFill()
    coffee.fill()
    // A soft crescent of reflected light on the coffee surface.
    let reflection = NSBezierPath(ovalIn: box(372, 545, 190, 26))
    NSColor.white.withAlphaComponent(0.10).setFill()
    reflection.fill()

    // Steam: three S-curves rising from the cup.
    NSColor.white.withAlphaComponent(0.52).setStroke()
    for x in [420.0, 512.0, 604.0] {
        let steam = NSBezierPath()
        steam.lineWidth = 27 * unit
        steam.lineCapStyle = .round
        steam.move(to: point(x, 636))
        steam.curve(to: point(x, 706), controlPoint1: point(x + 34, 654),
                    controlPoint2: point(x + 34, 688))
        steam.curve(to: point(x, 776), controlPoint1: point(x - 34, 724),
                    controlPoint2: point(x - 34, 758))
        steam.stroke()
    }
}

func renderAppIcon(px: Int) -> Data? {
    guard let rep = bitmapCanvas(px, px), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    drawCoffeeIcon(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

func appendFourCC(_ value: String, to data: inout Data) {
    data.append(contentsOf: value.utf8)
}

func appendUInt32BE(_ value: Int, to data: inout Data) {
    let clamped = UInt32(value)
    data.append(UInt8((clamped >> 24) & 0xff))
    data.append(UInt8((clamped >> 16) & 0xff))
    data.append(UInt8((clamped >> 8) & 0xff))
    data.append(UInt8(clamped & 0xff))
}

func writeICNS(entries: [(type: String, data: Data)], to url: URL) throws {
    let totalLength = 8 + entries.reduce(0) { $0 + 8 + $1.data.count }
    var icns = Data()
    appendFourCC("icns", to: &icns)
    appendUInt32BE(totalLength, to: &icns)
    for entry in entries {
        appendFourCC(entry.type, to: &icns)
        appendUInt32BE(8 + entry.data.count, to: &icns)
        icns.append(entry.data)
    }
    try icns.write(to: url)
}

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
var icnsEntries: [(type: String, data: Data)] = []
for (name, px, icnsType) in iconSizes {
    guard let data = renderAppIcon(px: px) else {
        print("failed to render \(name)")
        exit(1)
    }
    try data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    if let icnsType {
        icnsEntries.append((type: icnsType, data: data))
    }
}
try writeICNS(entries: icnsEntries, to: URL(fileURLWithPath: "\(outDir)/../AppIcon.icns"))
print("iconset written to \(outDir)")
