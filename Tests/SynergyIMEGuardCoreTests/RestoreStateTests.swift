import Foundation
import XCTest
@testable import SynergyIMEGuardCore

final class RestoreStateTests: XCTestCase {
    func testFileStorePreservesFirstObligationAndClears() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("state.json")
        let store = FileRestoreStateStore(url: url)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try store.saveIfAbsent(
            RestoreObligation(inputSourceID: "original")
        )
        let duplicate = try store.saveIfAbsent(
            RestoreObligation(inputSourceID: "replacement")
        )
        XCTAssertEqual(first.inputSourceID, "original")
        XCTAssertEqual(duplicate.inputSourceID, "original")
        XCTAssertEqual(try store.load()?.inputSourceID, "original")

        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testFileStoreRejectsUnsupportedSchema() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("state.json")
        try #"{"inputSourceID":"pinyin","schemaVersion":99}"#
            .write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try FileRestoreStateStore(url: url).load())
    }
}
