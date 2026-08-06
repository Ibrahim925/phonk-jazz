import Foundation
import XCTest

@testable import PhonkJazzCore

/// Contracts for the config subsystem: mode->URL mapping, URL validation, JSON
/// round-trip, and default fallback when nothing is persisted.
final class ConfigTests: XCTestCase {
    func testPlaylistURLMapsByMode() {
        let config = AppConfig(jazzURL: "j", phonkURL: "p")
        XCTAssertEqual(config.playlistURL(for: .jazz), "j")
        XCTAssertEqual(config.playlistURL(for: .phonk), "p")
    }

    func testURLValidation() {
        XCTAssertTrue(
            AppConfig.isValidPlaylistURL("https://music.youtube.com/playlist?list=RDATgy"))
        XCTAssertFalse(AppConfig.isValidPlaylistURL("https://music.youtube.com/"))  // no list=
        XCTAssertFalse(AppConfig.isValidPlaylistURL("https://example.com/?list=x"))  // wrong host
        XCTAssertFalse(AppConfig.isValidPlaylistURL("not a url"))
    }

    func testJSONRoundTrip() throws {
        let store = ConfigStore(directory: makeTempDir())
        let original = AppConfig(
            jazzURL: "https://music.youtube.com/playlist?list=A",
            phonkURL: "https://music.youtube.com/playlist?list=B")
        try store.save(original)
        XCTAssertEqual(store.load(), original)
    }

    func testLoadFallsBackToDefaultsWhenMissing() {
        let store = ConfigStore(directory: makeTempDir())  // nothing saved yet
        XCTAssertEqual(store.load(), AppConfig.defaults)
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pj-test-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }
}
