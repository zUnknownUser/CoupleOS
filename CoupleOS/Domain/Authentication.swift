import Foundation

nonisolated struct AuthenticatedUser: Equatable, Sendable {
    let id: String
    let email: String?
    let displayName: String?
}

nonisolated enum AuthenticationError: Error, Equatable, Sendable {
    case invalidCredentials
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case networkUnavailable
    case cancelled
    case unavailable
    case unknown
    
    var message: String {
        switch self {
        case .invalidCredentials:
            "That email or password doesn't look right."
        case .invalidEmail:
            "Enter a valid email address."
        case .emailAlreadyInUse:
            "An account already exists for this email."
        case .weakPassword:
            "Choose a password with at least 6 characters."
        case .networkUnavailable:
            "You're offline. Check your connection and try again."
        case .cancelled:
            "Sign in was cancelled."
        case .unavailable:
            "Sign in isn't available right now."
        case .unknown:
            "Something went wrong. Please try again."
        }
    }
}
