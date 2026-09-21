import Foundation

public final class GuardRuntime {
    private let logURL: URL
    private let screenName: String
    private let processDiscovery: ProcessDiscovering
    private let stateMachine: GuardStateMachine
    private let parser: TransitionParser
    private let inspector: TransitionLogInspector
    private let pollInterval: TimeInterval
    private let healthInterval: TimeInterval
    private let emit: (String) -> Void
    private let sleep: (TimeInterval) -> Void
    private let stopLock = NSLock()
    private var stopRequested = false
    private var reconciliationPending = false

    public init(
        logURL: URL,
        screenName: String,
        processDiscovery: ProcessDiscovering,
        stateMachine: GuardStateMachine,
        parser: TransitionParser = TransitionParser(),
        inspector: TransitionLogInspector = TransitionLogInspector(),
        pollInterval: TimeInterval = GuardConstants.defaultPollInterval,
        healthInterval: TimeInterval = GuardConstants.defaultHealthInterval,
        emit: @escaping (String) -> Void = { _ in },
        sleep: @escaping (TimeInterval) -> Void = Thread.sleep
    ) {
        self.logURL = logURL
        self.screenName = screenName
        self.processDiscovery = processDiscovery
        self.stateMachine = stateMachine
        self.parser = parser
        self.inspector = inspector
        self.pollInterval = pollInterval
        self.healthInterval = healthInterval
        self.emit = emit
        self.sleep = sleep
    }

    public func requestShutdown() {
        stopLock.lock()
        stopRequested = true
        stopLock.unlock()
    }

    public func reconcileStartup() {
        let location = inspector.lastLocation(
            logURL: logURL,
            localScreenName: screenName
        )
        guard let processState = currentProcessState() else {
            reconciliationPending = true
            emit("startup action=defer reason=process_snapshot_failed")
            return
        }
        reconciliationPending = false
        if processState.serverRunning,
           !processState.syncLanguageEnabled,
           location == .remote {
            emit("startup state=remote")
            stateMachine.leaveLocal()
        } else {
            emit("startup state=local_or_client")
            stateMachine.enterLocal()
        }
    }

    public func process(line: String) {
        switch parser.parse(line: line, localScreenName: screenName) {
        case .leftLocal:
            guard let processState = currentProcessState() else {
                reconciliationPending = true
                emit("leave action=skip reason=process_snapshot_failed")
                return
            }
            reconciliationPending = false
            guard processState.serverRunning else {
                emit("leave action=skip reason=not_server")
                return
            }
            guard !processState.syncLanguageEnabled else {
                emit("leave action=skip reason=sync_language")
                return
            }
            stateMachine.leaveLocal()
        case .enteredLocal, .serverStarted, .serverStopped:
            stateMachine.enterLocal()
        default:
            break
        }
    }

    public func healthCheck() {
        guard stateMachine.savedInputSourceID() != nil else { return }
        guard let processState = currentProcessState() else {
            reconciliationPending = true
            emit("health action=defer reason=process_snapshot_failed")
            return
        }
        reconciliationPending = false
        if !processState.serverRunning {
            emit("health restore reason=server_missing")
            stateMachine.enterLocal()
        } else if processState.syncLanguageEnabled {
            emit("health restore reason=sync_language")
            stateMachine.enterLocal()
        }
    }

    private func currentProcessState() -> (
        serverRunning: Bool,
        syncLanguageEnabled: Bool
    )? {
        let snapshot = processDiscovery.processSnapshot()
        guard snapshot.isAvailable else { return nil }
        let cores = snapshot.cores
        return (
            serverRunning: cores.contains {
                $0.role == "server" && $0.screenName == screenName
            },
            syncLanguageEnabled: cores.contains { $0.syncLanguage }
        )
    }

    public func run() {
        reconcileStartup()
        var identity: FileIdentity?
        var offset: UInt64 = 0
        var remainder = ""
        var nextHealth = ProcessInfo.processInfo.systemUptime + healthInterval

        defer { stateMachine.enterLocal() }
        while !shouldStop {
            guard let currentIdentity = fileIdentity(logURL) else {
                healthCheckIfDue(nextHealth: &nextHealth)
                sleep(pollInterval)
                continue
            }

            if identity?.fileNumber != currentIdentity.fileNumber
                || currentIdentity.size < offset {
                reconcileStartup()
                identity = currentIdentity
                offset = currentIdentity.size
                remainder = ""
                emit("watching log=\(logURL.path)")
            } else if currentIdentity.size > offset {
                if let chunk = read(logURL: logURL, from: offset) {
                    offset += UInt64(chunk.utf8.count)
                    remainder.append(chunk)
                    let parts = remainder.split(
                        separator: "\n",
                        omittingEmptySubsequences: false
                    )
                    for line in parts.dropLast() {
                        process(line: String(line))
                    }
                    remainder = String(parts.last ?? "")
                }
            }

            healthCheckIfDue(nextHealth: &nextHealth)
            sleep(pollInterval)
        }
    }

    private var shouldStop: Bool {
        stopLock.lock()
        defer { stopLock.unlock() }
        return stopRequested
    }

    private func healthCheckIfDue(nextHealth: inout TimeInterval) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= nextHealth else { return }
        if reconciliationPending {
            reconcileStartup()
        } else {
            healthCheck()
        }
        nextHealth = now + healthInterval
    }

    private func read(logURL: URL, from offset: UInt64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: logURL) else {
            return nil
        }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            guard let data = try handle.readToEnd() else { return "" }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private struct FileIdentity: Equatable {
        let fileNumber: UInt64
        let size: UInt64
    }

    private func fileIdentity(_ url: URL) -> FileIdentity? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let fileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
            let size = (attributes[.size] as? NSNumber)?.uint64Value
        else {
            return nil
        }
        return FileIdentity(fileNumber: fileNumber, size: size)
    }
}
