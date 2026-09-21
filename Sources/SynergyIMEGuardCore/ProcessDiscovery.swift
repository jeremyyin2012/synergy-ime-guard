import Foundation

public struct CoreProcess: Codable, Equatable {
    public let role: String
    public let screenName: String?
    public let syncLanguage: Bool

    public init(role: String, screenName: String?, syncLanguage: Bool) {
        self.role = role
        self.screenName = screenName
        self.syncLanguage = syncLanguage
    }
}

public struct CoreProcessSnapshot: Equatable {
    public let cores: [CoreProcess]
    public let isAvailable: Bool

    public init(cores: [CoreProcess], isAvailable: Bool) {
        self.cores = cores
        self.isAvailable = isAvailable
    }
}

public protocol ProcessDiscovering: AnyObject {
    func processSnapshot() -> CoreProcessSnapshot
    func cores() -> [CoreProcess]
    func current() -> CoreProcess?
    func serverRunning(screenName: String) -> Bool
    func syncLanguageEnabled() -> Bool
}

public final class ProcessDiscovery: ProcessDiscovering {
    private static let coreExpression = try! NSRegularExpression(
        pattern: #"^(?:\S*/)?synergy-core\s+(server|client)(?:\s|$)"#
    )
    private let snapshot: () -> String?

    public init(
        snapshot: (() -> String)? = nil,
        commandRunner: CommandRunning = ProcessCommandRunner(),
        emit: @escaping (String) -> Void = { _ in }
    ) {
        if let snapshot {
            self.snapshot = { snapshot() }
        } else {
            self.snapshot = {
                ProcessDiscovery.readProcessSnapshot(
                    commandRunner: commandRunner,
                    emit: emit
                )
            }
        }
    }

    public func processSnapshot() -> CoreProcessSnapshot {
        guard let contents = snapshot() else {
            return CoreProcessSnapshot(cores: [], isAvailable: false)
        }
        let cores = contents.split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { Self.parse(String($0)) }
        return CoreProcessSnapshot(cores: cores, isAvailable: true)
    }

    public func cores() -> [CoreProcess] {
        processSnapshot().cores
    }

    public func current() -> CoreProcess? {
        let found = cores()
        return found.count == 1 ? found[0] : nil
    }

    public func serverRunning(screenName: String) -> Bool {
        cores().contains {
            $0.role == "server" && $0.screenName == screenName
        }
    }

    public func syncLanguageEnabled() -> Bool {
        cores().contains { $0.syncLanguage }
    }

    static func parse(_ command: String) -> CoreProcess? {
        let commandRange = NSRange(command.startIndex..., in: command)
        guard
            let match = coreExpression.firstMatch(
                in: command,
                range: commandRange
            ),
            let roleRange = Range(match.range(at: 1), in: command)
        else {
            return nil
        }
        let role = String(command[roleRange])

        return CoreProcess(
            role: role,
            screenName: optionValue("--name", in: command),
            syncLanguage: booleanOption("--sync-language", in: command)
        )
    }

    private static func booleanOption(_ option: String, in command: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: option)
        let pattern = "(?:^|\\s)\(escaped)(?:=(true|false|1|0)|\\s+(true|false|1|0))?(?=\\s|$)"
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return false
        }
        let range = NSRange(command.startIndex..., in: command)
        guard let match = expression.firstMatch(in: command, range: range) else {
            return false
        }
        for index in 1..<match.numberOfRanges {
            let matchRange = match.range(at: index)
            if matchRange.location != NSNotFound,
               let swiftRange = Range(matchRange, in: command) {
                let value = command[swiftRange].lowercased()
                return value == "true" || value == "1"
            }
        }
        return true
    }

    private static func optionValue(_ option: String, in command: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: option)
        let pattern = "(?:^|\\s)\(escaped)(?:=|\\s+)(?:\\\"([^\\\"]+)\\\"|'([^']+)'|(\\S+))"
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(command.startIndex..., in: command)
        guard let match = expression.firstMatch(in: command, range: range) else {
            return nil
        }
        for index in 1..<match.numberOfRanges {
            let matchRange = match.range(at: index)
            if matchRange.location != NSNotFound,
               let swiftRange = Range(matchRange, in: command) {
                return String(command[swiftRange])
            }
        }
        return nil
    }

    private static func readProcessSnapshot(
        commandRunner: CommandRunning,
        emit: (String) -> Void
    ) -> String? {
        do {
            let result = try commandRunner.run(
                executable: "/bin/ps",
                arguments: ["-Ao", "command="],
                standardInput: nil
            )
            guard result.status == 0 else {
                emit("process_snapshot_failed status=\(result.status)")
                return nil
            }
            return String(data: result.standardOutput, encoding: .utf8) ?? ""
        } catch {
            emit(
                "process_snapshot_failed error="
                    + "\(type(of: error)):\(error.localizedDescription)"
            )
            return nil
        }
    }
}
