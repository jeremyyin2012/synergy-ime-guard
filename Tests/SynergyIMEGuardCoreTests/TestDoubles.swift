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

    func cores() -> [CoreProcess] { processes }
    func current() -> CoreProcess? {
        processes.count == 1 ? processes[0] : nil
    }
    func serverRunning(screenName: String) -> Bool { serverIsRunning }
    func syncLanguageEnabled() -> Bool { syncEnabled }
}

enum TestError: Error {
    case expected
}
