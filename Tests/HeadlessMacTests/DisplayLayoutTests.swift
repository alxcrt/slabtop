import CoreGraphics
import XCTest
@testable import HeadlessMac

final class DisplayLayoutTests: XCTestCase {
    func testSelectingExternalMainPreservesRelativePositionsAcrossThreeScreens() throws {
        let origins: [UInt32: CGPoint] = [2: CGPoint(x: 1512, y: -200),
                                         9: CGPoint(x: 4072, y: 240),
                                         30: CGPoint(x: -408, y: -1280)]

        let translated = try XCTUnwrap(DisplayLayout.translatedOrigins(origins, mainID: 2))

        XCTAssertEqual(translated, [2: .zero, 9: CGPoint(x: 2560, y: 440), 30: CGPoint(x: -1920, y: -1080)])
    }

    func testExistingExternalMainLeavesAllOriginsUnchanged() throws {
        let origins: [UInt32: CGPoint] = [2: CGPoint(x: -2560, y: 120), 9: .zero, 30: CGPoint(x: 1920, y: -400)]

        XCTAssertEqual(try XCTUnwrap(DisplayLayout.translatedOrigins(origins, mainID: 9)), origins)
    }

    func testMissingMainCannotProduceAnArrangement() {
        XCTAssertNil(DisplayLayout.translatedOrigins([2: .zero], mainID: 9))
    }
}
