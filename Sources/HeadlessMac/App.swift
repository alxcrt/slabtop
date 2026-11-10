import AppKit
import Carbon
import ServiceManagement
import OSLog

private let defaults = UserDefaults.standard
private let displayLog = Logger(subsystem: "com.alxcrt.HalfBook", category: "Displays")
private let projectURL = URL(string: "https://github.com/alxcrt/slabtop")!

final class AppController: NSObject, NSApplicationDelegate {
    private var engine: DisplayEngine?
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private let status = NSTextField(wrappingLabelWithString: "Checking your displays…")
    private let displayList = NSStackView()
    private let automatic = NSSwitch()
    private let login = NSSwitch()
    private let virtualScreens = NSSwitch()
    private var allowVirtual: Bool { defaults.bool(forKey: "allowVirtualScreens") }
    private let applyButton = NSButton(title: "Use external screens", target: nil, action: nil)
    private enum Operation { case useExternal, restore }
    private var operation: Operation?
    private var busy: Bool { operation != nil }
    private var pendingRestore = false
    private var quitting = false
    private var cancellation = Cancellation()
    private var timer: Timer?
    private var hotKeys: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var lastAttempt: Date = .distantPast
    private var failures = 0
    private var previousTopology: [Display]?
    private var lastMessage: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do { engine = try DisplayEngine() } catch { lastMessage = error.localizedDescription }
        if CommandLine.arguments.contains("--auto") { defaults.set(true, forKey: "automatic") }
        buildMenu()
        buildWindow()
        registerShortcuts()
        if CommandLine.arguments.contains("--login"), SMAppService.mainApp.status != .enabled, SMAppService.mainApp.status != .requiresApproval {
            login.state = .on
            toggleLogin()
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        CGDisplayRegisterReconfigurationCallback({ _, flags, context in
            guard !flags.contains(.beginConfigurationFlag), let context else { return }
            let controller = Unmanaged<AppController>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { controller.tick() }
        }, Unmanaged.passUnretained(self).toOpaque())
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
        tick()
        if !CommandLine.arguments.contains("--background") { showWindow() }
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Slabtop")
        let menu = NSMenu()
        menu.addItem(withTitle: "Slabtop…", action: #selector(showWindow), keyEquivalent: "")
        menu.addItem(.separator())
        let useExternal = menu.addItem(withTitle: "Use external screens", action: #selector(applyNow), keyEquivalent: "e")
        useExternal.keyEquivalentModifierMask = [.control, .option, .command]
        let restore = menu.addItem(withTitle: "Restore built-in screen", action: #selector(restoreNow), keyEquivalent: "b")
        restore.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Slabtop", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let useExternalItem = appMenu.addItem(withTitle: "Use external screens", action: #selector(applyNow), keyEquivalent: "e")
        useExternalItem.keyEquivalentModifierMask = [.control, .option, .command]
        useExternalItem.target = self
        let restoreItem = appMenu.addItem(withTitle: "Restore built-in screen", action: #selector(restoreNow), keyEquivalent: "b")
        restoreItem.keyEquivalentModifierMask = [.control, .option, .command]
        restoreItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Slabtop", action: #selector(quit), keyEquivalent: "q").target = self
        let item = NSMenuItem(); item.submenu = appMenu; mainMenu.addItem(item)
        NSApp.mainMenu = mainMenu
    }

    private func text(_ value: String, size: CGFloat = 13, secondary: Bool = false) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.font = .systemFont(ofSize: size)
        label.textColor = secondary ? .secondaryLabelColor : .labelColor
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Slabtop"
        window.minSize = NSSize(width: 460, height: 560)
        window.isReleasedWhenClosed = false
        window.center()

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        window.contentView!.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)
        ])
        let document = FlippedDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(root)
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            root.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
            root.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -20)
        ])

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityLabel("Slabtop")
        icon.widthAnchor.constraint(equalToConstant: 40).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let title = text("Slabtop", size: 23)
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        let identity = NSStackView(views: [title, text("For your screenless Mac.", size: 12, secondary: true)])
        identity.orientation = .vertical
        identity.alignment = .leading
        identity.spacing = 3
        let header = NSStackView(views: [icon, identity])
        header.spacing = 12
        header.alignment = .centerY
        root.addArrangedSubview(header)

        let displayGroup = NSBox()
        displayGroup.boxType = .custom
        displayGroup.borderColor = .separatorColor
        displayGroup.fillColor = .controlBackgroundColor
        displayGroup.cornerRadius = 10
        displayGroup.contentViewMargins = NSSize(width: 14, height: 14)
        let displayContent = NSStackView()
        displayContent.orientation = .vertical
        displayContent.alignment = .leading
        displayContent.spacing = 10
        displayContent.translatesAutoresizingMaskIntoConstraints = false
        displayGroup.contentView!.addSubview(displayContent)
        NSLayoutConstraint.activate([
            displayContent.leadingAnchor.constraint(equalTo: displayGroup.contentView!.leadingAnchor),
            displayContent.trailingAnchor.constraint(equalTo: displayGroup.contentView!.trailingAnchor),
            displayContent.topAnchor.constraint(equalTo: displayGroup.contentView!.topAnchor),
            displayContent.bottomAnchor.constraint(equalTo: displayGroup.contentView!.bottomAnchor)
        ])
        displayList.orientation = .vertical
        displayList.alignment = .leading
        displayList.spacing = 10
        displayContent.addArrangedSubview(displayList)
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.setContentCompressionResistancePriority(.required, for: .vertical)
        status.setAccessibilityIdentifier("display-status")
        displayContent.addArrangedSubview(status)
        applyButton.target = self
        applyButton.action = #selector(applyNow)
        applyButton.bezelStyle = .rounded
        applyButton.controlSize = .large
        applyButton.keyEquivalent = "\r"
        applyButton.toolTip = "Use external screens (⌃⌥⌘E)"
        displayContent.addArrangedSubview(applyButton)
        root.addArrangedSubview(displayGroup)
        for view in [displayList, status, applyButton] {
            view.widthAnchor.constraint(equalTo: displayContent.widthAnchor).isActive = true
        }

        automatic.target = self
        automatic.action = #selector(toggleAutomatic)
        automatic.state = defaults.bool(forKey: "automatic") ? .on : .off
        automatic.setAccessibilityLabel("Use external screens automatically")
        virtualScreens.target = self
        virtualScreens.action = #selector(toggleVirtualScreens)
        virtualScreens.state = allowVirtual ? .on : .off
        virtualScreens.setAccessibilityLabel("Keep the built-in screen off with virtual screens")
        login.target = self
        login.action = #selector(toggleLogin)
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.setAccessibilityLabel("Open Slabtop at login")
        let preferences = NSStackView(views: [
            preferenceRow("Use automatically", detail: "When a wired screen connects or your Mac wakes.", control: automatic),
            separator(),
            preferenceRow("Allow virtual screens", detail: "Keep the built-in screen off while apps such as VITURE SpaceWalker add screens.", control: virtualScreens),
            separator(),
            preferenceRow("Open at login", detail: "Keep Slabtop ready in the menu bar.", control: login)
        ])
        preferences.orientation = .vertical
        preferences.alignment = .leading
        preferences.spacing = 10
        root.addArrangedSubview(preferences)
        for view in preferences.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: preferences.widthAnchor).isActive = true
        }

        let restore = NSButton(title: "Restore built-in screen", target: self, action: #selector(restoreNow))
        restore.bezelStyle = .rounded
        restore.toolTip = "Pause automatic use and restore the built-in screen (⌃⌥⌘B)"
        let recovery = NSStackView(views: [restore, text("⌃⌥⌘B", size: 11, secondary: true)])
        recovery.spacing = 8
        root.addArrangedSubview(recovery)
        root.setCustomSpacing(12, after: preferences)
        root.setCustomSpacing(12, after: recovery)

        let settings = NSButton(title: "Display settings…", target: self, action: #selector(openDisplays))
        settings.bezelStyle = .rounded
        settings.controlSize = .small
        let help = NSButton(title: "Help", target: self, action: #selector(openHelp))
        help.bezelStyle = .rounded
        help.controlSize = .small
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [settings, spacer, help])
        footer.spacing = 8
        root.addArrangedSubview(footer)
        root.setCustomSpacing(8, after: footer)
        root.addArrangedSubview(text("Slabtop stays in the menu bar when this window closes.", size: 11, secondary: true))
        for view in root.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }
    }

    private func separator() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    private func preferenceRow(_ title: String, detail: String, control: NSSwitch) -> NSView {
        let titleLabel = text(title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        let labels = NSStackView(views: [titleLabel, text(detail, size: 11, secondary: true)])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [labels, control])
        row.spacing = 16
        row.distribution = .fill
        row.alignment = .centerY
        labels.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        for label in labels.arrangedSubviews {
            label.widthAnchor.constraint(equalTo: labels.widthAnchor).isActive = true
        }
        return row
    }

    private func displayRow(_ display: Display) -> NSView {
        let icon = NSImageView(image: NSImage(systemSymbolName: "display", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .controlAccentColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 27, weight: .regular)
        icon.widthAnchor.constraint(equalToConstant: 34).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let name = text(display.name, size: 14)
        name.font = .systemFont(ofSize: 14, weight: .semibold)
        let state: String
        if display.active && display.online {
            state = display.mirrored ? "Mirroring" : (display.main ? "Main screen" : "Available")
        } else {
            state = "Connected, preparing desktop"
        }
        let labels = NSStackView(views: [name, text(state, size: 11, secondary: true)])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [icon, labels])
        row.spacing = 10
        row.alignment = .centerY
        for label in labels.arrangedSubviews {
            label.widthAnchor.constraint(equalTo: labels.widthAnchor).isActive = true
        }
        return row
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }

    func applicationDidBecomeActive(_ notification: Notification) { refresh() }

    @objc private func showWindow() {
        refresh()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        quitting = true
        timer?.invalidate()
        cancellation.cancel()
        return busy ? .terminateLater : .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hotKeys.forEach { UnregisterEventHotKey($0) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
    @objc private func openDisplays() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")!) }
    @objc private func openHelp() { NSWorkspace.shared.open(projectURL.appendingPathComponent("blob/main/docs/USER-GUIDE.md")) }
    @objc private func wake() { failures = 0; lastAttempt = .distantPast; DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.tick() } }
    @objc private func toggleAutomatic() {
        defaults.set(automatic.state == .on, forKey: "automatic")
        if automatic.state == .off { cancellation.cancel() }
        failures = 0; lastAttempt = .distantPast; lastMessage = nil; tick()
    }
    @objc private func toggleVirtualScreens() {
        defaults.set(virtualScreens.state == .on, forKey: "allowVirtualScreens")
        failures = 0; lastAttempt = .distantPast; lastMessage = nil; tick()
    }
    @objc private func toggleLogin() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            login.state = .off
            lastMessage = "Move Slabtop to Applications before enabling Open at login."
            refresh()
            return
        }
        do {
            lastMessage = nil
            if login.state == .on {
                if SMAppService.mainApp.status != .enabled && SMAppService.mainApp.status != .requiresApproval {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
            if SMAppService.mainApp.status == .requiresApproval {
                lastMessage = "Allow Slabtop in System Settings, General, Login Items."
            }
        } catch {
            lastMessage = "Could not change Open at login. \(error.localizedDescription)"
        }
        refresh()
    }

    private func tick() {
        guard !busy, !quitting else { return }
        refresh()
        guard defaults.bool(forKey: "automatic"), let engine, engine.supportsChanges,
              let displays = try? engine.snapshot() else { return }
        let cooldown = min(60.0, 5.0 * pow(2, Double(failures)))
        guard Date().timeIntervalSince(lastAttempt) >= cooldown else { return }
        switch Policy.decide(displays, allowVirtual: allowVirtual) {
        case .admit, .externalOnly, .builtinOff: perform(restore: false)
        default: break
        }
    }

    private func refresh(clearMessagesOnChange: Bool = true) {
        let loginStatus = SMAppService.mainApp.status
        login.state = loginStatus == .enabled || loginStatus == .requiresApproval ? .on : .off
        login.toolTip = loginStatus == .requiresApproval ? "Approval needed in System Settings, General, Login Items." : "Open Slabtop at login"
        displayList.arrangedSubviews.forEach { displayList.removeArrangedSubview($0); $0.removeFromSuperview() }
        guard let engine else {
            status.stringValue = lastMessage ?? "Could not check your displays. Quit Slabtop and open it again."
            applyButton.isEnabled = false
            automatic.isEnabled = false
            return
        }
        do {
            let displays = try engine.snapshot()
            if let previousTopology, displays != previousTopology {
                failures = 0
                lastAttempt = .distantPast
                if clearMessagesOnChange { lastMessage = nil }
            }
            previousTopology = displays
            let visible = displays.filter { !$0.builtin && ($0.wired || $0.active || $0.online) }
            for display in visible {
                let row = displayRow(display)
                displayList.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: displayList.widthAnchor).isActive = true
            }
            if visible.isEmpty {
                let prompt = text("Connect your external screen", size: 14)
                prompt.font = .systemFont(ofSize: 14, weight: .semibold)
                displayList.insertArrangedSubview(prompt, at: 0)
                prompt.widthAnchor.constraint(equalTo: displayList.widthAnchor).isActive = true
            }
            automatic.isEnabled = engine.supportsChanges
            let decision = Policy.decide(displays, allowVirtual: allowVirtual)
            switch decision {
            case .admit, .externalOnly, .builtinOff: applyButton.isEnabled = engine.supportsChanges && !busy
            default: applyButton.isEnabled = false
            }
            if !engine.supportsChanges {
                status.stringValue = "Slabtop cannot control displays on this Mac. You can still use Display settings."
                automatic.state = .off
                return
            }
            if let operation {
                if pendingRestore {
                    status.stringValue = "Finishing the current change, then restoring the built-in screen…"
                } else {
                    status.stringValue = operation == .restore ? "Restoring your MacBook's screen…" : "Moving your desktop to your external screens…"
                }
                return
            }
            if let lastMessage {
                status.stringValue = lastMessage
                return
            }
            switch decision {
            case .ready: status.stringValue = visible.count == 1 ? "Your external screen is the only desktop." : "Your desktop is on \(visible.count) external screens."
            case .wait(let reason): status.stringValue = reason
            case .admit: status.stringValue = "Connected. Ready to move your desktop to this screen."
            case .externalOnly: status.stringValue = "Ready to use your external screens without the built-in display."
            case .builtinOff: status.stringValue = "Ready to turn off the built-in display. Virtual screens stay as they are."
            }
        } catch {
            status.stringValue = "Could not check your displays. \(error.localizedDescription)"
            applyButton.isEnabled = false
        }
    }

    @objc func applyNow() { perform(restore: false) }
    @objc func restoreNow() {
        defaults.set(false, forKey: "automatic"); automatic.state = .off
        perform(restore: true)
    }
    private func perform(restore: Bool) {
        guard let engine, (!quitting || restore) else { return }
        if busy {
            if restore { pendingRestore = true; cancellation.cancel(); status.stringValue = "Waiting for the current change, then restoring the built-in display…" }
            return
        }
        cancellation = Cancellation()
        let cancellation = self.cancellation
        let allowVirtual = self.allowVirtual
        operation = restore ? .restore : .useExternal; lastAttempt = Date(); applyButton.isEnabled = false
        status.stringValue = restore ? "Restoring the built-in display…" : "Preparing your external desktop…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<String, Error> = Result { try restore ? engine.restore() : engine.apply(allowVirtual: allowVirtual, cancelled: { cancellation.isCancelled }) }
            DispatchQueue.main.async {
                self.operation = nil
                if self.pendingRestore {
                    self.pendingRestore = false
                    self.perform(restore: true)
                    return
                }
                if self.quitting { NSApp.reply(toApplicationShouldTerminate: true); return }
                switch result {
                case .success: self.lastMessage = nil; self.failures = 0
                case .failure(let error):
                    displayLog.error("\(error.localizedDescription, privacy: .public)")
                    self.lastMessage = error.localizedDescription
                    self.failures = min(self.failures + 1, 4)
                }
                self.refresh(clearMessagesOnChange: false)
            }
        }
    }

    private func registerShortcuts() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard result == noErr else { return result }
            let app = Unmanaged<AppController>.fromOpaque(context).takeUnretainedValue()
            if key.id == 1 { app.applyNow() } else if key.id == 2 { app.restoreNow() }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        guard result == noErr else { lastMessage = "Global shortcuts unavailable. Menu-bar controls still work."; return }
        for (id, code) in [(UInt32(1), UInt32(kVK_ANSI_E)), (UInt32(2), UInt32(kVK_ANSI_B))] {
            var ref: EventHotKeyRef?
            let result = RegisterEventHotKey(code, UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: 0x484D4143, id: id), GetApplicationEventTarget(), 0, &ref)
            if result == noErr, let ref { hotKeys.append(ref) } else { lastMessage = "A recovery shortcut is already in use. Menu-bar controls still work." }
        }
    }
}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class Cancellation {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
