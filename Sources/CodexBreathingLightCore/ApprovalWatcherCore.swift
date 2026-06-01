import Foundation

public enum ApprovalWatcherCore {
    public static func approvalIDs(in text: String) -> [String] {
        var ids: [String] = []
        for line in text.split(whereSeparator: \.isNewline) {
            if let id = approvalID(inLine: String(line)) {
                ids.append(id)
            }
        }
        if ids.isEmpty, let id = approvalID(inLine: text) {
            ids.append(id)
        }
        return ids
    }

    public static func approvalID(inLine line: String) -> String? {
        let lowercased = line.lowercased()
        if let sessionApprovalID = sessionApprovalID(inLine: line, lowercased: lowercased) {
            return sessionApprovalID
        }

        guard lowercased.contains("[desktop-notifications]") else {
            return nil
        }
        guard lowercased.contains("show approval")
            || lowercased.contains("kind=permission")
            || lowercased.contains("notificationid=approval-local") else {
            return nil
        }
        guard !lowercased.contains("turn-complete") else {
            return nil
        }

        if let requestID = fieldValue(named: "requestId", in: line) {
            return "approval-local-\(requestID)"
        }
        if let notificationID = fieldValue(named: "notificationId", in: line),
           notificationID.lowercased().hasPrefix("approval-local") {
            return notificationID.lowercased()
        }
        return "approval-\(line)"
    }

    private static func sessionApprovalID(inLine line: String, lowercased: String) -> String? {
        guard lowercased.contains(#""sandbox_permissions":"require_escalated""#)
            || lowercased.contains(#""sandbox_permissions\":\"require_escalated\""#)
            || lowercased.contains(#""sandbox_permissions": "require_escalated""#) else {
            return nil
        }
        guard lowercased.contains(#""name":"exec_command""#)
            || lowercased.contains(#""name\":\"exec_command\""#)
            || lowercased.contains("exec_command") else {
            return nil
        }
        guard lowercased.contains(#""justification""#)
            || lowercased.contains(#"\"justification\""#) else {
            return nil
        }
        if let callID = jsonStringValue(named: "call_id", in: line) {
            return "session-approval-\(callID)"
        }
        return "session-approval-\(stableHash(line))"
    }

    public static func readStartOffset(
        previousOffset: UInt64?,
        fileSize: UInt64,
        startAtEnd: Bool,
        initialScan: Bool
    ) -> UInt64 {
        guard let previousOffset else {
            return startAtEnd && initialScan ? fileSize : 0
        }
        return previousOffset <= fileSize ? previousOffset : 0
    }

    private static func fieldValue(named fieldName: String, in line: String) -> String? {
        let pattern = "\(NSRegularExpression.escapedPattern(for: fieldName))=([^\\s]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let rawValue = String(line[valueRange])
        return rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func jsonStringValue(named fieldName: String, in line: String) -> String? {
        let pattern = #""# + NSRegularExpression.escapedPattern(for: fieldName) + #"":"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[valueRange])
    }

    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
