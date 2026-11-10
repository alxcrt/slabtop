import XCTest
@testable import HeadlessMac

final class PolicyTests: XCTestCase {
    private func display(_ id: UInt32, builtin: Bool = false, wired: Bool = true, active: Bool = true, online: Bool = true, mirrored: Bool = false, main: Bool = false) -> Display {
        Display(id: id, name: "Test", builtin: builtin, wired: wired, active: active, online: online, mirrored: mirrored, main: main)
    }
    func testNeverDisconnectsOnlyDisplay() {
        if case .wait = Policy.decide([display(1, builtin: true, main: true)]) {} else { XCTFail("Must wait") }
    }
    func testAdmitsPendingTVBeforeTouchingInternal() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true, main: true), display(88, active: false, online: false)]), .admit(88))
    }
    func testIgnoresWirelessAndVirtualTargets() {
        if case .wait = Policy.decide([display(1, builtin: true), display(22, wired: false)]) {} else { XCTFail("Must wait") }
    }
    func testDoesNotRearrangeMixedRemoteSession() {
        if case .wait = Policy.decide([display(1, builtin: true), display(22), display(33, wired: false)]) {} else { XCTFail("Must wait") }
    }
    func testMultipleWiredDisplaysUseTheLowestIDWhenBuiltInIsMain() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true, main: true), display(30), display(2)]), .externalOnly(2, [1]))
    }
    func testExistingExternalMainIsPreserved() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true), display(2), display(30, main: true)]), .externalOnly(30, [1]))
    }
    func testPreferredMainCanRestoreTheExternalMainAfterAdmission() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true, active: false, online: false), display(2), display(30, main: true)], preferredMainID: 2), .externalOnly(2, []))
    }
    func testPendingDisplayIsAdmittedWhileOtherExternalsStayActive() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true), display(2, main: true), display(30, active: false, online: false)]), .admit(30))
    }
    func testMultiplePendingDisplaysAreAdmittedInDeterministicOrder() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true), display(30, mirrored: true), display(2, active: false)]), .admit(2))
    }
    func testEveryExternalMustBeOnlineBeforeBuiltInCanBeDisabled() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true), display(2, main: true), display(30, online: false)]), .admit(30))
    }
    func testMultipleExternalDesktopIsReadyOnlyWithBuiltInOff() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true, active: false, online: false), display(2), display(30, main: true)]), .ready)
    }
    func testInactiveUnknownDisplayDoesNotPreventWiredDesktop() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true), display(2, main: true), display(30, wired: false, active: false, online: false)]), .externalOnly(2, [1]))
    }
    func testUsesCurrentIDsAndActiveExternal() {
        XCTAssertEqual(Policy.decide([display(91, builtin: true), display(108, main: true)]), .externalOnly(108, [91]))
    }
    func testStableLayoutNeedsNoMutation() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true, active: false, online: false), display(9, main: true)]), .ready)
    }
    func testMirroredExternalNeedsAdmission() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true), display(7, mirrored: true)]), .admit(7))
    }

    func testVirtualScreensStillPauseByDefault() {
        if case .wait = Policy.decide([display(1, builtin: true), display(2), display(10, wired: false, main: true)]) {} else { XCTFail("Must wait") }
    }
    func testAllowedVirtualScreensOnlyTurnOffTheBuiltInDisplay() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true), display(2), display(10, wired: false, main: true)], allowVirtual: true), .builtinOff([1]))
    }
    func testAllowedVirtualScreensAreReadyOnceBuiltInIsOff() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true, active: false, online: false), display(2), display(10, wired: false, main: true)], allowVirtual: true), .ready)
    }
    func testAllowedVirtualScreensLeaveMirroringAlone() {
        if case .wait = Policy.decide([display(1, builtin: true), display(2, mirrored: true), display(10, wired: false)], allowVirtual: true) {} else { XCTFail("Must wait") }
    }
    func testAllowedVirtualScreensStillAdmitAnInactiveWiredScreen() {
        XCTAssertEqual(Policy.decide([display(1, builtin: true, main: true), display(2, active: false, online: false), display(10, wired: false)], allowVirtual: true), .admit(2))
    }
    func testVirtualScreenAloneNeverTurnsOffTheBuiltInDisplay() {
        if case .wait = Policy.decide([display(1, builtin: true), display(10, wired: false, main: true)], allowVirtual: true) {} else { XCTFail("Must wait") }
    }
}
