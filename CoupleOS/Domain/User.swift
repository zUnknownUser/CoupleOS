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

nonisolated enum UserClientError: Error, Equatable, Sendable, CaseIterable {
    case documentNotFound
    case invalidData
    case networkUnavailable
    case permissionDenied
    case unavailable
    case unknown
}
