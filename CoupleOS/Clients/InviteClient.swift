import ComposableArchitecture
import Foundation

@DependencyClient
nonisolated struct InviteClient: Sendable {
    var createInvite: @Sendable (_ coupleID: String) async throws -> CoupleInvite
    var acceptInvite: @Sendable (_ token: InviteToken) async throws -> Couple
    var parseInviteURL: @Sendable (_ url: URL) throws -> InviteToken
}

extension InviteClient: DependencyKey {
    static let liveValue = InviteClient.firebase
    static let testValue = InviteClient()
}

extension DependencyValues {
    nonisolated var inviteClient: InviteClient {
        get { self[InviteClient.self] }
        set { self[InviteClient.self] = newValue }
    }
}
