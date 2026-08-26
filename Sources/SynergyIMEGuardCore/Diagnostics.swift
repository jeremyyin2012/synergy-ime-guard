import Foundation

public struct DiagnosticReport: Codable, Equatable {
    public let version: String
    public let role: String?
    public let screenName: String?
    public let syncLanguage: Bool
    public let currentInputSourceID: String?
    public let abcAvailable: Bool
    public let savedInputSourceID: String?
    public let lastLocation: String

    public init(
        version: String,
        role: String?,
        screenName: String?,
        syncLanguage: Bool,
        currentInputSourceID: String?,
        abcAvailable: Bool,
        savedInputSourceID: String?,
        lastLocation: String
    ) {
        self.version = version
        self.role = role
        self.screenName = screenName
        self.syncLanguage = syncLanguage
        self.currentInputSourceID = currentInputSourceID
        self.abcAvailable = abcAvailable
        self.savedInputSourceID = savedInputSourceID
        self.lastLocation = lastLocation
    }
}
