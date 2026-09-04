import Foundation

nonisolated struct User: Equatable, Sendable {
    let id: String
    var firstName: String
    let createdAt: Date
    var onboardingStatus: OnboardingStatus
    var activeCoupleID: String? = nil
}

nonisolated enum OnboardingStatus: String, Equatable, Sendable {
    case profileIncomplete
    case readyForPartner
    case completed
}

nonisolated struct CreateUserRequest: Equatable, Sendable {
    let id: String
    let firstName: String
    let onboardingStatus: OnboardingStatus
}

nonisolated struct UpdateUserRequest: Equatable, Sendable {
    let id: String
    let firstName: String
    let onboardingStatus: OnboardingStatus
}

nonisolated enum UserClientError: Error, Equatable, Sendable {
    case documentNotFound
    case invalidData
    case networkUnavailable
    case permissionDenied
    case unavailable
    case unknown

    var message: String {
        switch self {
        case .documentNotFound:
            "We couldn't find your profile."
        case .invalidData:
            "Your profile needs attention before we can open your world."
        case .networkUnavailable:
            "You're offline. Your account is safe—try again when you're connected."
        case .permissionDenied:
            "We couldn't access your profile. Please sign in again."
        case .unavailable:
            "Your profile is temporarily unavailable. Please try again."
        case .unknown:
            "We couldn't finish setting up your profile. Please try again."
        }
    }
}
