import XCTest
@testable import SynergyIMEGuardCore

final class GuardStateMachineTests: XCTestCase {
    private let pinyin = "com.apple.inputmethod.SCIM.ITABC"

    func testLeaveSavesOriginalBeforeSelectingABC() {
        let selection = MockSelection(pinyin)
        let input = MockInputSource()
        let store = MemoryStateStore()
        let machine = GuardStateMachine(
            selection: selection,
            inputSource: input,
            stateStore: store
        )

        XCTAssertEqual(machine.leaveLocal(), .savedAndSelectedABC(pinyin))
        XCTAssertEqual(store.obligation?.inputSourceID, pinyin)
        XCTAssertEqual(input.selections, [GuardConstants.abcInputSourceID])
    }

    func testDuplicateLeaveNeverOverwritesRestoreObligation() {
        let selection = MockSelection(pinyin)
        let input = MockInputSource()
        let store = MemoryStateStore()
        let machine = GuardStateMachine(
            selection: selection,
            inputSource: input,
            stateStore: store
        )

        _ = machine.leaveLocal()
        selection.current = "third.party.layout"
        XCTAssertEqual(
            machine.leaveLocal(),
            .selectedABCWithExistingState(pinyin)
        )
        XCTAssertEqual(store.obligation?.inputSourceID, pinyin)
    }

    func testSuccessfulEnterRestoresAndClears() {
        let input = MockInputSource()
        let store = MemoryStateStore()
        store.obligation = RestoreObligation(inputSourceID: pinyin)
        let machine = GuardStateMachine(
            selection: MockSelection(GuardConstants.abcInputSourceID),
            inputSource: input,
            stateStore: store
        )

        XCTAssertEqual(machine.enterLocal(), .restored(pinyin))
        XCTAssertNil(store.obligation)
        XCTAssertEqual(input.selections, [pinyin])
    }

    func testFailedRestorePreservesObligationForRetry() {
        let input = MockInputSource()
        input.results = [1, 0]
        let store = MemoryStateStore()
        store.obligation = RestoreObligation(inputSourceID: pinyin)
        let machine = GuardStateMachine(
            selection: MockSelection(GuardConstants.abcInputSourceID),
            inputSource: input,
            stateStore: store
        )

        guard case .failed = machine.enterLocal() else {
            return XCTFail("expected failed restore")
        }
        XCTAssertEqual(store.obligation?.inputSourceID, pinyin)
        XCTAssertEqual(machine.enterLocal(), .restored(pinyin))
        XCTAssertNil(store.obligation)
    }

    func testUnknownCurrentWithoutStateDoesNothing() {
        let input = MockInputSource()
        let machine = GuardStateMachine(
            selection: MockSelection(nil),
            inputSource: input,
            stateStore: MemoryStateStore()
        )

        XCTAssertEqual(machine.leaveLocal(), .skippedUnknownCurrent)
        XCTAssertTrue(input.selections.isEmpty)
    }

    func testUnknownCurrentWithStateReassertsABC() {
        let input = MockInputSource()
        let store = MemoryStateStore()
        store.obligation = RestoreObligation(inputSourceID: pinyin)
        let machine = GuardStateMachine(
            selection: MockSelection(nil),
            inputSource: input,
            stateStore: store
        )

        XCTAssertEqual(
            machine.leaveLocal(),
            .selectedABCWithExistingState(pinyin)
        )
        XCTAssertEqual(store.obligation?.inputSourceID, pinyin)
    }

    func testAlreadyABCDoesNotCreateState() {
        let store = MemoryStateStore()
        let input = MockInputSource()
        let machine = GuardStateMachine(
            selection: MockSelection(GuardConstants.abcInputSourceID),
            inputSource: input,
            stateStore: store
        )

        XCTAssertEqual(machine.leaveLocal(), .alreadyABC(saved: nil))
        XCTAssertNil(store.obligation)
        XCTAssertTrue(input.selections.isEmpty)
    }

    func testStateWriteFailureDoesNotSwitchToABC() {
        let store = MemoryStateStore()
        store.saveError = TestError.expected
        let input = MockInputSource()
        let machine = GuardStateMachine(
            selection: MockSelection(pinyin),
            inputSource: input,
            stateStore: store
        )

        guard case .failed = machine.leaveLocal() else {
            return XCTFail("expected state write failure")
        }
        XCTAssertTrue(input.selections.isEmpty)
    }

    func testABCFailureKeepsSavedState() {
        let store = MemoryStateStore()
        let input = MockInputSource()
        input.results = [1]
        let machine = GuardStateMachine(
            selection: MockSelection(pinyin),
            inputSource: input,
            stateStore: store
        )

        guard case .failed = machine.leaveLocal() else {
            return XCTFail("expected ABC selection failure")
        }
        XCTAssertEqual(store.obligation?.inputSourceID, pinyin)
    }

    func testSeededTransitionOrdersAlwaysRestoreOriginalSource() {
        var generator = SeededGenerator(seed: 0xC0FFEE)
        for _ in 0..<130 {
            let store = MemoryStateStore()
            let input = MockInputSource()
            let selection = MockSelection(pinyin)
            let machine = GuardStateMachine(
                selection: selection,
                inputSource: input,
                stateStore: store
            )
            _ = machine.leaveLocal()
            selection.current = GuardConstants.abcInputSourceID
            for _ in 0..<Int.random(in: 0...12, using: &generator) {
                if Bool.random(using: &generator) {
                    _ = machine.leaveLocal()
                } else if Bool.random(using: &generator) {
                    _ = machine.enterLocal()
                    _ = machine.leaveLocal()
                }
            }
            _ = machine.enterLocal()
            XCTAssertNil(store.obligation)
            XCTAssertEqual(input.current, pinyin)
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
