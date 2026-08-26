import Darwin
import Foundation
import SynergyIMEGuardCore

private struct CLIError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct Options {
    var command = "run"
    var logPath: String?
    var screenName: String?
    var statePath: String?
    var onceEvent: String?
}

private func usage() -> String {
    """
    Synergy IME Guard \(GuardConstants.version)

    Usage:
      synergy-ime-guard run --log PATH --screen NAME --state PATH
      synergy-ime-guard check --log PATH --screen NAME --state PATH
      synergy-ime-guard once <leave|enter> --log PATH --screen NAME --state PATH
      synergy-ime-guard discover
      synergy-ime-guard version
    """
}

private func parseOptions(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 0
    if let first = arguments.first {
        if ["--version", "--help", "-h"].contains(first) {
            options.command = first
            index = 1
        } else if !first.hasPrefix("--") {
            options.command = first
            index = 1
        }
    }
    if options.command == "once" {
        guard arguments.indices.contains(index) else {
            throw CLIError(message: "once requires leave or enter")
        }
        options.onceEvent = arguments[index]
        index += 1
    }

    while index < arguments.count {
        let argument = arguments[index]
        guard ["--log", "--screen", "--state"].contains(argument),
              arguments.indices.contains(index + 1) else {
            throw CLIError(message: "unknown or incomplete option: \(argument)")
        }
        let value = arguments[index + 1]
        switch argument {
        case "--log": options.logPath = value
        case "--screen": options.screenName = value
        case "--state": options.statePath = value
        default: break
        }
        index += 2
    }
    return options
}

private func makeRuntime(_ options: Options) throws -> (
    GuardRuntime,
    GuardStateMachine,
    MacOSInputSourceController,
    ProcessDiscovery
) {
    guard let logPath = options.logPath,
          let screenName = options.screenName,
          let statePath = options.statePath else {
        throw CLIError(message: "run/check/once require --log, --screen, and --state")
    }
    let emit: (String) -> Void = { message in
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        print("\(formatter.string(from: Date())) \(message)")
        fflush(stdout)
    }
    let inputSource = MacOSInputSourceController()
    let stateStore = FileRestoreStateStore(url: URL(fileURLWithPath: statePath))
    let machine = GuardStateMachine(
        selection: SystemSelection(inputSource: inputSource),
        inputSource: inputSource,
        stateStore: stateStore,
        emit: emit
    )
    let discovery = ProcessDiscovery()
    let runtime = GuardRuntime(
        logURL: URL(fileURLWithPath: logPath),
        screenName: screenName,
        processDiscovery: discovery,
        stateMachine: machine,
        emit: emit
    )
    return (runtime, machine, inputSource, discovery)
}

private func encode<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
}

private func main() throws {
    let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
    switch options.command {
    case "version", "--version":
        print(GuardConstants.version)
    case "discover":
        let discovery = ProcessDiscovery()
        guard let core = discovery.current() else {
            throw CLIError(message: "expected exactly one running synergy-core process")
        }
        try encode(core)
    case "run":
        let (runtime, _, inputSource, discovery) = try makeRuntime(options)
        guard inputSource.isAvailable(GuardConstants.abcInputSourceID) else {
            throw CLIError(message: "ABC input source is not available")
        }
        guard !discovery.syncLanguageEnabled() else {
            throw CLIError(message: "Synergy language sync is enabled; disable it before running the guard")
        }
        signal(SIGPIPE, SIG_IGN)
        let signalQueue = DispatchQueue(label: "synergy-ime-guard.signals")
        let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue)
        let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)
        term.setEventHandler { runtime.requestShutdown() }
        interrupt.setEventHandler { runtime.requestShutdown() }
        term.resume()
        interrupt.resume()
        runtime.run()
    case "check":
        let (runtime, machine, inputSource, discovery) = try makeRuntime(options)
        let core = discovery.current()
        let screen = options.screenName!
        let report = DiagnosticReport(
            version: GuardConstants.version,
            role: core?.role,
            screenName: core?.screenName,
            syncLanguage: discovery.syncLanguageEnabled(),
            currentInputSourceID: SystemSelection(inputSource: inputSource).currentID(),
            abcAvailable: inputSource.isAvailable(GuardConstants.abcInputSourceID),
            savedInputSourceID: machine.savedInputSourceID(),
            lastLocation: TransitionLogInspector().lastLocation(
                logURL: URL(fileURLWithPath: options.logPath!),
                localScreenName: screen
            ).rawValue
        )
        _ = runtime
        try encode(report)
    case "once":
        let (_, machine, _, _) = try makeRuntime(options)
        switch options.onceEvent {
        case "leave": _ = machine.leaveLocal()
        case "enter": _ = machine.enterLocal()
        default: throw CLIError(message: "once requires leave or enter")
        }
    case "help", "--help", "-h":
        print(usage())
    default:
        throw CLIError(message: "unknown command: \(options.command)\n\n\(usage())")
    }
}

do {
    try main()
} catch {
    fputs("synergy-ime-guard: \(error.localizedDescription)\n", stderr)
    exit(1)
}
