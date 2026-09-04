import ComposableArchitecture

@DependencyClient
nonisolated struct CoupleClient: Sendable {
    var createCouple: @Sendable () async throws -> Couple
    var fetchCurrentCouple: @Sendable () async throws -> Couple?
    var observeCouple: @Sendable (_ id: String) -> AsyncThrowingStream<Couple, any Error> = { _ in
        AsyncThrowingStream { $0.finish() }
    }
}

extension CoupleClient: DependencyKey {
    static let liveValue = CoupleClient.firebase
    static let testValue = CoupleClient()
}

extension DependencyValues {
    nonisolated var coupleClient: CoupleClient {
        get { self[CoupleClient.self] }
        set { self[CoupleClient.self] = newValue }
    }
}
