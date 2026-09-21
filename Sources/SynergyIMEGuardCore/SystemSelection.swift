import Foundation

public protocol SystemSelectionReading: AnyObject {
    func currentID() -> String?
}

public protocol CommandRunning {
    func run(
        executable: String,
        arguments: [String],
        standardInput: Data?
    ) throws -> CommandResult
}

public struct CommandResult {
    public let status: Int32
    public let standardOutput: Data
    public let standardError: Data

    public init(status: Int32, standardOutput: Data, standardError: Data) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(
        executable: String,
        arguments: [String],
        standardInput: Data? = nil
    ) throws -> CommandResult {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        var input: Pipe?

        defer {
            try? output.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
            try? error.fileHandleForReading.close()
            try? error.fileHandleForWriting.close()
            try? input?.fileHandleForReading.close()
            try? input?.fileHandleForWriting.close()
        }

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error

        if standardInput != nil {
            input = Pipe()
            process.standardInput = input
        }

        try process.run()

        // Process duplicates the child-facing pipe ends during launch. Close
        // the parent's copies immediately so every invocation has a bounded
        // file-descriptor lifetime, including long-running health checks.
        try? output.fileHandleForWriting.close()
        try? error.fileHandleForWriting.close()
        try? input?.fileHandleForReading.close()

        let outputData = LockedData()
        let errorData = LockedData()
        let readers = DispatchGroup()
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            outputData.set(output.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            errorData.set(error.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }

        if let standardInput, let input {
            input.fileHandleForWriting.write(standardInput)
            try input.fileHandleForWriting.close()
        }

        process.waitUntilExit()
        readers.wait()
        return CommandResult(
            status: process.terminationStatus,
            standardOutput: outputData.get(),
            standardError: errorData.get()
        )
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Data()

    func set(_ data: Data) {
        lock.lock()
        value = data
        lock.unlock()
    }

    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

public final class SystemSelection: SystemSelectionReading {
    private let inputSource: InputSourceControlling
    private let commandRunner: CommandRunning

    public init(
        inputSource: InputSourceControlling,
        commandRunner: CommandRunning = ProcessCommandRunner()
    ) {
        self.inputSource = inputSource
        self.commandRunner = commandRunner
    }

    public func currentID() -> String? {
        do {
            let result = try commandRunner.run(
                executable: "/usr/bin/defaults",
                arguments: ["export", "com.apple.HIToolbox", "-"],
                standardInput: nil
            )
            guard result.status == 0 else {
                return inputSource.currentID()
            }

            let propertyList = try PropertyListSerialization.propertyList(
                from: result.standardOutput,
                options: [],
                format: nil
            )
            guard
                let root = propertyList as? [String: Any],
                let selected = root["AppleSelectedInputSources"] as? [[String: Any]],
                let first = selected.first
            else {
                return inputSource.currentID()
            }

            if let inputMode = first["Input Mode"] as? String {
                return inputMode
            }
            if first["KeyboardLayout Name"] as? String == "ABC" {
                return GuardConstants.abcInputSourceID
            }
            return inputSource.currentID()
        } catch {
            return inputSource.currentID()
        }
    }
}
