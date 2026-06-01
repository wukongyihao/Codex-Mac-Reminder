import CodexBreathingLightCore
import Foundation

do {
    let command = try ReminderControlCommand.parse(Array(CommandLine.arguments.dropFirst()))
    let state = try command.apply(to: ReminderStateStore())
    print(state.isEnabled ? "enabled" : "disabled")
} catch {
    fputs("codex-reminder-control: \(error)\n", stderr)
    fputs("usage: codex-reminder-control [enable|disable|toggle|status]\n", stderr)
    exit(2)
}
