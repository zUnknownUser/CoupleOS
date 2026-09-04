import Foundation

nonisolated struct Couple: Equatable, Sendable {
    let id: String
    let memberIDs: [String]
    let status: Status
    let createdBy: String
    let createdAt: Date
    let activatedAt: Date?

    nonisolated enum Status: String, Equatable, Sendable {
        case waitingForPartner
        case active
    }
}

nonisolated struct InviteToken: Equatable, Hashable, Sendable, CustomStringConvertible,
    CustomDebugStringConvertible {
    private(set) var rawValue: String

    init?(rawValue: String) {
        guard rawValue.count == 43,
              rawValue.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") })
        else { return nil }
        self.rawValue = rawValue
    }

    var description: String { "<redacted-invite-token>" }
    var debugDescription: String { description }
}

nonisolated struct CoupleInvite: Equatable, Sendable {
    let token: InviteToken
    let url: URL
    let expiresAt: Date
}

nonisolated enum CoupleClientError: Error, Equatable, Sendable, CaseIterable {
    case profileRequired
    case alreadyInCouple
    case coupleNotFound
    case coupleAlreadyFull
    case networkUnavailable
    case permissionDenied
    case invalidData
    case unknown
}

nonisolated enum InviteClientError: Error, Equatable, Sendable, CaseIterable {
    case inviteInvalid
    case inviteExpired
    case inviteAlreadyUsed
    case cannotAcceptOwnInvite
    case alreadyInCouple
    case coupleNotFound
    case coupleAlreadyFull
    case configurationMissing
    case networkUnavailable
    case permissionDenied
    case unknown
}
