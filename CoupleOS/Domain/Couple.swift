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

nonisolated enum CoupleClientError: Error, Equatable, Sendable {
    case profileRequired
    case alreadyInCouple
    case coupleNotFound
    case coupleAlreadyFull
    case networkUnavailable
    case permissionDenied
    case invalidData
    case unknown

    var message: String {
        switch self {
        case .profileRequired: "Finish your profile before creating your world."
        case .alreadyInCouple: "This account already belongs to a Couple World."
        case .coupleNotFound: "We couldn't find this Couple World."
        case .coupleAlreadyFull: "This Couple World is already shared."
        case .networkUnavailable: "You're offline. Reconnect and try again."
        case .permissionDenied: "You don't have access to this Couple World."
        case .invalidData: "This Couple World needs attention before it can open."
        case .unknown: "We couldn't prepare your world. Please try again."
        }
    }
}

nonisolated enum InviteClientError: Error, Equatable, Sendable {
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

    var message: String {
        switch self {
        case .inviteInvalid: "This invite isn't valid. Ask your person for a new link."
        case .inviteExpired: "This invite has expired. Ask your person to share a new one."
        case .inviteAlreadyUsed: "This invite has already been used or replaced."
        case .cannotAcceptOwnInvite: "This invite is for your person—not for the account that created it."
        case .alreadyInCouple: "This account already belongs to a Couple World."
        case .coupleNotFound: "The Couple World behind this invite no longer exists."
        case .coupleAlreadyFull: "This Couple World is already shared by two people."
        case .configurationMissing: "Invite links aren't configured for this build."
        case .networkUnavailable: "You're offline. Reconnect and try again."
        case .permissionDenied: "We couldn't verify this invite for your account."
        case .unknown: "We couldn't accept this invite. Please try again."
        }
    }
}
