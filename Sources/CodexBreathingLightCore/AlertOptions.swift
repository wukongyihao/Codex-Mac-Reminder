import Foundation

public enum GlowAnimation: String, Equatable {
    case breathe
    case pulse
    case solid
}

public enum AlertEventKind: Equatable {
    case attention
    case completion
}

public struct AlertOptions: Equatable {
    public enum ParseError: Error, Equatable {
        case missingValue(String)
        case invalidDuration(String)
        case invalidThickness(String)
        case invalidBlur(String)
        case invalidAnimation(String)
        case unknownArgument(String)
    }

    public var eventKind: AlertEventKind
    public var durationSeconds: Int?
    public var colorHex: String
    public var animation: GlowAnimation
    public var thickness: Int
    public var blur: Int
    public var runUI: Bool
    public var force: Bool
    public var colorWasProvided: Bool

    public init(
        eventKind: AlertEventKind = .attention,
        durationSeconds: Int? = nil,
        colorHex: String? = nil,
        animation: GlowAnimation? = nil,
        thickness: Int = 6,
        blur: Int = 24,
        runUI: Bool = false,
        force: Bool = false,
        colorWasProvided: Bool = false
    ) {
        self.eventKind = eventKind
        self.durationSeconds = durationSeconds
        self.colorHex = colorHex ?? Self.defaultColor(for: eventKind)
        self.animation = animation ?? Self.defaultAnimation(for: eventKind)
        self.thickness = thickness
        self.blur = blur
        self.runUI = runUI
        self.force = force
        self.colorWasProvided = colorWasProvided
    }

    public static func parse(_ arguments: [String]) throws -> AlertOptions {
        var eventKind: AlertEventKind = .attention
        var durationSeconds: Int?
        var colorHex: String?
        var animation: GlowAnimation?
        var thickness = 6
        var blur = 24
        var runUI = false
        var force = false
        var colorWasProvided = false
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            if argument == "--run-ui" {
                runUI = true
                index += 1
                continue
            }

            if argument == "--force" {
                force = true
                index += 1
                continue
            }

            if argument == "--duration" {
                let value = try value(after: argument, in: arguments, at: index)
                guard let duration = Int(value), duration > 0 else {
                    throw ParseError.invalidDuration(value)
                }
                durationSeconds = duration
                index += 2
                continue
            }

            if argument == "--color" {
                colorHex = try value(after: argument, in: arguments, at: index)
                colorWasProvided = true
                index += 2
                continue
            }

            if argument == "--animation" {
                let value = try value(after: argument, in: arguments, at: index)
                guard let parsed = GlowAnimation(rawValue: value.lowercased()) else {
                    throw ParseError.invalidAnimation(value)
                }
                animation = parsed
                index += 2
                continue
            }

            if argument == "--thickness" {
                let value = try value(after: argument, in: arguments, at: index)
                guard let parsed = Int(value), parsed > 0 else {
                    throw ParseError.invalidThickness(value)
                }
                thickness = parsed
                index += 2
                continue
            }

            if argument == "--blur" {
                let value = try value(after: argument, in: arguments, at: index)
                guard let parsed = Int(value), parsed >= 0 else {
                    throw ParseError.invalidBlur(value)
                }
                blur = parsed
                index += 2
                continue
            }

            if let payloadKind = eventKindFromPayload(argument) {
                eventKind = payloadKind
                index += 1
                continue
            }

            if isCodexPayload(argument) {
                index += 1
                continue
            }

            throw ParseError.unknownArgument(argument)
        }

        return AlertOptions(
            eventKind: eventKind,
            durationSeconds: durationSeconds,
            colorHex: colorHex,
            animation: animation,
            thickness: thickness,
            blur: blur,
            runUI: runUI,
            force: force,
            colorWasProvided: colorWasProvided
        )
    }

    public var effectiveDurationSeconds: Int {
        durationSeconds ?? Self.defaultDuration(for: eventKind)
    }

    public var detachedUIArguments: [String] {
        [
            "--run-ui",
            "--duration", "\(effectiveDurationSeconds)",
            "--color", colorHex,
            "--animation", animation.rawValue,
            "--thickness", "\(thickness)",
            "--blur", "\(blur)"
        ] + (force ? ["--force"] : [])
    }

    private static func value(
        after option: String,
        in arguments: [String],
        at index: Int
    ) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw ParseError.missingValue(option)
        }
        return arguments[valueIndex]
    }

    private static func eventKindFromPayload(_ argument: String) -> AlertEventKind? {
        guard isCodexPayload(argument),
              let data = argument.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requestedInput = json["codexUserInputRequestedDuringTurn"] as? Bool else {
            return nil
        }
        return requestedInput ? .attention : .completion
    }

    private static func isCodexPayload(_ argument: String) -> Bool {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
    }

    private static func defaultDuration(for eventKind: AlertEventKind) -> Int {
        switch eventKind {
        case .attention, .completion: return 10
        }
    }

    private static func defaultColor(for eventKind: AlertEventKind) -> String {
        switch eventKind {
        case .attention: return ReminderColor.defaultAttentionColorHex
        case .completion: return "#34C759"
        }
    }

    private static func defaultAnimation(for eventKind: AlertEventKind) -> GlowAnimation {
        switch eventKind {
        case .attention: return .breathe
        case .completion: return .pulse
        }
    }
}
