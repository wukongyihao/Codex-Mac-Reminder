import Foundation

public struct ReminderState: Codable, Equatable {
    public var isEnabled: Bool
    public var attentionColorHex: String?

    public init(isEnabled: Bool = true, attentionColorHex: String? = nil) {
        self.isEnabled = isEnabled
        self.attentionColorHex = ReminderColor.normalized(attentionColorHex)
    }

    public var effectiveAttentionColorHex: String {
        ReminderColor.normalized(attentionColorHex) ?? ReminderColor.defaultAttentionColorHex
    }
}

public enum ReminderColor {
    public static let defaultAttentionColorHex = "#FF3B30"

    private static let namedColors: Set<String> = [
        "red",
        "green",
        "blue",
        "orange",
        "yellow",
        "cyan",
        "purple",
        "pink"
    ]

    public static func normalized(_ rawValue: String?) -> String? {
        guard let rawValue else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let lowercased = trimmed.lowercased()
        if namedColors.contains(lowercased) {
            return lowercased
        }

        let hex = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              hex.allSatisfy(\.isHexDigit) else {
            return nil
        }
        return "#\(hex.uppercased())"
    }
}

public struct ReminderStateStore {
    public let path: String

    public init(path: String = ReminderStateStore.defaultPath) {
        self.path = path
    }

    public static var defaultPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/codex-reminder-state.json")
            .path
    }

    public func read() -> ReminderState {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let state = try? JSONDecoder().decode(ReminderState.self, from: data) else {
            return ReminderState()
        }
        return state
    }

    public func write(_ state: ReminderState) throws {
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
    }
}

public enum ReminderGate {
    public static func shouldShowAlert(isEnabled: Bool, force: Bool) -> Bool {
        isEnabled || force
    }
}

public enum ReminderControlCommand: String, Equatable {
    case enable
    case disable
    case toggle
    case status

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case unknownCommand(String)

        public var description: String {
            switch self {
            case .unknownCommand(let command): return "unknown command: \(command)"
            }
        }
    }

    public static func parse(_ arguments: [String]) throws -> ReminderControlCommand {
        guard let command = arguments.first else {
            return .status
        }
        guard let parsed = ReminderControlCommand(rawValue: command.lowercased()) else {
            throw ParseError.unknownCommand(command)
        }
        return parsed
    }

    @discardableResult
    public func apply(to store: ReminderStateStore) throws -> ReminderState {
        switch self {
        case .enable:
            var state = store.read()
            state.isEnabled = true
            try store.write(state)
            return state
        case .disable:
            var state = store.read()
            state.isEnabled = false
            try store.write(state)
            return state
        case .toggle:
            var state = store.read()
            state.isEnabled.toggle()
            try store.write(state)
            return state
        case .status:
            return store.read()
        }
    }
}
