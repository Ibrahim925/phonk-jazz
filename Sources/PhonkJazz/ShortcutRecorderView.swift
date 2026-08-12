import AppKit
import PhonkJazzCore

/// A click-to-record shortcut field: click it, press a combination, and it
/// becomes the new binding.
///
/// Key presses are intercepted in `performKeyEquivalent` as well as `keyDown`
/// because AppKit routes combinations like ⌘Q to key-equivalent handling before
/// any view sees a `keyDown` — without that override, recording ⌘-anything would
/// trigger a menu item instead of being captured.
@MainActor
final class ShortcutRecorderView: NSView {
    /// Called with the new binding whenever the user records a valid one.
    var onChange: (Shortcut) -> Void = { _ in }

    /// The binding currently shown.
    private(set) var shortcut: Shortcut

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false

    /// Creates a recorder pre-filled with `shortcut`.
    init(shortcut: Shortcut) {
        self.shortcut = shortcut
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 26),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
        ])

        render()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        render()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        render()
        return true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        return capture(event)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording, capture(event) else {
            super.keyDown(with: event)
            return
        }
    }

    /// Turns a key event into a binding. Returns false when the event should be
    /// handled normally instead of recorded.
    private func capture(_ event: NSEvent) -> Bool {
        // Escape (with no modifiers) cancels recording rather than binding it.
        if event.keyCode == 0x35,
            event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .isEmpty
        {
            window?.makeFirstResponder(nil)
            return true
        }

        let candidate = Shortcut(
            keyCode: event.keyCode,
            modifiers: Self.modifiers(from: event.modifierFlags)
        )
        guard candidate.isValid else {
            label.stringValue = "Add ⌃, ⌥ or ⌘"
            return true  // stay in recording mode and let them try again
        }

        shortcut = candidate
        window?.makeFirstResponder(nil)
        onChange(candidate)
        return true
    }

    private func render() {
        label.stringValue = isRecording ? "Press a combination…" : shortcut.displayString
        label.textColor = isRecording ? .secondaryLabelColor : .labelColor
        layer?.borderColor =
            isRecording ? NSColor.controlAccentColor.cgColor : NSColor.separatorColor.cgColor
        layer?.backgroundColor =
            isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            : NSColor.controlBackgroundColor.cgColor
    }

    /// Translates AppKit's modifier flags into the pure Core representation.
    private static func modifiers(from flags: NSEvent.ModifierFlags) -> ModifierKeys {
        var modifiers: ModifierKeys = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }
}
