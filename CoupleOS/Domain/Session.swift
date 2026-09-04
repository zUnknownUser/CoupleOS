import Foundation

nonisolated struct Session: Equatable, Sendable {
    let authenticatedUser: AuthenticatedUser
    let user: User
}
