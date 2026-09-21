import Foundation
@testable import SynergyIMEGuardCore

final class MockInputSource: InputSourceControlling {
    var current: String?
    var available = Set([GuardConstants.abcInputSourceID])
    var results: [Int32?] = []
    var selections: [String] = []

    func currentID() -> String? { current }
    func isAvailable(_ inputSourceID: String) -> Bool {
        available.contains(inputSourceID)
    }
    func select(_ inputSourceID: String) -> Int32? {
        selections.append(inputSourceID)
        let result = results.isEmpty ? 0 : results.removeFirst()
        if result == 0 { current = inputSourceID }
        return result
    }
}

final class MockSelection: SystemSelectionReading {
    var current: String?
    init(_ current: String?) { self.current = current }
    func currentID() -> String? { current }
}

final class MemoryStateStore: RestoreStateStoring {
    var obligation: RestoreObligation?
    var saveError: Error?
    var clearError: Error?

    func load() throws -> RestoreObligation? { obligation }
    func saveIfAbsent(_ value: RestoreObligation) throws -> RestoreObligation {
        if let saveError { throw saveError }
        if let obligation { return obligation }
        obligation = value
        return value
    }
    func clear() throws {
        if let clearError { throw clearError }
        obligation = nil
    }
}

final class MockProcessDiscovery: ProcessDiscovering {
    var processes: [CoreProcess] = []
    var serverIsRunning = false
    var syncEnabled = false
    var snapshotAvailable = true
    var coreSnapshotCount = 0

    func processSnapshot() -> CoreProcessSnapshot {
        coreSnapshotCount += 1
        guard snapshotAvailable else {
            return CoreProcessSnapshot(cores: [], isAvailable: false)
        }
        let cores: [CoreProcess]
        if !processes.isEmpty {
            cores = processes
        } else if serverIsRunning {
            cores = [
                CoreProcess(
                    role: "server",
                    screenName: "mini",
                    syncLanguage: syncEnabled
                )
            ]
        } else {
            cores = []
        }
        return CoreProcessSnapshot(cores: cores, isAvailable: true)
    }
    func cores() -> [CoreProcess] { processSnapshot().cores }
    func current() -> CoreProcess? {
        processes.count == 1 ? processes[0] : nil
    }
    func serverRunning(screenName: String) -> Bool { serverIsRunning }
    func syncLanguageEnabled() -> Bool { syncEnabled }
}

enum TestError: Error {
    case expected
}

struct ThrowingCommandRunner: CommandRunning {
    func run(
        executable: String,
        arguments: [String],
        standardInput: Data?
    ) throws -> CommandResult {
        throw TestError.expected
    }
}
