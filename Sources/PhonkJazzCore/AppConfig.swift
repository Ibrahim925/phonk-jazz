import Foundation

/// User configuration: the two playlist URLs the app toggles between, plus the
/// global shortcut bindings.
///
/// Pure and `Codable` so it can be persisted (`ConfigStore`) and unit-tested
/// without a display. The app maps the current `Mode` onto a playlist URL here.
///
/// Decoding is additive on purpose: a config file written before the shortcut
/// keys existed still decodes, keeping the user's playlists and filling in the
/// default bindings. Never make a new field non-optional in `init(from:)` — a
/// throw there sends `ConfigStore.load()` to `.defaults` and silently discards
/// the user's playlists.
public struct AppConfig: Codable, Equatable, Sendable {
    /// YouTube Music playlist URL for the calm reading mode.
    public var jazzURL: String
    /// YouTube Music playlist URL for the focus/work mode.
    public var phonkURL: String
    /// Global shortcut that flips jazz<->phonk.
    public var toggleShortcut: Shortcut
    /// Global shortcut that toggles play/pause.
    public var playPauseShortcut: Shortcut

    /// Creates a config from two playlist URLs and, optionally, custom bindings.
    public init(
        jazzURL: String,
        phonkURL: String,
        toggleShortcut: Shortcut = .toggleDefault,
        playPauseShortcut: Shortcut = .playPauseDefault
    ) {
        self.jazzURL = jazzURL
        self.phonkURL = phonkURL
        self.toggleShortcut = toggleShortcut
        self.playPauseShortcut = playPauseShortcut
    }

    /// Decodes a config, tolerating files written by older versions.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jazzURL = try container.decode(String.self, forKey: .jazzURL)
        phonkURL = try container.decode(String.self, forKey: .phonkURL)
        toggleShortcut =
            try container.decodeIfPresent(Shortcut.self, forKey: .toggleShortcut)
            ?? .toggleDefault
        playPauseShortcut =
            try container.decodeIfPresent(Shortcut.self, forKey: .playPauseShortcut)
            ?? .playPauseDefault
    }

    /// The shipped defaults (the user's own playlists, default bindings).
    public static let defaults = AppConfig(
        jazzURL: "https://music.youtube.com/playlist?list=RDATgy",
        phonkURL: "https://music.youtube.com/playlist?list=RDATfdcGhvbmsz"
    )

    /// The playlist URL to play for a given mode.
    public func playlistURL(for mode: Mode) -> String {
        switch mode {
        case .jazz: return jazzURL
        case .phonk: return phonkURL
        }
    }

    /// True if `string` is a plausible YouTube Music playlist URL (music.youtube.com
    /// host with a `list=` query). Used to reject bad input before saving.
    public static func isValidPlaylistURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host else { return false }
        return host.contains("music.youtube.com") && (url.query?.contains("list=") ?? false)
    }
}
