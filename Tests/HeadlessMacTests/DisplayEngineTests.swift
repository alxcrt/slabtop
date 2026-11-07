import XCTest
@testable import HeadlessMac

final class DisplayEngineTests: XCTestCase {
    private var lockDirectory: URL!
    private let internalID: UInt32 = 1
    private let externalID: UInt32 = 88

    override func setUpWithError() throws {
        lockDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("HeadlessMacTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: lockDirectory.path) { try FileManager.default.removeItem(at: lockDirectory) }
    }

    private func display(_ id: UInt32, builtin: Bool = false, active: Bool = true, online: Bool = true, mirrored: Bool = false, main: Bool = false, identity: String? = nil) -> Display {
        Display(id: id, name: builtin ? "Built-in display" : "Wired screen", builtin: builtin, wired: !builtin,
                active: active, online: online, mirrored: mirrored, main: main, identity: identity)
    }

    private func setup(pending: Bool = false) -> (DisplayEngine, TestDisplaySystem, TestClock) {
        let system = TestDisplaySystem(displays: [display(internalID, builtin: true, main: true),
                                                   display(externalID, active: !pending, online: !pending, identity: "screen-A")])
        let clock = TestClock()
        let engine = DisplayEngine(system: system, now: { clock.time }, pause: { clock.advance($0) },
                                   verificationTimeout: 0.3, lockDirectory: lockDirectory)
        return (engine, system, clock)
    }

    func testReadyDesktopIsANoOpAcrossRepeatedApply() throws {
        let (engine, system, _) = setup()
        system.displays = [display(internalID, builtin: true, active: false, online: false), display(externalID, main: true)]

        _ = try engine.apply()
        _ = try engine.apply()

        XCTAssertTrue(system.changes.isEmpty)
        XCTAssertEqual(Policy.decide(try engine.snapshot()), .ready)
    }

    func testActiveExternalBecomesTheOnlyDesktop() throws {
        let (engine, system, _) = setup()

        let result = try engine.apply()

        XCTAssertEqual(Policy.decide(try engine.snapshot()), .ready)
        XCTAssertEqual(system.changes, [.externalOnly(externalID, [internalID])])
        XCTAssertTrue(result.contains("Wired screen"))
    }

    func testAllActiveWiredDisplaysRemainAvailableAfterBuiltInIsDisabled() throws {
        let (engine, system, _) = setup()
        system.displays.append(display(4, identity: "screen-B"))

        let result = try engine.apply()

        XCTAssertEqual(system.changes, [.externalOnly(4, [internalID])])
        XCTAssertEqual(system.displays.filter { !$0.builtin && $0.active && $0.online }.map(\.id).sorted(), [4, externalID])
        XCTAssertFalse(system.displays.first { $0.builtin }!.active)
        XCTAssertEqual(Policy.decide(system.displays), .ready)
        XCTAssertTrue(result.contains("2 wired displays"))
    }

    func testExistingExternalMainIsRetainedWithMultipleDisplays() throws {
        let (engine, system, _) = setup()
        system.displays = [display(internalID, builtin: true), display(4), display(externalID, main: true)]

        _ = try engine.apply()

        XCTAssertEqual(system.displays.filter(\.main).map(\.id), [externalID])
        XCTAssertTrue(system.displays.filter { !$0.builtin }.allSatisfy { $0.active && $0.online })
        XCTAssertFalse(system.displays.first { $0.builtin }!.active)
    }

    func testAdmissionKeepsTheOriginalExternalMainEvenIfMacOSSelectsAnother() throws {
        let (engine, system, _) = setup()
        system.displays = [display(internalID, builtin: true), display(externalID, main: true),
                           display(99, active: false, online: false, identity: "screen-B")]
        system.onChange = { change in
            if case .externalOnly = change {
                XCTAssertTrue(system.displays.filter { !$0.builtin }.allSatisfy { $0.active && $0.online && !$0.mirrored })
            }
            system.complete(change)
            if case .admit = change {
                system.displays = [self.display(self.internalID, builtin: true), self.display(self.externalID),
                                   self.display(99, main: true, identity: "screen-B")]
            }
        }

        _ = try engine.apply()

        XCTAssertEqual(system.changes, [.admit(99), .externalOnly(externalID, [internalID])])
        XCTAssertEqual(Policy.decide(system.displays), .ready)
        XCTAssertEqual(system.displays.filter(\.main).map(\.id), [externalID])
    }

    func testMultiplePendingExternalsEachWaitForReadbackBeforeBuiltInDisable() throws {
        let (engine, system, clock) = setup(pending: true)
        system.displays.append(display(99, active: false, online: false, identity: "screen-B"))
        var pending: (id: UInt32, readyAt: TimeInterval)?
        system.onChange = { change in
            if case .admit(let target) = change {
                XCTAssertNil(pending)
                pending = (target, clock.time + 0.2)
            } else {
                XCTAssertNil(pending)
                XCTAssertTrue(system.displays.filter { !$0.builtin }.allSatisfy { $0.active && $0.online && !$0.mirrored })
                system.complete(change)
            }
        }
        clock.onAdvance = {
            XCTAssertTrue(system.displays.first { $0.builtin }!.active)
            if let next = pending, clock.time >= next.readyAt {
                system.complete(.admit(next.id))
                pending = nil
            }
        }

        _ = try engine.apply()

        XCTAssertEqual(system.changes, [.admit(externalID), .admit(99), .externalOnly(externalID, [internalID])])
        XCTAssertGreaterThanOrEqual(clock.time, 0.4)
        XCTAssertEqual(Policy.decide(system.displays), .ready)
    }

    func testFailureToActivateOneOfManyExternalsLeavesBuiltInAvailable() {
        let (engine, system, _) = setup()
        system.displays.append(display(99, active: false, online: false, identity: "screen-B"))
        system.onChange = { _ in }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes, [.admit(99)])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
        XCTAssertTrue(system.displays.first { $0.builtin }!.online)
    }

