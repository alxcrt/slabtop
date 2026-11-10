import AppKit
import ServiceManagement

private struct Diagnostics: Encodable {
    let supportsChanges: Bool
    let automatic: Bool
    let allowVirtualScreens: Bool
    let loginStatus: Int
    let displays: [Display]
}

if CommandLine.arguments.dropFirst().first == "--diagnostics" {
    do {
        let engine = try DisplayEngine()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(Diagnostics(supportsChanges: engine.supportsChanges, automatic: UserDefaults.standard.bool(forKey: "automatic"), allowVirtualScreens: UserDefaults.standard.bool(forKey: "allowVirtualScreens"), loginStatus: SMAppService.mainApp.status.rawValue, displays: engine.snapshot())), as: UTF8.self))
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
} else {
    let app = NSApplication.shared
    let existing = NSRunningApplication.runningApplications(withBundleIdentifier: "com.alxcrt.HalfBook").first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if let existing { existing.activate(options: [.activateAllWindows]); exit(0) }
    app.setActivationPolicy(.accessory)
    let delegate = AppController()
    app.delegate = delegate
    app.run()
}
