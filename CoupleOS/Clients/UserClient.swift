import ComposableArchitecture
import Foundation

@DependencyClient
nonisolated struct UserClient: Sendable {
    var fetchUser: @Sendable (_ id: String) async throws -> User?
    var createUser: @Sendable (_ request: CreateUserRequest) async throws -> User
    var updateUser: @Sendable (_ request: UpdateUserRequest) async throws -> User
}

extension UserClient: DependencyKey {
    static let liveValue = UserClient.firestore
    static let testValue = UserClient()
}

extension DependencyValues {
    nonisolated var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
