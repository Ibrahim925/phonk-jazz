import XCTest

@testable import PhonkJazzCore

/// Example test that proves the XCTest framework is wired. It also pins the one
/// invariant the whole app depends on: a single toggle flips jazz<->phonk and is
/// its own inverse.
final class ModeTests: XCTestCase {
    func testToggleFlipsBetweenModes() {
        XCTAssertEqual(Mode.jazz.toggled, .phonk)
        XCTAssertEqual(Mode.phonk.toggled, .jazz)
    }

    func testToggleIsItsOwnInverse() {
        for mode in Mode.allCases {
            XCTAssertEqual(mode.toggled.toggled, mode)
        }
    }
}
