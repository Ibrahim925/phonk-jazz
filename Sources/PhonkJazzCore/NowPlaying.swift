import Foundation

/// A snapshot of what the embedded player is playing right now.
///
/// Decoded straight from the JSON the metadata script returns, so every field is
/// optional or defaulted: YouTube Music populates its media session
/// asynchronously, and the panel has to render something sane in the gap between
/// "page loaded" and "track known".
public struct NowPlaying: Codable, Equatable, Sendable {
    /// Track title, when known.
    public var title: String?
    /// Artist (media session "artist"), when known.
    public var artist: String?
    /// Album, when known.
    public var album: String?
    /// Largest available artwork URL, when known.
    public var artworkURL: String?
    /// Playback position in seconds.
    public var currentTime: Double
    /// Track length in seconds; zero or non-finite until the media loads.
    public var duration: Double
    /// True while the media element is actually playing.
    public var isPlaying: Bool

    /// Creates a snapshot. Defaults describe "nothing loaded yet".
    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        artworkURL: String? = nil,
        currentTime: Double = 0,
        duration: Double = 0,
        isPlaying: Bool = false
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.currentTime = currentTime
        self.duration = duration
        self.isPlaying = isPlaying
    }

    /// Decodes a snapshot, tolerating missing keys, nulls, and non-finite times.
    ///
    /// `video.duration` is `NaN` before metadata loads, which JSON renders as
    /// `null`; treating that as zero keeps the seek bar at a known-empty state
    /// instead of propagating NaN into layout math.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = Self.nonEmpty(try container.decodeIfPresent(String.self, forKey: .title))
        artist = Self.nonEmpty(try container.decodeIfPresent(String.self, forKey: .artist))
        album = Self.nonEmpty(try container.decodeIfPresent(String.self, forKey: .album))
        artworkURL = Self.nonEmpty(try container.decodeIfPresent(String.self, forKey: .artworkURL))
        currentTime = Self.finite(try container.decodeIfPresent(Double.self, forKey: .currentTime))
        duration = Self.finite(try container.decodeIfPresent(Double.self, forKey: .duration))
        isPlaying = try container.decodeIfPresent(Bool.self, forKey: .isPlaying) ?? false
    }

    /// True when no track identity is known yet.
    public var isEmpty: Bool {
        title == nil && artist == nil && album == nil
    }

    /// Title to show, or a placeholder before the player reports one.
    public var displayTitle: String {
        title ?? "Nothing playing"
    }

    /// Artist and album on one line, omitting whichever is unknown.
    public var displaySubtitle: String {
        [artist, album].compactMap { $0 }.joined(separator: " — ")
    }

    /// Elapsed time as `m:ss`.
    public var elapsedText: String {
        Self.timeText(currentTime)
    }

    /// Total time as `m:ss`, or `--:--` when the duration isn't known yet.
    public var durationText: String {
        duration > 0 ? Self.timeText(duration) : "--:--"
    }

    /// Progress through the track in `0...1`; zero when the duration is unknown.
    ///
    /// Clamped because YTM briefly reports a `currentTime` past the old
    /// `duration` when a track changes, which would otherwise overshoot the
    /// slider.
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    /// The absolute position, in seconds, for a `0...1` slider value.
    public func time(forProgress fraction: Double) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(fraction, 0), 1) * duration
    }

    /// Formats seconds as `m:ss`, or `h:mm:ss` past an hour.
    public static func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let (hours, minutes, secs) = (total / 3600, (total % 3600) / 60, total % 60)
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
        else { return nil }
        return trimmed
    }

    private static func finite(_ value: Double?) -> Double {
        guard let value, value.isFinite, value > 0 else { return 0 }
        return value
    }
}