    func testMissingSecondExternalDuringAdmissionPreventsBuiltInDisable() {
        let (engine, system, _) = setup(pending: true)
        system.displays.append(display(99, identity: "screen-B"))
        system.onChange = { change in
            system.complete(change)
            if case .admit = change { system.displays.removeAll { $0.id == 99 } }
        }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes, [.admit(externalID)])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testFreshConnectionsAreCheckedBeforeAdmittingTheNextExternal() {
        let (engine, system, _) = setup(pending: true)
        system.displays.append(display(99, active: false, online: false, identity: "screen-B"))
        var admittedReadbackObserved = false
        system.onChange = { change in
            system.complete(change)
            if case .admit = change {
                system.onRead = {
                    if admittedReadbackObserved { system.displays.removeAll { $0.id == self.externalID } }
                    admittedReadbackObserved = true
                }
            }
        }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes, [.admit(externalID)])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testMissingSecondExternalAfterDisableRestoresBuiltIn() {
        let (engine, system, _) = setup()
        system.displays.append(display(99, identity: "screen-B"))
        system.onChange = { change in
            system.complete(change)
            if case .externalOnly = change { system.displays.removeAll { $0.id == 99 } }
        }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes.last, .restore([internalID]))
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
        XCTAssertTrue(system.displays.first { $0.builtin }!.online)
    }

    func testMultipleExternalDesktopNeedsNoFurtherMutations() throws {
        let (engine, system, _) = setup()
        system.displays = [display(internalID, builtin: true, active: false, online: false),
                           display(externalID, main: true), display(99)]

        _ = try engine.apply()
        _ = try engine.apply()

        XCTAssertTrue(system.changes.isEmpty)
        XCTAssertEqual(Policy.decide(system.displays), .ready)
    }

    func testDisabledBuiltInMayDisappearFromTheDisplayList() throws {
        let (engine, system, _) = setup()
        system.onChange = { change in
            system.complete(change)
            if case .externalOnly = change { system.displays.removeAll { $0.builtin } }
        }

        _ = try engine.apply()

        XCTAssertEqual(Policy.decide(system.displays), .ready)
        XCTAssertEqual(system.changes, [.externalOnly(externalID, [internalID])])
    }

    func testPendingTVWaitsForActiveOnlineUnmirroredOutputBeforeDisablingBuiltIn() throws {
        let (engine, system, clock) = setup(pending: true)
        system.onChange = { change in
            if case .admit = change { return }
            system.complete(change)
        }
        clock.onAdvance = {
            XCTAssertTrue(system.displays.first { $0.builtin }!.active)
            if clock.time >= 0.2 {
                system.displays = [self.display(self.internalID, builtin: true, main: true),
                                   self.display(self.externalID, identity: "screen-A")]
            }
        }

        _ = try engine.apply()

        XCTAssertGreaterThanOrEqual(clock.time, 0.2)
        XCTAssertEqual(system.changes, [.admit(externalID), .externalOnly(externalID, [internalID])])
        XCTAssertEqual(Policy.decide(system.displays), .ready)
    }

    func testNativeSuccessWithInactiveTVNeverDisablesBuiltIn() {
        let (engine, system, clock) = setup(pending: true)
        system.onChange = { _ in }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes, [.admit(externalID)])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
        XCTAssertGreaterThanOrEqual(clock.time, 0.3)
        XCTAssertLessThanOrEqual(clock.time, 0.31)
    }

    func testMirroredTVIsNotAcceptedAsAnIndependentDesktop() {
        let (engine, system, _) = setup()
        system.displays = [display(internalID, builtin: true, main: true), display(externalID, mirrored: true)]
        system.onChange = { _ in }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes, [.admit(externalID)])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testFailedReadbackAfterDisableStillAttemptsAndVerifiesRecovery() {
        let (engine, system, _) = setup()
        system.onChange = { change in
            system.complete(change)
            if case .externalOnly = change { system.readFailure = DisplayFailure(message: "Readback unavailable") }
            if case .restore = change { system.readFailure = nil }
        }

        XCTAssertThrowsError(try engine.apply()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Readback unavailable"))
            XCTAssertTrue(error.localizedDescription.contains("active and online for recovery"))
        }

        XCTAssertEqual(system.changes, [.externalOnly(externalID, [internalID]), .restore([internalID])])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
        XCTAssertTrue(system.displays.first { $0.builtin }!.online)
    }

    func testInactiveExternalAfterDisableRestoresBuiltIn() {
        let (engine, system, _) = setup()
        system.onChange = { change in
            system.complete(change)
            if case .externalOnly = change {
                system.displays = [self.display(self.internalID, builtin: true, active: false, online: false),
                                   self.display(self.externalID, active: false, online: false, identity: "screen-A")]
            }
        }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes.last, .restore([internalID]))
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testMirroredExternalAfterDisableRestoresBuiltIn() {
        let (engine, system, _) = setup()
        system.onChange = { change in
            system.complete(change)
            if case .externalOnly = change {
                system.displays = [self.display(self.internalID, builtin: true, active: false, online: false),
                                   self.display(self.externalID, mirrored: true, main: true, identity: "screen-A")]
            }
        }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes.last, .restore([internalID]))
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testFailedDisableTransactionAlsoRecoversIfItsOutcomeIsUncertain() {
        let (engine, system, _) = setup()
        system.onChange = { change in
            system.complete(change)
            if case .externalOnly = change { throw DisplayFailure(message: "Commit failed") }
        }

        XCTAssertThrowsError(try engine.apply()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Commit failed"))
            XCTAssertTrue(error.localizedDescription.contains("active and online for recovery"))
        }

        XCTAssertEqual(system.changes.last, .restore([internalID]))
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testCancellationAfterFailedDisableStillRestoresBuiltIn() {
        let (engine, system, _) = setup()
        var cancelled = false
        system.onChange = { change in
            system.complete(change)
            if case .externalOnly = change {
                cancelled = true
                throw DisplayFailure(message: "Arrangement failed during cancellation")
            }
        }

        XCTAssertThrowsError(try engine.apply(cancelled: { cancelled }))

        XCTAssertEqual(system.changes.last, .restore([internalID]))
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
        XCTAssertTrue(system.displays.first { $0.builtin }!.online)
    }

    func testOriginalFailureAndFailedRecoveryAreBothReported() {
        let (engine, system, _) = setup()
        system.onChange = { change in
            if case .restore = change { throw DisplayFailure(message: "Restore failed") }
            system.complete(change)
            if case .externalOnly = change { throw DisplayFailure(message: "Disable failed") }
        }

        XCTAssertThrowsError(try engine.apply()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Disable failed"))
            XCTAssertTrue(error.localizedDescription.contains("Restore failed"))
            XCTAssertTrue(error.localizedDescription.contains("Recovery could not be verified"))
        }
    }

    func testRestoreDoesNotClaimSuccessFromAnUnchangedInactiveOutput() {
        let (engine, system, _) = setup()
        system.displays = [display(internalID, builtin: true, active: false, online: false), display(externalID, main: true)]
        system.onChange = { _ in }

        XCTAssertThrowsError(try engine.restore())

        XCTAssertEqual(system.changes, [.restore([internalID])])
        XCTAssertFalse(system.displays.first { $0.builtin }!.active)
    }

    func testRestoreWaitsForBothActiveAndOnlineReadback() throws {
        let (engine, system, clock) = setup()
        system.displays = [display(internalID, builtin: true, active: false, online: false), display(externalID, main: true)]
        system.onChange = { _ in
            system.displays = [self.display(self.internalID, builtin: true, online: false), self.display(self.externalID, main: true)]
        }
        clock.onAdvance = {
            if clock.time >= 0.2 {
                system.displays = [self.display(self.internalID, builtin: true), self.display(self.externalID, main: true)]
            }
        }

        let result = try engine.restore()

        XCTAssertTrue(result.contains("active and online"))
        XCTAssertGreaterThanOrEqual(clock.time, 0.2)
        XCTAssertTrue(system.displays.first { $0.builtin }!.online)
    }

    func testRestoreOfAnAlreadyAvailableBuiltInDoesNotMutate() throws {
        let (engine, system, _) = setup()

        _ = try engine.restore()

        XCTAssertTrue(system.changes.isEmpty)
    }

    func testRecoveryRequestedDuringAdmissionPreventsBuiltInDisable() {
        let (engine, system, _) = setup(pending: true)
        var cancelled = false
        system.onChange = { change in system.complete(change); cancelled = true }

        XCTAssertThrowsError(try engine.apply(cancelled: { cancelled }))

        XCTAssertEqual(system.changes, [.admit(externalID)])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testRecoveryRequestedDuringFreshReadbackPreventsBuiltInDisable() {
        let (engine, system, _) = setup()
        var cancelled = false
        system.onRead = { cancelled = true }

        XCTAssertThrowsError(try engine.apply(cancelled: { cancelled }))

        XCTAssertTrue(system.changes.isEmpty)
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testChangedTargetBetweenAdmissionAndDisableIsRefused() {
        let (engine, system, _) = setup(pending: true)
        system.onChange = { change in
            system.complete(change)
            system.onRead = {
                system.displays = [self.display(self.internalID, builtin: true, main: true), self.display(99, identity: "screen-B")]
            }
        }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes, [.admit(externalID)])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testSameIDWithChangedPhysicalIdentityIsRefusedBeforeDisable() {
        let (engine, system, _) = setup(pending: true)
        system.onChange = { change in
            system.complete(change)
            system.onRead = {
                system.displays = [self.display(self.internalID, builtin: true, main: true),
                                   self.display(self.externalID, identity: "screen-B")]
            }
        }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes, [.admit(externalID)])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }

    func testFreshSnapshotAfterAdmissionMustStillMatchBeforeDisable() {
        let (engine, system, _) = setup(pending: true)
        var admittedReadbackObserved = false
        system.onChange = { change in
            system.complete(change)
            system.onRead = {
                if admittedReadbackObserved {
                    system.displays = [self.display(self.internalID, builtin: true, main: true),
                                       self.display(self.externalID, identity: "screen-B")]
                }
                admittedReadbackObserved = true
            }
        }

        XCTAssertThrowsError(try engine.apply())

        XCTAssertEqual(system.changes, [.admit(externalID)])
        XCTAssertTrue(system.displays.first { $0.builtin }!.active)
    }
}

private final class TestClock {
    var time: TimeInterval = 0
    var onAdvance: (() -> Void)?
    func advance(_ interval: TimeInterval) { time += interval; onAdvance?() }
}

private final class TestDisplaySystem: DisplaySystem {
    let supportsChanges = true
    var displays: [Display]
    var changes: [DisplayChange] = []
    var onChange: ((DisplayChange) throws -> Void)?
    var onRead: (() -> Void)?
    var readFailure: Error?

    init(displays: [Display]) { self.displays = displays }

    func snapshot() throws -> [Display] {
        onRead?()
        if let readFailure { throw readFailure }
        return displays
    }

    func change(_ change: DisplayChange) throws {
        changes.append(change)
        if let onChange { try onChange(change) } else { complete(change) }
    }

    func complete(_ change: DisplayChange) {
        displays = displays.map { display in
            var active = display.active, online = display.online, mirrored = display.mirrored, main = display.main
            switch change {
            case .admit(let target) where display.id == target:
                active = true; online = true; mirrored = false
            case .externalOnly(let target, let internalIDs):
                if internalIDs.contains(display.id) { active = false; online = false; main = false }
                main = display.id == target
            case .restore(let internalIDs) where internalIDs.contains(display.id):
                active = true; online = true
            default: break
            }
            return Display(id: display.id, name: display.name, builtin: display.builtin, wired: display.wired,
                           active: active, online: online, mirrored: mirrored, main: main, identity: display.identity)
        }
    }
}
