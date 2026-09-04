import ComposableArchitecture
import Foundation

@DependencyClient
nonisolated struct ChoreClient: Sendable {
    var create: @Sendable (
        _ coupleID: String,
        _ requestID: UUID,
        _ draft: ChoreDraft
    ) async throws -> Chore

    /// Marks a chore done and moves the turn on.
    ///
    /// `expectedDueAt` is the due date the caller was looking at. The backend
    /// refuses to advance a chore that has already moved, which is what keeps
    /// two people tapping "done" at the same moment from burning two cycles.
    /// A losing caller is not an error — it gets the chore as it now stands.
    var complete: @Sendable (
        _ coupleID: String,
        _ choreID: String,
        _ expectedDueAt: Date
    ) async throws -> Chore

    var remove: @Sendable (_ coupleID: String, _ choreID: String) async throws -> Void

    var observe: @Sendable (
        _ coupleID: String
    ) -> AsyncThrowingStream<[Chore], any Error> = { _ in
        AsyncThrowingStream { $0.finish() }
    }
}

extension ChoreClient: DependencyKey {
    static let liveValue = ChoreClient.firebase
    static let testValue = ChoreClient()
}

extension DependencyValues {
    nonisolated var choreClient: ChoreClient {
        get { self[ChoreClient.self] }
        set { self[ChoreClient.self] = newValue }
    }
}
