import Darwin
import Foundation

public struct RestoreObligation: Codable, Equatable {
    public let schemaVersion: Int
    public let inputSourceID: String

    public init(inputSourceID: String) {
        self.schemaVersion = 1
        self.inputSourceID = inputSourceID
    }
}

public protocol RestoreStateStoring: AnyObject {
    func load() throws -> RestoreObligation?
    @discardableResult
    func saveIfAbsent(_ obligation: RestoreObligation) throws -> RestoreObligation
    func clear() throws
}

public enum RestoreStateError: Error, LocalizedError {
    case unsupportedSchema(Int)
    case invalidInputSourceID

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "unsupported state schema version: \(version)"
        case .invalidInputSourceID:
            return "state contains an empty input source ID"
        }
    }
}

public final class FileRestoreStateStore: RestoreStateStoring {
    public let url: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> RestoreObligation? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let obligation = try decoder.decode(
            RestoreObligation.self,
            from: Data(contentsOf: url)
        )
        guard obligation.schemaVersion == 1 else {
            throw RestoreStateError.unsupportedSchema(obligation.schemaVersion)
        }
        guard !obligation.inputSourceID.isEmpty else {
            throw RestoreStateError.invalidInputSourceID
        }
        return obligation
    }

    @discardableResult
    public func saveIfAbsent(
        _ obligation: RestoreObligation
    ) throws -> RestoreObligation {
        if let existing = try load() {
            return existing
        }

        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let temporaryURL = directory.appendingPathComponent(
            ".\(url.lastPathComponent).tmp.\(ProcessInfo.processInfo.processIdentifier).\(UUID().uuidString)"
        )
        let data = try encoder.encode(obligation) + Data([0x0A])
        guard fileManager.createFile(
            atPath: temporaryURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        do {
            let handle = try FileHandle(forWritingTo: temporaryURL)
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            try fileManager.moveItem(at: temporaryURL, to: url)
            synchronizeDirectory(directory)
            return obligation
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
        synchronizeDirectory(url.deletingLastPathComponent())
    }

    private func synchronizeDirectory(_ directory: URL) {
        let descriptor = open(directory.path, O_RDONLY | O_DIRECTORY)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }
        _ = fsync(descriptor)
    }
}
