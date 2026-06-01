import Testing
@testable import CodexBreathingLightCore

@Test func defaultOptionsMatchCodexReminderUseCase() throws {
    let options = try AlertOptions.parse([])

    #expect(options.eventKind == .attention)
    #expect(options.effectiveDurationSeconds == 10)
    #expect(options.colorHex == "#FF3B30")
    #expect(options.animation == .breathe)
    #expect(options.thickness == 6)
    #expect(options.blur == 24)
    #expect(options.runUI == false)
    #expect(options.colorWasProvided == false)
}

@Test func parsesUIArgumentsAndIgnoresCodexPayload() throws {
    let options = try AlertOptions.parse([
        "--run-ui",
        "--duration", "12",
        "--color", "#0A84FF",
        "--animation", "pulse",
        "--thickness", "12",
        "--blur", "30",
        "{\"codexUserInputRequestedDuringTurn\":true}"
    ])

    #expect(options.effectiveDurationSeconds == 12)
    #expect(options.colorHex == "#0A84FF")
    #expect(options.animation == .pulse)
    #expect(options.thickness == 12)
    #expect(options.blur == 30)
    #expect(options.runUI == true)
    #expect(options.colorWasProvided == true)
}

@Test func completionPayloadUsesBoopaStyleSuccessFlash() throws {
    let options = try AlertOptions.parse([
        "{\"codexUserInputRequestedDuringTurn\":false}"
    ])

    #expect(options.eventKind == .completion)
    #expect(options.effectiveDurationSeconds == 10)
    #expect(options.colorHex == "#34C759")
    #expect(options.animation == .pulse)
    #expect(options.colorWasProvided == false)
}

@Test func buildsDetachedUIArgumentsWithoutForwardingPayload() throws {
    let options = try AlertOptions.parse([
        "--duration", "60",
        "{\"codexUserInputRequestedDuringTurn\":true}"
    ])

    #expect(options.detachedUIArguments == [
        "--run-ui",
        "--duration", "60",
        "--color", "#FF3B30",
        "--animation", "breathe",
        "--thickness", "6",
        "--blur", "24"
    ])
}

@Test func rejectsNonPositiveDuration() {
    #expect(throws: AlertOptions.ParseError.invalidDuration("0")) {
        try AlertOptions.parse(["--duration", "0"])
    }
}
