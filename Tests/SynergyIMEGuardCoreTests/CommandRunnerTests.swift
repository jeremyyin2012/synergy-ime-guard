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
}
