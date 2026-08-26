import Foundation
import XCTest
@testable import SynergyIMEGuardCore

final class ParsingAndRuntimeTests: XCTestCase {
    func testProcessDiscoveryParsesServerAndQuotedScreenName() {
        let process = ProcessDiscovery.parse(
            #"/Applications/Synergy.app/Contents/MacOS/synergy-core server --name "Office Mac" --sync-language"#
        )
        XCTAssertEqual(
            process,
            CoreProcess(role: "server", screenName: "Office Mac", syncLanguage: true)
        )
    }

    func testProcessDiscoveryParsesClientAndEqualsOption() {
        let process = ProcessDiscovery.parse(
            "/opt/synergy-core client --name=air --sync-language=true"
        )
        XCTAssertEqual(
            process,
            CoreProcess(role: "client", screenName: "air", syncLanguage: true)
        )
    }

    func testProcessDiscoveryHonorsExplicitFalseLanguageSync() {
        XCTAssertEqual(
            ProcessDiscovery.parse(
                "/opt/synergy-core server --name mini --sync-language=false"
            )?.syncLanguage,
            false
        )
        XCTAssertEqual(
            ProcessDiscovery.parse(
                "/opt/synergy-core server --name mini --sync-language false"
            )?.syncLanguage,
            false
        )
    }

    func testProcessDiscoveryRejectsUnrelatedCommand() {
        XCTAssertNil(ProcessDiscovery.parse("rg synergy-core server --name fake"))
    }

    func testTransitionParserClassifiesLocalBoundaryOnly() {
        let parser = TransitionParser()
        XCTAssertEqual(
            parser.parse(
                line: #"INFO switch from "mini" to "air""#,
                localScreenName: "mini"
            ),
            .leftLocal(from: "mini", to: "air")
        )
        XCTAssertEqual(
            parser.parse(
                line: #"INFO switch from "air" to "linux""#,
                localScreenName: "mini"
            ),
            .remoteToRemote(from: "air", to: "linux")
        )
        XCTAssertEqual(
            parser.parse(
                line: #"INFO switch from "linux" to "mini""#,
                localScreenName: "mini"
            ),
            .enteredLocal(from: "linux", to: "mini")
        )
    }

    func testTransitionInspectorUsesLastRelevantEvent() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try """
        switch from "mini" to "air"
        switch from "air" to "linux"
        switch from "linux" to "mini"
        """.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(
            TransitionLogInspector().lastLocation(
                logURL: url,
                localScreenName: "mini"
            ),
            .local
        )
    }

    func testServerRestartResetsLastLocationToLocal() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try """
        switch from "mini" to "air"
        stopped server
        started server
        """.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(
            TransitionLogInspector().lastLocation(
                logURL: url,
                localScreenName: "mini"
            ),
            .local
        )
    }

    func testRuntimeRoleGatePreventsClientLeaveAction() {
        let process = MockProcessDiscovery()
        process.serverIsRunning = false
        let store = MemoryStateStore()
        let input = MockInputSource()
        let machine = GuardStateMachine(
            selection: MockSelection("pinyin"),
            inputSource: input,
            stateStore: store
        )
        let runtime = GuardRuntime(
            logURL: URL(fileURLWithPath: "/nonexistent"),
            screenName: "mini",
            processDiscovery: process,
            stateMachine: machine
        )

        runtime.process(line: #"switch from "mini" to "air""#)
        XCTAssertNil(store.obligation)
        XCTAssertTrue(input.selections.isEmpty)
    }

    func testRuntimeStaysPassiveWhenLanguageSyncIsEnabled() {
        let process = MockProcessDiscovery()
        process.serverIsRunning = true
        process.syncEnabled = true
        let store = MemoryStateStore()
        let input = MockInputSource()
        let machine = GuardStateMachine(
            selection: MockSelection("pinyin"),
            inputSource: input,
            stateStore: store
        )
        let runtime = GuardRuntime(
            logURL: URL(fileURLWithPath: "/nonexistent"),
            screenName: "mini",
            processDiscovery: process,
            stateMachine: machine
        )

        runtime.process(line: #"switch from "mini" to "air""#)
        XCTAssertNil(store.obligation)
        XCTAssertTrue(input.selections.isEmpty)
    }

    func testHealthCheckRestoresIfLanguageSyncBecomesEnabled() {
        let process = MockProcessDiscovery()
        process.serverIsRunning = true
        process.syncEnabled = true
        let store = MemoryStateStore()
        store.obligation = RestoreObligation(inputSourceID: "pinyin")
        let input = MockInputSource()
        let machine = GuardStateMachine(
            selection: MockSelection(GuardConstants.abcInputSourceID),
            inputSource: input,
            stateStore: store
        )
        let runtime = GuardRuntime(
            logURL: URL(fileURLWithPath: "/nonexistent"),
            screenName: "mini",
            processDiscovery: process,
            stateMachine: machine
        )

        runtime.healthCheck()
        XCTAssertNil(store.obligation)
        XCTAssertEqual(input.selections, ["pinyin"])
    }

    func testHealthCheckRestoresWhenServerDisappears() {
        let process = MockProcessDiscovery()
        process.serverIsRunning = false
        let store = MemoryStateStore()
        store.obligation = RestoreObligation(inputSourceID: "pinyin")
        let input = MockInputSource()
        let machine = GuardStateMachine(
            selection: MockSelection(GuardConstants.abcInputSourceID),
            inputSource: input,
            stateStore: store
        )
        let runtime = GuardRuntime(
            logURL: URL(fileURLWithPath: "/nonexistent"),
            screenName: "mini",
            processDiscovery: process,
            stateMachine: machine
        )

        runtime.healthCheck()
        XCTAssertNil(store.obligation)
        XCTAssertEqual(input.selections, ["pinyin"])
    }
}
