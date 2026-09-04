import ComposableArchitecture
import Foundation

@DependencyClient
nonisolated struct AuthenticationClient: Sendable {
    var currentUser: @Sendable () async -> AuthenticatedUser?
    var authStateChanges: @Sendable () -> AsyncStream<AuthenticatedUser?> = { .finished }
    var signIn: @Sendable (_ email: String, _ password: String) async throws -> AuthenticatedUser
    var signUp: @Sendable (_ email: String, _ password: String) async throws -> AuthenticatedUser
    var signInWithApple: @Sendable () async throws -> AuthenticatedUser
    var sendPasswordReset: @Sendable (_ email: String) async throws -> Void
    var signOut: @Sendable () async throws -> Void
}

extension AuthenticationClient: DependencyKey {
    static let liveValue = AuthenticationClient.firebase
    static let testValue = AuthenticationClient()
}

extension DependencyValues {
    nonisolated var authenticationClient: AuthenticationClient {
        get { self[AuthenticationClient.self] }
        set { self[AuthenticationClient.self] = newValue }
    }
}
