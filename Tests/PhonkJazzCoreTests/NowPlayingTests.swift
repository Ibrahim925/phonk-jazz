import Foundation
import XCTest

@testable import PhonkJazzCore

/// Contracts for the now-playing snapshot: it must survive every shape the
/// YouTube Music page can hand back (full metadata, partial, nulls, NaN
/// duration) and turn that into panel-ready text and a bounded progress value.
final class NowPlayingTests: XCTestCase {
    private func decode(_ json: String) throws -> NowPlaying {
        try JSONDecoder().decode(NowPlaying.self, from: Data(json.utf8))
    }

    func testDecodesFullPayload() throws {
        let track = try decode(
            """
            {
              "title": "Nightdrive",
              "artist": "Some Artist",
              "album": "Phonk Vol. 3",
              "artworkURL": "https://lh3.googleusercontent.com/abc=w544-h544",
              "currentTime": 65.4,
              "duration": 182.0,
              "isPlaying": true
            }
            """
        )
        XCTAssertEqual(track.title, "Nightdrive")
        XCTAssertEqual(track.displaySubtitle, "Some Artist — Phonk Vol. 3")
        XCTAssertEqual(track.artworkURL, "https://lh3.googleusercontent.com/abc=w544-h544")
        XCTAssertTrue(track.isPlaying)
        XCTAssertEqual(track.elapsedText, "1:05")
        XCTAssertEqual(track.durationText, "3:02")
        XCTAssertEqual(track.progress, 65.4 / 182.0, accuracy: 0.0001)
        XCTAssertFalse(track.isEmpty)
    }

    /// `video.duration` is NaN until metadata loads and JSON-encodes as null;
    /// that must not leak NaN into the seek bar.
    func testTolerantOfNullsAndMissingKeys() throws {
        let track = try decode(
            """
            { "title": null, "artist": "", "duration": null, "currentTime": 12 }
            """
        )
        XCTAssertNil(track.title)
        XCTAssertNil(track.artist)  // blank strings are not metadata
        XCTAssertTrue(track.isEmpty)
        XCTAssertEqual(track.displayTitle, "Nothing playing")
        XCTAssertEqual(track.displaySubtitle, "")
        XCTAssertEqual(track.duration, 0)
        XCTAssertEqual(track.durationText, "--:--")
        XCTAssertEqual(track.progress, 0)  // never NaN
        XCTAssertFalse(track.isPlaying)
    }

    func testEmptyObjectDecodesToIdleState() throws {
        let track = try decode("{}")
        XCTAssertEqual(track, NowPlaying())
        XCTAssertEqual(track.elapsedText, "0:00")
    }

    func testSubtitleOmitsUnknownHalf() throws {
        let artistOnly = try decode(
            """
            { "artist": "Solo" }
            """)
        XCTAssertEqual(artistOnly.displaySubtitle, "Solo")
        let albumOnly = try decode(
            """
            { "album": "Only Album" }
            """)
        XCTAssertEqual(albumOnly.displaySubtitle, "Only Album")
    }

    func testTimeTextFormatting() {
        XCTAssertEqual(NowPlaying.timeText(0), "0:00")
        XCTAssertEqual(NowPlaying.timeText(-5), "0:00")
        XCTAssertEqual(NowPlaying.timeText(.nan), "0:00")
        XCTAssertEqual(NowPlaying.timeText(9), "0:09")
        XCTAssertEqual(NowPlaying.timeText(59.9), "0:59")  // truncates, never rolls to 1:00
        XCTAssertEqual(NowPlaying.timeText(600), "10:00")
        XCTAssertEqual(NowPlaying.timeText(3725), "1:02:05")
    }

    func testProgressIsClampedAcrossTrackChanges() {
        // YTM can report a position past the previous track's duration mid-switch.
        var track = NowPlaying(currentTime: 500, duration: 180)
        XCTAssertEqual(track.progress, 1)
        track.currentTime = -3
        XCTAssertEqual(track.progress, 0)
    }

    func testSeekTargetFromSliderFraction() {
        let track = NowPlaying(currentTime: 0, duration: 200)
        XCTAssertEqual(track.time(forProgress: 0.25), 50, accuracy: 0.0001)
        XCTAssertEqual(track.time(forProgress: 2), 200, accuracy: 0.0001)  // clamped
        XCTAssertEqual(NowPlaying().time(forProgress: 0.5), 0)  // unknown duration
    }
}
