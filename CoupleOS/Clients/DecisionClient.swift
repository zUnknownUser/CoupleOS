import ComposableArchitecture
import Foundation

@DependencyClient
nonisolated struct DecisionClient: Sendable {
    var create: @Sendable (
        _ coupleID: String,
        _ requestID: UUID,
        _ title: String,
        _ options: [String]
    ) async throws -> Decision
    var resolve: @Sendable (
        _ coupleID: String,
        _ decisionID: String,
        _ optionIndex: Int
    ) async throws -> Decision
    var observe: @Sendable (
        _ coupleID: String
    ) -> AsyncThrowingStream<[Decision], any Error> = { _ in
        AsyncThrowingStream { $0.finish() }
    }
}

extension DecisionClient: DependencyKey {
    static let liveValue = DecisionClient.firebase
    static let testValue = DecisionClient()
}

extension DependencyValues {
    nonisolated var decisionClient: DecisionClient {
        get { self[DecisionClient.self] }
        set { self[DecisionClient.self] = newValue }
    }
}
