import Foundation

/// YouTube Music URL helpers.
public enum YTMURL {
    /// Converts a YTM playlist URL into a *watch* URL that actually starts
    /// playback.
    ///
    /// Navigating to `music.youtube.com/playlist?list=<id>` only shows the
    /// playlist (its `<video>` stays paused with no source). Navigating to
    /// `music.youtube.com/watch?list=<id>` loads the player, auto-selects the
    /// first track, and begins playing. This extracts the `list` id and returns
    /// the watch form; input without a `list` param is returned unchanged.
    public static func watchURL(from urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
            let list = components.queryItems?.first(where: { $0.name == "list" })?.value,
            !list.isEmpty
        else {
            return trimmed
        }
        return "https://music.youtube.com/watch?list=\(list)"
    }
}
