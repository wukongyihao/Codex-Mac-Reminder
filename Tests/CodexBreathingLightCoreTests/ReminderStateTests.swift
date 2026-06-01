import Foundation
import Testing
@testable import CodexBreathingLightCore

@Test func missingStateFileDefaultsToEnabled() {
    let store = ReminderStateStore(path: "/tmp/codex-reminder-state-missing.json")

    #expect(store.read().isEnabled)
}

@Test func stateStorePersistsDisabledAndEnabledStates() throws {
    let path = temporaryStatePath("persist")
    let store = ReminderStateStore(path: path)

    try store.write(ReminderState(isEnabled: false))
    #expect(store.read().isEnabled == false)

    try store.write(ReminderState(isEnabled: true))
    #expect(store.read().isEnabled == true)
}

@Test func stateStorePersistsNormalizedAttentionColor() throws {
    let path = temporaryStatePath("color")
    let store = ReminderStateStore(path: path)

    try store.write(ReminderState(isEnabled: false, attentionColorHex: "0a84ff"))

    let state = store.read()
    #expect(state.isEnabled == false)
    #expect(state.attentionColorHex == "#0A84FF")
    #expect(state.effectiveAttentionColorHex == "#0A84FF")
}

@Test func reminderColorNormalizesHexAndNamedColors() {
    #expect(ReminderColor.normalized(" #ff3b30 ") == "#FF3B30")
    #expect(ReminderColor.normalized("0a84ff") == "#0A84FF")
    #expect(ReminderColor.normalized("blue") == "blue")
    #expect(ReminderColor.normalized("") == nil)
    #expect(ReminderColor.normalized("#xyzxyz") == nil)
}

@Test func alertOptionsParsesForceFlagForMenuTestAlerts() throws {
    let options = try AlertOptions.parse([
        "--force",
        "--duration", "2",
        #"{"codexUserInputRequestedDuringTurn":true}"#
    ])

    #expect(options.force == true)
    #expect(options.detachedUIArguments.contains("--force"))
}

@Test func reminderGateAllowsEnabledOrForcedAlerts() {
    #expect(ReminderGate.shouldShowAlert(isEnabled: true, force: false))
    #expect(ReminderGate.shouldShowAlert(isEnabled: false, force: true))
    #expect(ReminderGate.shouldShowAlert(isEnabled: false, force: false) == false)
}

@Test func parsesReminderControlCommands() throws {
    #expect(try ReminderControlCommand.parse(["enable"]) == .enable)
    #expect(try ReminderControlCommand.parse(["disable"]) == .disable)
    #expect(try ReminderControlCommand.parse(["toggle"]) == .toggle)
    #expect(try ReminderControlCommand.parse(["status"]) == .status)
    #expect(try ReminderControlCommand.parse([]) == .status)
}

@Test func appliesReminderControlCommands() throws {
    let path = temporaryStatePath("commands")
    let store = ReminderStateStore(path: path)

    let disabled = try ReminderControlCommand.disable.apply(to: store)
    #expect(disabled.isEnabled == false)
    #expect(store.read().isEnabled == false)

    let enabled = try ReminderControlCommand.toggle.apply(to: store)
    #expect(enabled.isEnabled == true)

    let status = try ReminderControlCommand.status.apply(to: store)
    #expect(status.isEnabled == true)
}

@Test func reminderControlCommandsPreserveAttentionColor() throws {
    let path = temporaryStatePath("commands-color")
    let store = ReminderStateStore(path: path)

    try store.write(ReminderState(isEnabled: true, attentionColorHex: "#AF52DE"))

    let disabled = try ReminderControlCommand.disable.apply(to: store)
    #expect(disabled.isEnabled == false)
    #expect(disabled.attentionColorHex == "#AF52DE")

    let enabled = try ReminderControlCommand.enable.apply(to: store)
    #expect(enabled.isEnabled == true)
    #expect(enabled.attentionColorHex == "#AF52DE")

    let toggled = try ReminderControlCommand.toggle.apply(to: store)
    #expect(toggled.isEnabled == false)
    #expect(toggled.attentionColorHex == "#AF52DE")
}

private func temporaryStatePath(_ name: String) -> String {
    let fileName = "codex-reminder-state-\(name)-\(UUID().uuidString).json"
    return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName).path
}
