import CodexBreathingLightCore
import Foundation

func launchDetachedUI(options: AlertOptions) throws {
    let uiPath = "/Users/xiaoming/.codex/bin/codex-breathing-light-ui"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: uiPath)
    process.arguments = options.detachedUIArguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
}

do {
    var options = try AlertOptions.parse(Array(CommandLine.arguments.dropFirst()))
    let reminderState = ReminderStateStore().read()
    if options.eventKind == .attention, !options.colorWasProvided {
        options.colorHex = reminderState.effectiveAttentionColorHex
    }
    guard ReminderGate.shouldShowAlert(isEnabled: reminderState.isEnabled, force: options.force) else {
        exit(0)
    }

    try launchDetachedUI(options: options)
} catch {
    fputs("codex-breathing-light: \(error)\n", stderr)
    exit(2)
}
