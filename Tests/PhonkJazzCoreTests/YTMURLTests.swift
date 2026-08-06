import XCTest

@testable import PhonkJazzCore

/// The watch-URL transform is what makes playback actually start (verified
/// against the live site: playlist URLs stay paused, watch URLs auto-play).
final class YTMURLTests: XCTestCase {
    func testPlaylistURLBecomesWatchURL() {
        XCTAssertEqual(
            YTMURL.watchURL(from: "https://music.youtube.com/playlist?list=RDATfdcGhvbmsz"),
            "https://music.youtube.com/watch?list=RDATfdcGhvbmsz"
        )
    }

    func testWatchURLIsIdempotent() {
        let watch = "https://music.youtube.com/watch?list=RDATgy"
        XCTAssertEqual(YTMURL.watchURL(from: watch), watch)
    }

    func testURLWithoutListParamIsUnchanged() {
        let noList = "https://music.youtube.com/"
        XCTAssertEqual(YTMURL.watchURL(from: noList), noList)
    }

    func testExtractsListEvenWithOtherParams() {
        XCTAssertEqual(
            YTMURL.watchURL(from: "https://music.youtube.com/watch?v=abc&list=PL123&index=2"),
            "https://music.youtube.com/watch?list=PL123"
        )
    }
}
