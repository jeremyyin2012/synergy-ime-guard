import Foundation

public enum ScreenLocation: String, Equatable {
    case local
    case remote
    case unknown
}

public enum Transition: Equatable {
    case leftLocal(from: String, to: String)
    case enteredLocal(from: String, to: String)
    case remoteToRemote(from: String, to: String)
    case unrelated(from: String, to: String)
    case serverStarted
    case serverStopped
}

public struct TransitionParser {
    private static let expression = try! NSRegularExpression(
        pattern: #"switch from \"([^\"]+)\" to \"([^\"]+)\""#
    )

    public init() {}

    public func parse(line: String, localScreenName: String) -> Transition? {
        if line.contains("started server") {
            return .serverStarted
        }
        if line.contains("stopped server") {
            return .serverStopped
        }

        let range = NSRange(line.startIndex..., in: line)
        guard
            let match = Self.expression.firstMatch(in: line, range: range),
            let fromRange = Range(match.range(at: 1), in: line),
            let toRange = Range(match.range(at: 2), in: line)
        else {
            return nil
        }

        let from = String(line[fromRange])
        let to = String(line[toRange])
        if from == localScreenName && to != localScreenName {
            return .leftLocal(from: from, to: to)
        }
        if to == localScreenName && from != localScreenName {
            return .enteredLocal(from: from, to: to)
        }
        if from != localScreenName && to != localScreenName {
            return .remoteToRemote(from: from, to: to)
        }
        return .unrelated(from: from, to: to)
    }
}

public struct TransitionLogInspector {
    private let parser: TransitionParser
    private let tailBytes: UInt64

    public init(parser: TransitionParser = TransitionParser(), tailBytes: UInt64 = 1_048_576) {
        self.parser = parser
        self.tailBytes = tailBytes
    }

    public func lastLocation(logURL: URL, localScreenName: String) -> ScreenLocation {
        guard let handle = try? FileHandle(forReadingFrom: logURL) else {
            return .unknown
        }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > tailBytes ? size - tailBytes : 0
        try? handle.seek(toOffset: start)
        let data = (try? handle.readToEnd()) ?? nil
        guard var text = data.flatMap({ String(data: $0, encoding: .utf8) }) else {
            return .unknown
        }
        if start > 0, let newline = text.firstIndex(of: "\n") {
            text.removeSubrange(...newline)
        }

        var latest = ScreenLocation.unknown
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            switch parser.parse(line: String(line), localScreenName: localScreenName) {
            case .leftLocal:
                latest = .remote
            case .enteredLocal:
                latest = .local
            case .serverStarted, .serverStopped:
                latest = .local
            default:
                break
            }
        }
        return latest
    }
}
