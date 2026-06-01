import AppKit
import Carbon.HIToolbox
import CodexBreathingLightCore
import Foundation

@MainActor
final class ReminderAgentDelegate: NSObject, NSApplicationDelegate {
    private let store = ReminderStateStore()
    private let requestURL = URL(fileURLWithPath: "/Users/xiaoming/.codex/codex-reminder-request.json")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var requestTimer: Timer?
    private var lastRequestID: Int64?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenu()
        registerHotKey()
        startRequestPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func setupMenu() {
        statusItem.button?.title = store.read().isEnabled ? "Codex" : "Codex off"
        refreshMenu()
    }

    private func refreshMenu() {
        let state = store.read()
        let isEnabled = state.isEnabled
        statusItem.button?.title = isEnabled ? "Codex" : "Codex off"

        let menu = NSMenu()
        let toggleTitle = isEnabled ? "暂停提醒" : "启用提醒"
        menu.addItem(NSMenuItem(title: toggleTitle, action: #selector(toggleReminder), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "测试提醒", action: #selector(testReminder), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "调整提醒颜色...", action: #selector(changeReminderColor), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "当前颜色: \(state.effectiveAttentionColorHex)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "快捷键: ^⌥⌘N", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    private func startRequestPolling() {
        requestTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingRequest()
            }
        }
    }

    private func processPendingRequest() {
        guard let data = try? Data(contentsOf: requestURL),
              let request = try? JSONDecoder().decode(ReminderRequest.self, from: data),
              request.id != lastRequestID else {
            return
        }

        lastRequestID = request.id
        log("process request id=\(request.id) args=\(request.arguments.joined(separator: " "))")
        launchNotifier(arguments: ["--run-ui"] + request.arguments)
    }

    @objc private func toggleReminder() {
        let state = try? ReminderControlCommand.toggle.apply(to: store)
        log("toggle reminder: \(state?.isEnabled == true ? "enabled" : "disabled")")
        refreshMenu()
    }

    @objc private func testReminder() {
        log("test reminder requested")
        let colorHex = store.read().effectiveAttentionColorHex
        launchNotifier(arguments: [
            "--run-ui",
            "--force",
            "--duration", "3",
            "--color", colorHex,
            "--animation", "pulse",
            #"{"codexUserInputRequestedDuringTurn":true}"#
        ])
    }

    @objc private func changeReminderColor() {
        let state = store.read()
        let alert = NSAlert()
        alert.messageText = "调整提醒颜色"
        alert.informativeText = "输入基准颜色，支持 #RRGGBB、RRGGBB，或 red/green/blue/orange/yellow/cyan/purple/pink。留空恢复默认红色。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存并预览")
        alert.addButton(withTitle: "取消")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 28))
        textField.placeholderString = ReminderColor.defaultAttentionColorHex
        textField.stringValue = state.attentionColorHex ?? ""
        alert.accessoryView = textField

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let input = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.isEmpty || ReminderColor.normalized(input) != nil else {
            showMessage(title: "颜色格式不对", message: "请输入类似 #FF3B30、0A84FF 或 blue 的颜色。")
            return
        }

        let normalizedColor = ReminderColor.normalized(input)
        var updatedState = state
        updatedState.attentionColorHex = normalizedColor

        do {
            try store.write(updatedState)
            log("attention color changed to \(updatedState.effectiveAttentionColorHex)")
            refreshMenu()
            previewReminder(colorHex: updatedState.effectiveAttentionColorHex)
        } catch {
            log("failed to write reminder color: \(error)")
            showMessage(title: "保存失败", message: "\(error)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func previewReminder(colorHex: String) {
        launchNotifier(arguments: [
            "--run-ui",
            "--force",
            "--duration", "3",
            "--color", colorHex,
            "--animation", "pulse",
            #"{"codexUserInputRequestedDuringTurn":true}"#
        ])
    }

    private func showMessage(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func launchNotifier(arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Users/xiaoming/.codex/bin/codex-breathing-light-ui")
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            log("launched test reminder pid=\(process.processIdentifier)")
        } catch {
            log("failed to launch test reminder: \(error)")
        }
    }

    private func registerHotKey() {
        let hotKeyID = EventHotKeyID(signature: fourCharCode("CDXR"), id: 1)
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            NSLog("codex-reminder-agent: failed to register hot key: \(status)")
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else {
                return noErr
            }
            let delegate = Unmanaged<ReminderAgentDelegate>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                delegate.toggleReminder()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }

    private func log(_ message: String) {
        NSLog("codex-reminder-agent: \(message)")
    }
}

private struct ReminderRequest: Decodable {
    var id: Int64
    var arguments: [String]
}

let app = NSApplication.shared
let delegate = ReminderAgentDelegate()
app.delegate = delegate
withExtendedLifetime(delegate) {
    app.run()
}
