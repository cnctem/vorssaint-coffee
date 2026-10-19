// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A shortcut field: click it, press a combination, and it records. Escape
/// cancels, Delete clears where Delete is not itself part of the combination.
struct ShortcutRecorderField: NSViewRepresentable {
    let shortcut: KeepAwakeShortcut?
    let placeholder: String
    let onChange: (KeepAwakeShortcut?) -> Void
    let onRecordingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onChange = onChange
        view.onRecordingChanged = onRecordingChanged
        view.placeholder = placeholder
        view.shortcut = shortcut
        return view
    }

    func updateNSView(_ view: ShortcutRecorderNSView, context: Context) {
        view.onChange = onChange
        view.onRecordingChanged = onRecordingChanged
        view.placeholder = placeholder
        view.shortcut = shortcut
    }
}

final class ShortcutRecorderNSView: NSView {
    var onChange: ((KeepAwakeShortcut?) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?
    var placeholder = ""
    var shortcut: KeepAwakeShortcut? {
        didSet { needsDisplay = true }
    }

    private var isRecording = false {
        didSet {
            needsDisplay = true
            onRecordingChanged?(isRecording)
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var focusRingMaskBounds: NSRect { bounds }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                      xRadius: 6, yRadius: 6)
        background.fill()
        let borderColor: NSColor = isRecording ? .controlAccentColor : .separatorColor
        borderColor.setStroke()
        background.lineWidth = isRecording ? 1.5 : 1
        background.stroke()

        let text: String
        let color: NSColor
        if isRecording {
            text = placeholder
            color = .secondaryLabelColor
        } else if let shortcut {
            text = shortcut.displayString
            color = .labelColor
        } else {
            text = placeholder
            color = .tertiaryLabelColor
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color,
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: 8, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == UInt16(kVK_Escape) {
            window?.makeFirstResponder(nil)
            return
        }
        let modifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
        if KeepAwakeShortcut.clearsShortcut(keyCode: Int64(event.keyCode), modifiers: modifiers) {
            onChange?(nil)
            window?.makeFirstResponder(nil)
            return
        }
        let candidate = KeepAwakeShortcut(keyCode: Int64(event.keyCode), modifiers: modifiers)
        guard candidate.isValid else {
            NSSound.beep()
            return
        }
        onChange?(candidate)
        window?.makeFirstResponder(nil)
    }

    override func flagsChanged(with event: NSEvent) {
        // Modifiers alone never complete a shortcut.
        needsDisplay = true
    }
}
