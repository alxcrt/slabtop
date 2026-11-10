import CoreGraphics
import IOKit
import Darwin
import Foundation

struct DisplayFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum DisplayChange: Equatable {
    case admit(UInt32)
    case externalOnly(UInt32, [UInt32])
    case builtinOff([UInt32])
    case restore([UInt32])
}

protocol DisplaySystem {
    var supportsChanges: Bool { get }
    func snapshot() throws -> [Display]
    func change(_ change: DisplayChange) throws
}

final class DisplayEngine {
    private let system: DisplaySystem
    private let now: () -> TimeInterval
    private let pause: (TimeInterval) -> Void
    private let verificationTimeout: TimeInterval
    private let lockDirectory: URL
    var supportsChanges: Bool { system.supportsChanges }

    convenience init() throws {
        self.init(system: NativeDisplaySystem())
    }

    init(system: DisplaySystem,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         pause: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) },
         verificationTimeout: TimeInterval = 3,
         lockDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HalfBook", isDirectory: true)) {
        self.system = system
        self.now = now
        self.pause = pause
        self.verificationTimeout = verificationTimeout
        self.lockDirectory = lockDirectory
    }

    func snapshot() throws -> [Display] { try system.snapshot() }

    func apply(allowVirtual: Bool = false, cancelled: () -> Bool = { false }) throws -> String {
        try locked {
            // With virtual screens allowed, their arrival or removal is not a connection change.
            let tracked: ([Display]) -> [Display] = { allowVirtual ? Policy.physical($0) : $0 }
            let initial = try snapshot()
            let builtinIDs = initial.filter(\.builtin).map(\.id)
            let external = initial.filter { !$0.builtin && $0.wired }.sorted { $0.id < $1.id }
            let mainID = external.first(where: \.main)?.id ?? external.first?.id
            switch Policy.decide(initial, allowVirtual: allowVirtual) {
            case .wait(let reason): throw DisplayFailure(message: reason)
            case .ready: return "External-only desktop is ready."
            default: break
            }

            var admittedIDs: Set<UInt32> = []
            var attemptedDisable = false
            do {
                while true {
                    let current = try snapshot()
                    try checkConnections(tracked(initial), tracked(current))
                    try checkCancellation(cancelled)
                    switch Policy.decide(current, preferredMainID: mainID, allowVirtual: allowVirtual) {
                    case .wait(let reason): throw DisplayFailure(message: reason)
                    case .ready: return "External-only desktop is ready."
                    case .admit(let target):
                        guard admittedIDs.insert(target).inserted else {
                            throw DisplayFailure(message: "An external display did not stay active. No built-in output was disconnected.")
                        }
                        try system.change(.admit(target))
                        _ = try waitFor("An external desktop did not become active. No built-in output was disconnected.") { observed in
                            try self.checkCancellation(cancelled)
                            try self.checkConnections(tracked(initial), tracked(observed))
                            return observed.contains { $0.id == target && $0.active && $0.online && !$0.mirrored }
                        }
                    case .externalOnly(let target, let internalIDs):
                        attemptedDisable = !internalIDs.isEmpty
                        try system.change(.externalOnly(target, internalIDs))
                        let after = try waitFor("macOS did not verify an external-only desktop.") { observed in
                            try self.checkConnections(tracked(initial).filter { !$0.builtin }, tracked(observed).filter { !$0.builtin })
                            return Policy.decide(observed, preferredMainID: mainID, allowVirtual: allowVirtual) == .ready
                        }
                        let outputs = after.filter { !$0.builtin && $0.wired }
                        return outputs.count == 1 ? "\(outputs[0].name) is the only desktop." : "\(outputs.count) wired displays are active. Built-in display is off."
                    case .builtinOff(let internalIDs):
                        attemptedDisable = true
                        try system.change(.builtinOff(internalIDs))
                        _ = try waitFor("macOS did not verify the built-in display is off.") { observed in
                            try self.checkConnections(tracked(initial).filter { !$0.builtin }, tracked(observed).filter { !$0.builtin })
                            return Policy.decide(observed, preferredMainID: mainID, allowVirtual: allowVirtual) == .ready
                        }
                        return "Built-in display is off. Virtual screens are left as they are."
                    }
                }
            } catch {
                if cancelled() && !attemptedDisable { throw error }
                throw recover(after: error, builtinIDs: builtinIDs)
            }
        }
    }

    func restore() throws -> String {
        try locked {
            try restoreUnlocked()
            return "Built-in display is active and online."
        }
    }

    private func checkCancellation(_ cancelled: () -> Bool) throws {
        if cancelled() { throw DisplayFailure(message: "External-only change cancelled before disabling built-in output.") }
    }

    private func checkConnections(_ expected: [Display], _ current: [Display]) throws {
        guard Policy.sameConnections(expected, current) else {
            throw DisplayFailure(message: "Display connections changed during the operation. Apply again after checking your screen.")
        }
    }

    private func waitFor(_ failure: String, until verified: ([Display]) throws -> Bool) throws -> [Display] {
        let deadline = now() + verificationTimeout
        while true {
            let current = try snapshot()
            if try verified(current) { return current }
            let remaining = deadline - now()
            guard remaining > 0 else { throw DisplayFailure(message: failure) }
            pause(min(0.1, remaining))
        }
    }

    private func recover(after failure: Error, builtinIDs: [UInt32]) -> DisplayFailure {
        do {
            try restoreUnlocked(knownBuiltinIDs: builtinIDs)
            return DisplayFailure(message: "\(failure.localizedDescription) Built-in output is active and online for recovery.")
        } catch {
            return DisplayFailure(message: "\(failure.localizedDescription) Recovery could not be verified. \(error.localizedDescription)")
        }
    }

    private func restoreUnlocked(knownBuiltinIDs: [UInt32] = []) throws {
        let current: [Display]
        do { current = try snapshot() } catch {
            guard !knownBuiltinIDs.isEmpty else { throw error }
            current = []
        }
        let currentBuiltin = current.filter(\.builtin)
        let ids = currentBuiltin.isEmpty ? knownBuiltinIDs : currentBuiltin.map(\.id)
        guard !ids.isEmpty else { throw DisplayFailure(message: "No built-in display was found for recovery.") }
        if ids.allSatisfy({ id in currentBuiltin.contains { $0.id == id && $0.active && $0.online } }) { return }
        try system.change(.restore(ids))
        _ = try waitFor("macOS did not verify an active, online built-in display.") { observed in
            ids.allSatisfy { id in observed.contains { $0.id == id && $0.builtin && $0.active && $0.online } }
        }
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: lockDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = open(lockDirectory.appendingPathComponent("display.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw DisplayFailure(message: "Cannot open the display operation lock.") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw DisplayFailure(message: "Another display change is running. Try again shortly.") }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }
}

struct DisplayLayout {
    static func translatedOrigins(_ origins: [UInt32: CGPoint], mainID: UInt32) -> [UInt32: CGPoint]? {
        guard let main = origins[mainID] else { return nil }
        return origins.mapValues { CGPoint(x: $0.x - main.x, y: $0.y - main.y) }
    }
}

private final class NativeDisplaySystem: DisplaySystem {
    typealias List = @convention(c) (UInt32, UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<UInt32>?) -> Int32
    typealias Enable = @convention(c) (OpaquePointer?, UInt32, Bool) -> Int32
    typealias Independent = @convention(c) (OpaquePointer?, UInt32, UInt32) -> Int32
    private let library: UnsafeMutableRawPointer?
    private let list: List?
    private let enable: Enable?
    private let independent: Independent?
    let supportsChanges: Bool

    init() {
        let library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
        self.library = library
        func symbol<T>(_ name: String, _: T.Type) -> T? {
            guard let library, let address = dlsym(library, name) else { return nil }
            return unsafeBitCast(address, to: T.self)
        }
        list = symbol("SLSGetDisplayList", List.self)
        enable = symbol("SLSConfigureDisplayEnabled", Enable.self)
        independent = symbol("SLSConfigureDisplayIndependentOutput", Independent.self)
        var arm64: Int32 = 0
        var size = MemoryLayout.size(ofValue: arm64)
        let appleSilicon = sysctlbyname("hw.optional.arm64", &arm64, &size, nil, 0) == 0 && arm64 == 1
        supportsChanges = appleSilicon && list != nil && enable != nil && independent != nil
    }

    deinit { if let library { dlclose(library) } }

    private func wiredProducts() -> [[String: Any]] {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOMobileFramebuffer")!
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var result: [[String: Any]] = []
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            if let attributes = IORegistryEntryCreateCFProperty(entry, "DisplayAttributes" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
               let product = attributes["ProductAttributes"] as? [String: Any] { result.append(product) }
        }
        return result
    }

    func snapshot() throws -> [Display] {
        var ids = [UInt32](repeating: 0, count: 64)
        var count: UInt32 = 0
        if let list { try check(list(64, &ids, &count), "Read connected displays") }
        else { try check(CGGetOnlineDisplayList(64, &ids, &count).rawValue, "Read online displays") }
        guard count <= 64 else { throw DisplayFailure(message: "Too many displays; no changes made.") }
        let products = wiredProducts()
        return ids.prefix(Int(count)).map { id in
            let vendor = CGDisplayVendorNumber(id)
            let model = CGDisplayModelNumber(id)
            let serial = CGDisplaySerialNumber(id)
            let product = products.first {
                ($0["LegacyManufacturerID"] as? NSNumber)?.uint32Value == vendor &&
                ($0["ProductID"] as? NSNumber)?.uint32Value == model &&
                ($0["SerialNumber"] as? NSNumber)?.uint32Value == serial
            }
            let builtin = CGDisplayIsBuiltin(id) != 0
            return Display(id: id, name: builtin ? "Built-in display" : (product?["ProductName"] as? String ?? "Other display"),
                           builtin: builtin, wired: !builtin && product != nil, active: CGDisplayIsActive(id) != 0,
                           online: CGDisplayIsOnline(id) != 0, mirrored: CGDisplayMirrorsDisplay(id) != kCGNullDirectDisplay,
                           main: CGMainDisplayID() == id, identity: "\(vendor):\(model):\(serial)")
        }
    }

    func change(_ change: DisplayChange) throws {
        guard supportsChanges, let enable, let independent else {
            throw DisplayFailure(message: "Native display changes are unavailable on this system. Apple Silicon and the required macOS display services are needed. This system stays read-only.")
        }
        switch change {
        case .admit(let target):
            try transaction { config in
                try check(independent(config, target, 0), "Exit TV sharing output")
                try check(enable(config, target, true), "Enable external display")
                try check(CGConfigureDisplayMirrorOfDisplay(config, target, kCGNullDirectDisplay).rawValue, "Extend external display")
            }
        case .externalOnly(let target, let internalIDs):
            let external = try snapshot().filter { !$0.builtin && $0.wired && $0.active && $0.online && !$0.mirrored }
            let origins = Dictionary(uniqueKeysWithValues: external.map { ($0.id, CGDisplayBounds($0.id).origin) })
            guard let translated = DisplayLayout.translatedOrigins(origins, mainID: target) else {
                throw DisplayFailure(message: "The selected main external display is no longer active.")
            }
            var coordinates: [UInt32: (Int32, Int32)] = [:]
            var modes: [UInt32: CGDisplayMode] = [:]
            for (id, point) in translated {
                guard let x = Int32(exactly: point.x), let y = Int32(exactly: point.y),
                      let mode = CGDisplayCopyDisplayMode(id) else {
                    throw DisplayFailure(message: "Cannot preserve this screen's current mode or position.")
                }
                coordinates[id] = (x, y)
                modes[id] = mode
            }
            // WindowServer rearranges peers when disabling its main output. Apply saved origins after that commit.
            if !internalIDs.isEmpty {
                try transaction { config in
                    for id in internalIDs { try check(enable(config, id, false), "Disconnect built-in display") }
                }
            }
            let current = try snapshot().filter { !$0.builtin }
            guard Policy.sameConnections(external, current.filter { $0.wired }),
                  current.filter(\.wired).allSatisfy({ $0.active && $0.online && !$0.mirrored }) else {
                throw DisplayFailure(message: "External connections changed before arranging the desktop.")
            }
            var changedModes: [UInt32: CGDisplayMode] = [:]
            for (id, saved) in modes where !sameMode(CGDisplayCopyDisplayMode(id), saved) {
                let available = CGDisplayCopyAllDisplayModes(id, [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary) as? [CGDisplayMode] ?? []
                guard let mode = available.first(where: { sameMode($0, saved) }) else {
                    throw DisplayFailure(message: "The previous display mode is no longer available. Check Display settings.")
                }
                changedModes[id] = mode
            }
            if !changedModes.isEmpty {
                try transaction { config in
                    for id in changedModes.keys.sorted() {
                        try check(CGConfigureDisplayWithDisplayMode(config, id, changedModes[id]!, nil).rawValue, "Preserve external display mode")
                    }
                }
            }
            try transaction { config in
                for id in translated.keys.filter({ $0 != target }).sorted() + [target] {
                    let point = coordinates[id]!
                    try check(CGConfigureDisplayOrigin(config, id, point.0, point.1).rawValue, "Preserve external display arrangement")
                }
            }
            guard translated.allSatisfy({ CGDisplayBounds($0.key).origin == $0.value }),
                  modes.allSatisfy({ sameMode(CGDisplayCopyDisplayMode($0.key), $0.value) }) else {
                throw DisplayFailure(message: "macOS did not preserve the external screen modes and arrangement.")
            }
        case .builtinOff(let internalIDs):
            try transaction { config in
                for id in internalIDs { try check(enable(config, id, false), "Disconnect built-in display") }
            }
        case .restore(let internalIDs):
            try transaction { config in
                for id in internalIDs { try check(enable(config, id, true), "Restore built-in display") }
            }
        }
    }

    private func sameMode(_ current: CGDisplayMode?, _ saved: CGDisplayMode) -> Bool {
        guard let current else { return false }
        return current.width == saved.width && current.height == saved.height &&
            current.pixelWidth == saved.pixelWidth && current.pixelHeight == saved.pixelHeight &&
            abs(current.refreshRate - saved.refreshRate) < 0.001 && current.ioFlags == saved.ioFlags
    }

    private func check(_ code: Int32, _ operation: String) throws {
        if code != 0 { throw DisplayFailure(message: "\(operation) failed (macOS error \(code)).") }
    }

    private func transaction(_ body: (CGDisplayConfigRef) throws -> Void) throws {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { throw DisplayFailure(message: "Cannot begin a display change.") }
        do {
            try body(config)
        } catch {
            CGCancelDisplayConfiguration(config)
            throw error
        }
        try check(CGCompleteDisplayConfiguration(config, .forSession).rawValue, "Apply display change")
    }
}
