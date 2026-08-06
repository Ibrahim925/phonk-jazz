import Foundation

/// User configuration: the two playlist URLs the app toggles between.
///
/// Pure and `Codable` so it can be persisted (`ConfigStore`) and unit-tested
/// without a display. The app maps the current `Mode` onto a playlist URL here.
public struct AppConfig: Codable, Equatable, Sendable {
    /// YouTube Music playlist URL for the calm reading mode.
    public var jazzURL: String
    /// YouTube Music playlist URL for the focus/work mode.
    public var phonkURL: String

    /// Creates a config from two playlist URLs.
    public init(jazzURL: String, phonkURL: String) {
        self.jazzURL = jazzURL
        self.phonkURL = phonkURL
    }

    /// The shipped defaults (the user's own playlists).
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
