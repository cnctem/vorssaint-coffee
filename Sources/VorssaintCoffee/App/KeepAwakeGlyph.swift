// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// The menu bar glyph. The chosen shape is a template image in the idle state,
/// so it follows the menu bar's light or dark appearance; an active session
/// tints the same shape with the chosen color. The dot is the one shape that
/// gets out of the way while a session runs.
enum KeepAwakeGlyph {
    /// Logical size of the glyph in the menu bar, in points.
    static let pointSize = NSSize(width: 26, height: 20)

    /// Requested ink height for system symbols.
    private static let symbolHeight: CGFloat = 16

    /// The image for the menu bar, or nil when an active dot session should
    /// leave the slot to the countdown text alone.
    static func image(active: Bool) -> NSImage? {
        let style = KeepAwakeActiveIcon.current
        if active, style == .dot { return nil }
        guard active else { return templateImage(style: style) }
        return activeImage(style: style, tint: .current)
    }

    /// The shape in the active color. Also used by the icon picker, where even
    /// the dot is shown.
    static func activeImage(style: KeepAwakeActiveIcon,
                            tint: KeepAwakeIconTint = .orange) -> NSImage? {
        guard let source = templateImage(style: style) else { return fallback(active: tint != .none) }
        guard let color = color(for: tint) else {
            source.isTemplate = true
            return source
        }
        return tintedImage(source, color: color) ?? fallback(active: true)
    }

    /// The shape as a template image, filled with the menu bar's own color.
    static func templateImage(style: KeepAwakeActiveIcon) -> NSImage? {
        if style == .dot { return dotImage() }
        guard let symbolName = style.systemSymbolName else { return nil }
        return fixedSizeSymbol(named: symbolName, drop: style.menuBarDrop)
    }

    /// A small centered disc: the "·" choice, quiet until a session starts.
    private static func dotImage() -> NSImage? {
        let dot: CGFloat = 5.5
        let image = NSImage(size: pointSize, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.midX - dot / 2,
                                        y: rect.midY - dot / 2,
                                        width: dot, height: dot)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// System symbols have different natural widths. Center them inside the
    /// same canvas as the app glyph so activation never shifts nearby items.
    private static func fixedSizeSymbol(named name: String, drop: CGFloat = 0) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .semibold)),
              symbol.size.width > 0,
              symbol.size.height > 0,
              let ink = inkBounds(of: symbol),
              ink.width > 0, ink.height > 0 else { return nil }
        let scale = min(symbolHeight / ink.height, (pointSize.width - 2) / ink.width)
        let drawSize = NSSize(width: symbol.size.width * scale,
                              height: symbol.size.height * scale)
        let inkOrigin = NSPoint(x: ink.minX * scale, y: ink.minY * scale)
        let inkSize = NSSize(width: ink.width * scale, height: ink.height * scale)
        let image = NSImage(size: pointSize, flipped: false) { rect in
            let target = NSRect(x: rect.midX - inkOrigin.x - inkSize.width / 2,
                                y: rect.midY - inkOrigin.y - inkSize.height / 2 - drop,
                                width: drawSize.width,
                                height: drawSize.height)
            symbol.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Bounding box of an image's visible pixels, in its own (bottom-up) point
    /// space. Only runs when the menu bar icon changes, so rasterizing is cheap.
    private static func inkBounds(of image: NSImage) -> NSRect? {
        let sampling = 2
        let wide = Int(ceil(image.size.width)) * sampling
        let high = Int(ceil(image.size.height)) * sampling
        guard wide > 0, high > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: wide, pixelsHigh: high,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        // The context comes from the rep's pixel dimensions, so it draws in
        // pixels; fill the whole bitmap and scale the bounds back down.
        image.draw(in: NSRect(x: 0, y: 0, width: CGFloat(wide), height: CGFloat(high)))
        NSGraphicsContext.restoreGraphicsState()

        var minX = wide, minY = high, maxX = -1, maxY = -1
        for y in 0..<high {
            for x in 0..<wide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let unit = CGFloat(sampling)
        return NSRect(x: CGFloat(minX) / unit,
                      y: CGFloat(high - 1 - maxY) / unit,
                      width: CGFloat(maxX - minX + 1) / unit,
                      height: CGFloat(maxY - minY + 1) / unit)
    }

    private static func tintedImage(_ source: NSImage, color: NSColor) -> NSImage? {
        let tinted = NSImage(size: source.size, flipped: false) { rect in
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            color.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
    }

    private static func color(for tint: KeepAwakeIconTint) -> NSColor? {
        switch tint {
        case .orange: return .systemOrange
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .pink: return .systemPink
        case .none: return nil
        }
    }

    /// Keeps a recognizable presence if the bundled asset is ever missing
    /// (e.g. running the bare binary from build/).
    private static func fallback(active: Bool) -> NSImage? {
        if let symbol = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: AppInfo.name)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: active ? .bold : .regular)) {
            symbol.isTemplate = true
            return symbol
        }
        let drawn = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)).fill()
            return true
        }
        drawn.isTemplate = true
        return drawn
    }
}
