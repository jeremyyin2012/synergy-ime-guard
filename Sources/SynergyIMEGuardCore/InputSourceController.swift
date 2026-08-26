import Carbon
import Foundation

public protocol InputSourceControlling: AnyObject {
    func currentID() -> String?
    func isAvailable(_ inputSourceID: String) -> Bool
    @discardableResult
    func select(_ inputSourceID: String) -> Int32?
}

public final class MacOSInputSourceController: InputSourceControlling {
    public init() {}

    public func currentID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        else {
            return nil
        }
        return inputSourceID(source)
    }

    public func isAvailable(_ inputSourceID: String) -> Bool {
        withSource(matching: inputSourceID) { _ in true } ?? false
    }

    @discardableResult
    public func select(_ inputSourceID: String) -> Int32? {
        withSource(matching: inputSourceID) { TISSelectInputSource($0) }
    }

    private func withSource<Result>(
        matching inputSourceID: String,
        perform: (TISInputSource) -> Result
    ) -> Result? {
        guard let unmanaged = TISCreateInputSourceList(nil, true) else {
            return nil
        }
        let sources = unmanaged.takeRetainedValue() as NSArray
        for case let source as TISInputSource in sources {
            if self.inputSourceID(source) == inputSourceID {
                return perform(source)
            }
        }
        return nil
    }

    private func inputSourceID(_ source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceID
        ) else {
            return nil
        }
        return Unmanaged<CFString>
            .fromOpaque(pointer)
            .takeUnretainedValue() as String
    }
}
