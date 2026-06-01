import CodexBreathingLightCore
import Foundation

struct ApprovalWatcherOptions {
    var watchRoots: [URL]
    var notifierPath: String
    var pollInterval: TimeInterval
    var once: Bool
    var startAtEnd: Bool
    var triggerCooldown: TimeInterval

    static func parse(_ arguments: [String]) throws -> ApprovalWatcherOptions {
        var watchRoots: [URL] = []
        var notifierPath = "/Users/xiaoming/.codex/bin/codex-breathing-light-wrapper"
        var pollInterval: TimeInterval = 1
        var once = false
        var startAtEnd = true
        var triggerCooldown: TimeInterval = 8
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--watch-root":
                let value = try value(after: argument, in: arguments, at: index)
                watchRoots.append(URL(fileURLWithPath: value).standardizedFileURL)
                index += 2
            case "--notifier":
                notifierPath = try value(after: argument, in: arguments, at: index)
                index += 2
            case "--poll-interval":
                let value = try value(after: argument, in: arguments, at: index)
                guard let parsed = TimeInterval(value), parsed > 0 else {
                    throw ParseError.invalidValue(argument, value)
                }
                pollInterval = parsed
                index += 2
            case "--cooldown":
                let value = try value(after: argument, in: arguments, at: index)
                guard let parsed = TimeInterval(value), parsed >= 0 else {
                    throw ParseError.invalidValue(argument, value)
                }
                triggerCooldown = parsed
                index += 2
            case "--once":
                once = true
                startAtEnd = false
                index += 1
            case "--start-at-beginning":
                startAtEnd = false
                index += 1
            default:
                throw ParseError.unknownArgument(argument)
            }
        }

        if watchRoots.isEmpty {
            watchRoots = Self.defaultWatchRoots()
        }

        return ApprovalWatcherOptions(
            watchRoots: watchRoots,
            notifierPath: notifierPath,
            pollInterval: pollInterval,
            once: once,
            startAtEnd: startAtEnd,
            triggerCooldown: triggerCooldown
        )
    }

    private static func defaultWatchRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".codex/sessions"),
            home.appendingPathComponent("Library/Logs/com.openai.codex"),
            home.appendingPathComponent("Library/Logs/Codex")
        ]
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
}

enum ParseError: Error, CustomStringConvertible {
    case missingValue(String)
    case invalidValue(String, String)
    case unknownArgument(String)

    var description: String {
        switch self {
        case .missingValue(let option): return "missing value after \(option)"
        case .invalidValue(let option, let value): return "invalid value for \(option): \(value)"
        case .unknownArgument(let argument): return "unknown argument: \(argument)"
        }
    }
}

final class ApprovalWatcher {
    private let options: ApprovalWatcherOptions
    private let fileManager = FileManager.default
    private var offsets: [String: UInt64] = [:]
    private var seenApprovalIDs: Set<String> = []
    private var lastTriggerDate: Date?
    private var isInitialScan = true

    init(options: ApprovalWatcherOptions) {
        self.options = options
    }

    func run() {
        repeat {
            scanOnce()
            if !options.once {
                Thread.sleep(forTimeInterval: options.pollInterval)
            }
        } while !options.once
    }

    private func scanOnce() {
        for file in watchedFiles() {
            scan(file: file)
        }
        isInitialScan = false
    }

    private func watchedFiles() -> [URL] {
        var files: [URL] = []
        for root in options.watchRoots where fileManager.fileExists(atPath: root.path) {
            if isRegularFile(root) {
                files.append(root)
                continue
            }

            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator where shouldWatch(fileURL) {
                files.append(fileURL)
            }
        }
        return files
    }

    private func scan(file: URL) {
        guard let fileSize = size(of: file) else {
            return
        }

        let key = file.path
        let start = ApprovalWatcherCore.readStartOffset(
            previousOffset: offsets[key],
            fileSize: fileSize,
            startAtEnd: options.startAtEnd,
            initialScan: isInitialScan
        )
        offsets[key] = fileSize

        guard fileSize > start,
              let text = read(file: file, from: start, length: fileSize - start) else {
            return
        }

        for approvalID in ApprovalWatcherCore.approvalIDs(in: text) {
            trigger(approvalID: approvalID, file: file)
        }
    }

    private func trigger(approvalID: String, file: URL) {
        guard !seenApprovalIDs.contains(approvalID) else {
            return
        }
        seenApprovalIDs.insert(approvalID)

        if let lastTriggerDate,
           Date().timeIntervalSince(lastTriggerDate) < options.triggerCooldown {
            log("suppressed nearby approval \(approvalID) from \(file.path)")
            return
        }

        lastTriggerDate = Date()
        log("detected approval \(approvalID) in \(file.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: options.notifierPath)
        process.arguments = [
            "--duration", "10",
            "--animation", "breathe",
            #"{"codexUserInputRequestedDuringTurn":true}"#
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            log("failed to launch notifier: \(error)")
        }
    }

    private func shouldWatch(_ fileURL: URL) -> Bool {
        guard isRegularFile(fileURL) else {
            return false
        }
        let name = fileURL.lastPathComponent.lowercased()
        return name.hasSuffix(".log") || name.hasSuffix(".jsonl")
    }

    private func isRegularFile(_ fileURL: URL) -> Bool {
        guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]) else {
            return false
        }
        return values.isRegularFile == true
    }

    private func size(of fileURL: URL) -> UInt64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return nil
        }
        return fileSize.uint64Value
    }

    private func read(file fileURL: URL, from offset: UInt64, length: UInt64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: offset)
            let data = try handle.read(upToCount: Int(min(length, 1_048_576))) ?? Data()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func log(_ message: String) {
        let line = "[\(Date())] codex-approval-watcher: \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}

do {
    let options = try ApprovalWatcherOptions.parse(Array(CommandLine.arguments.dropFirst()))
    ApprovalWatcher(options: options).run()
} catch {
    fputs("codex-approval-watcher: \(error)\n", stderr)
    exit(2)
}
