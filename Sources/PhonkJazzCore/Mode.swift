/// The two listening modes the app toggles between.
///
/// `jazz` is the calm reading mode; `phonk` is the focus/work mode. This is the
/// core domain seam: the menubar, the global hotkey, and the settings window all
/// map user intent onto a `Mode`, and the WebKit layer plays the matching
/// playlist. Keeping it here (pure, no AppKit) makes the toggle logic testable
/// without a display.
public enum Mode: String, CaseIterable, Sendable {
    case jazz
    case phonk

    /// The opposite mode. A single toggle action flips between the two.
    public var toggled: Mode {
        switch self {
        case .jazz: return .phonk
        case .phonk: return .jazz
        }
    }

    /// Short label suitable for a menubar status item.
    public var shortLabel: String {
        switch self {
        case .jazz: return "JZ"
        case .phonk: return "PH"
        }
    }
}
