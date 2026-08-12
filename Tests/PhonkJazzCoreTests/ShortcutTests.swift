import Foundation
import XCTest

@testable import PhonkJazzCore

/// Contracts for shortcut bindings: how they render, which combinations are
/// legal to register system-wide, and that adding them to `AppConfig` did not
/// break configs written before they existed.
final class ShortcutTests: XCTestCase {
    func testDisplayStringUsesCanonicalModifierOrder() {
        XCTAssertEqual(Shortcut.toggleDefault.displayString, "⌃⌥⌘J")
        XCTAssertEqual(Shortcut.playPauseDefault.displayString, "⌃⌥⌘P")
        // ⇧ sits between ⌥ and ⌘ regardless of insertion order.
        let all = Shortcut(
            keyCode: KeyCodes.space, modifiers: [.command, .shift, .option, .control])
        XCTAssertEqual(all.displayString, "⌃⌥⇧⌘Space")
    }

    func testUnknownKeyCodeStillRenders() {
        XCTAssertEqual(Shortcut(keyCode: 0xFF, modifiers: [.command]).displayString, "⌘Key 255")
    }

    func testValidityRequiresAHardModifier() {
        XCTAssertTrue(Shortcut(keyCode: KeyCodes.p, modifiers: [.control]).isValid)
        XCTAssertTrue(Shortcut(keyCode: KeyCodes.p, modifiers: [.option]).isValid)
        XCTAssertTrue(Shortcut(keyCode: KeyCodes.p, modifiers: [.command]).isValid)
        // Bare keys and Shift-only would swallow ordinary typing in every app.
        XCTAssertFalse(Shortcut(keyCode: KeyCodes.p, modifiers: []).isValid)
        XCTAssertFalse(Shortcut(keyCode: KeyCodes.p, modifiers: [.shift]).isValid)
    }

    func testShortcutSurvivesJSONRoundTrip() throws {
        let shortcut = Shortcut(keyCode: KeyCodes.space, modifiers: [.control, .shift])
        let data = try JSONEncoder().encode(shortcut)
        XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: data), shortcut)
    }

    /// The migration contract: a pre-shortcuts config keeps its playlists and
    /// gains the default bindings. If this ever throws instead, `ConfigStore`
    /// falls back to `.defaults` and the user's playlists vanish.
    func testLegacyConfigWithoutShortcutsDecodesWithDefaults() throws {
        let legacy = """
            {
              "jazzURL": "https://music.youtube.com/playlist?list=LEGACYJ",
              "phonkURL": "https://music.youtube.com/playlist?list=LEGACYP"
            }
            """
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(legacy.utf8))
        XCTAssertEqual(config.jazzURL, "https://music.youtube.com/playlist?list=LEGACYJ")
        XCTAssertEqual(config.phonkURL, "https://music.youtube.com/playlist?list=LEGACYP")
        XCTAssertEqual(config.toggleShortcut, .toggleDefault)
        XCTAssertEqual(config.playPauseShortcut, .playPauseDefault)
    }

    func testCustomBindingsPersistThroughTheStore() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pj-test-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigStore(directory: dir)
        var config = AppConfig.defaults
        config.playPauseShortcut = Shortcut(
            keyCode: KeyCodes.space, modifiers: [.control, .option])
        try store.save(config)

        XCTAssertEqual(store.load(), config)
        XCTAssertEqual(store.load().playPauseShortcut.displayString, "⌃⌥Space")
    }
}
