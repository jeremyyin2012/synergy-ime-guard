import Foundation

public enum GuardAction: Equatable {
    case savedAndSelectedABC(String)
    case selectedABCWithExistingState(String)
    case alreadyABC(saved: String?)
    case skippedUnknownCurrent
    case restored(String)
    case noRestoreNeeded
    case failed(String)
}

public final class GuardStateMachine {
    private let selection: SystemSelectionReading
    private let inputSource: InputSourceControlling
    private let stateStore: RestoreStateStoring
    private let emit: (String) -> Void

    public init(
        selection: SystemSelectionReading,
        inputSource: InputSourceControlling,
        stateStore: RestoreStateStoring,
        emit: @escaping (String) -> Void = { _ in }
    ) {
        self.selection = selection
        self.inputSource = inputSource
        self.stateStore = stateStore
        self.emit = emit
    }

    @discardableResult
    public func leaveLocal() -> GuardAction {
        do {
            let existing = try stateStore.load()
            guard let current = selection.currentID() else {
                guard let existing else {
                    emit("leave current=unknown action=skip")
                    return .skippedUnknownCurrent
                }
                return selectABC(existing: existing, newlySaved: false)
            }

            if current == GuardConstants.abcInputSourceID {
                emit("leave current=\(current) action=already_abc")
                return .alreadyABC(saved: existing?.inputSourceID)
            }

            let obligation: RestoreObligation
            let newlySaved: Bool
            if let existing {
                obligation = existing
                newlySaved = false
            } else {
                obligation = try stateStore.saveIfAbsent(
                    RestoreObligation(inputSourceID: current)
                )
                newlySaved = true
            }
            return selectABC(existing: obligation, newlySaved: newlySaved)
        } catch {
            let detail = "leave_failed error=\(describe(error))"
            emit(detail)
            return .failed(detail)
        }
    }

    @discardableResult
    public func enterLocal() -> GuardAction {
        do {
            guard let obligation = try stateStore.load() else {
                emit("enter action=no_restore")
                return .noRestoreNeeded
            }
            guard inputSource.select(obligation.inputSourceID) == 0 else {
                let detail = "enter restore=\(obligation.inputSourceID) result=failed"
                emit(detail)
                return .failed(detail)
            }
            try stateStore.clear()
            emit("enter restored=\(obligation.inputSourceID)")
            return .restored(obligation.inputSourceID)
        } catch {
            let detail = "enter_failed error=\(describe(error))"
            emit(detail)
            return .failed(detail)
        }
    }

    public func savedInputSourceID() -> String? {
        try? stateStore.load()?.inputSourceID
    }

    private func selectABC(
        existing: RestoreObligation,
        newlySaved: Bool
    ) -> GuardAction {
        guard inputSource.select(GuardConstants.abcInputSourceID) == 0 else {
            let detail = "leave saved=\(existing.inputSourceID) select_abc=failed"
            emit(detail)
            return .failed(detail)
        }
        emit("leave saved=\(existing.inputSourceID) select_abc=ok")
        return newlySaved
            ? .savedAndSelectedABC(existing.inputSourceID)
            : .selectedABCWithExistingState(existing.inputSourceID)
    }

    private func describe(_ error: Error) -> String {
        "\(type(of: error)):\(error.localizedDescription)"
    }
}
