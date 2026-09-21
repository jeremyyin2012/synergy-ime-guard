import Foundation
import XCTest
@testable import SynergyIMEGuardCore

final class CommandRunnerTests: XCTestCase {
    func testRunnerDrainsOutputLargerThanPipeBuffer() throws {
        let result = try ProcessCommandRunner().run(
            executable: "/usr/bin/awk",
            arguments: [#"BEGIN { for (i=0; i<20000; i++) print "xxxxxxxxxx" }"#],
            standardInput: nil
        )
        XCTAssertEqual(result.status, 0)
        XCTAssertGreaterThan(result.standardOutput.count, 200_000)
    }

    func testRunnerClosesFileDescriptorsAcrossRepeatedRuns() throws {
        let runner = ProcessCommandRunner()
        let before = try openFileDescriptorCount()

        for _ in 0..<64 {
            let result = try runner.run(
                executable: "/usr/bin/true",
                arguments: [],
                standardInput: nil
            )
            XCTAssertEqual(result.status, 0)
        }

        let after = try openFileDescriptorCount()
        XCTAssertLessThanOrEqual(after, before + 4)
    }

    func testRunnerClosesStandardInputPipe() throws {
        let payload = Data("pipe lifecycle\n".utf8)
        let result = try ProcessCommandRunner().run(
            executable: "/bin/cat",
            arguments: [],
            standardInput: payload
        )

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.standardOutput, payload)
    }

    private func openFileDescriptorCount() throws -> Int {
        try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
    }
}
