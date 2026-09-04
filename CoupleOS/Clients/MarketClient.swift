import ComposableArchitecture
import Foundation

@DependencyClient
nonisolated struct MarketClient: Sendable {
    var addItem: @Sendable (
        _ coupleID: String,
        _ requestID: UUID,
        _ name: String,
        _ note: String?,
        _ isRequest: Bool
    ) async throws -> MarketItem
    var setItemStatus: @Sendable (
        _ coupleID: String,
        _ itemID: String,
        _ status: MarketItem.Status
    ) async throws -> MarketItem
    var removeItem: @Sendable (_ coupleID: String, _ itemID: String) async throws -> Void
    var startRun: @Sendable (_ coupleID: String, _ requestID: UUID) async throws -> MarketRun
    var finishRun: @Sendable (_ coupleID: String, _ runID: String) async throws -> MarketRun
    /// Empties the basket when no run is open — things ticked off at home.
    var clearGathered: @Sendable (_ coupleID: String) async throws -> Void
    var observe: @Sendable (
        _ coupleID: String
    ) -> AsyncThrowingStream<MarketBoard, any Error> = { _ in
        AsyncThrowingStream { $0.finish() }
    }
}

extension MarketClient: DependencyKey {
    static let liveValue = MarketClient.firebase
    static let testValue = MarketClient()
}

extension DependencyValues {
    nonisolated var marketClient: MarketClient {
        get { self[MarketClient.self] }
        set { self[MarketClient.self] = newValue }
    }
}
