import Foundation

/// The modifier keys a `Shortcut` requires.
///
/// Deliberately our own bit set rather than Carbon's or AppKit's: `PhonkJazzCore`
/// stays pure (no Carbon/AppKit import), stable on disk, and unit-testable. The
/// app layer translates these flags into the Carbon mask it registers with.
public struct ModifierKeys: OptionSet, Codable, Equatable, Hashable, Sendable {
    /// The raw bit set. Stable across releases — it is persisted in config.
    public let rawValue: UInt32

    /// Creates a modifier set from its raw bit set.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// The Control key.
    public static let control = ModifierKeys(rawValue: 1 << 0)
    /// The Option (Alt) key.
    public static let option = ModifierKeys(rawValue: 1 << 1)
    /// The Command key.
    public static let command = ModifierKeys(rawValue: 1 << 2)
    /// The Shift key.
    public static let shift = ModifierKeys(rawValue: 1 << 3)

    /// The modifier glyphs in the canonical macOS order (⌃⌥⇧⌘).
    public var displaySymbols: String {
        var symbols = ""
        if contains(.control) { symbols += "⌃" }
        if contains(.option) { symbols += "⌥" }
        if contains(.shift) { symbols += "⇧" }
        if contains(.command) { symbols += "⌘" }
        return symbols
    }
}

/// A global keyboard shortcut: one key plus its modifiers.
///
/// `keyCode` is a hardware-independent macOS virtual key code (the `kVK_*`
/// values), which is what the Carbon hotkey API registers, so the binding
/// follows the physical key regardless of keyboard layout.
public struct Shortcut: Codable, Equatable, Hashable, Sendable {
    /// The macOS virtual key code of the non-modifier key.
    public var keyCode: UInt16
    /// The modifiers that must be held.
    public var modifiers: ModifierKeys

    /// Creates a shortcut from a virtual key code and its modifiers.
    public init(keyCode: UInt16, modifiers: ModifierKeys) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// The default jazz/phonk toggle binding, `⌃⌥⌘J`.
    public static let toggleDefault = Shortcut(
        keyCode: KeyCodes.j, modifiers: [.control, .option, .command]
    )

    /// The default play/pause binding, `⌃⌥⌘P`.
    public static let playPauseDefault = Shortcut(
        keyCode: KeyCodes.p, modifiers: [.control, .option, .command]
    )

    /// Menu-style rendering of the binding, e.g. `⌃⌥⌘P`.
    public var displayString: String {
        modifiers.displaySymbols + KeyCodes.name(for: keyCode)
    }

    /// True if this is safe to register system-wide.
    ///
    /// A global hotkey with no modifier (or Shift alone) would swallow an
    /// ordinary keystroke in every other app, so those combinations are refused.
    public var isValid: Bool {
        !modifiers.intersection([.control, .option, .command]).isEmpty
    }
}

/// macOS virtual key codes and their display names.
///
/// Only the keys a user can plausibly bind are named; anything else renders as
/// its numeric code so an unknown binding is still legible rather than blank.
public enum KeyCodes {
    /// Virtual key code for `J`.
    public static let j: UInt16 = 0x26
    /// Virtual key code for `P`.
    public static let p: UInt16 = 0x23
    /// Virtual key code for Space.
    public static let space: UInt16 = 0x31

    /// The display name of a virtual key code, e.g. `P`, `Space`, `F5`, `←`.
    public static func name(for keyCode: UInt16) -> String {
        if let name = names[keyCode] { return name }
        return "Key \(keyCode)"
    }

    private static let names: [UInt16: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F", 0x05: "G",
        0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N",
        0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T", 0x20: "U",
        0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y", 0x06: "Z",
        0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5", 0x16: "6",
        0x1A: "7", 0x1C: "8", 0x19: "9",
        0x18: "=", 0x1B: "-", 0x21: "[", 0x1E: "]", 0x27: "'", 0x29: ";", 0x2A: "\\",
        0x2B: ",", 0x2F: ".", 0x2C: "/", 0x32: "`",
        0x24: "Return", 0x30: "Tab", 0x31: "Space", 0x33: "Delete", 0x35: "Escape",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
    ]
}
