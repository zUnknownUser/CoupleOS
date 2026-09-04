import Foundation

nonisolated struct AuthenticatedUser: Equatable, Sendable {
    let id: String
    let email: String?
    let displayName: String?
}

nonisolated enum AuthenticationError: Error, Equatable, Sendable, CaseIterable {
    case invalidCredentials
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case networkUnavailable
    case cancelled
    case unavailable
    case unknown
}
