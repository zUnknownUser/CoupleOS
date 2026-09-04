import ComposableArchitecture
import Foundation

@DependencyClient
nonisolated struct PushNotificationClient: Sendable {
    /// Asks the system for permission, registering with APNs when granted.
    var requestAuthorization: @Sendable () async -> Bool = { false }

    /// Stores this install's current token so a partner's action can reach it,
    /// alongside the language this install reads in — the backend picks the
    /// wording of every notification from it, per device rather than per
    /// person, so two phones in one Couple World can differ.
    var registerDevice: @Sendable (_ userID: String, _ language: AppLanguage) async throws -> Void

    /// Removes this install's token, so a signed-out phone stops receiving a
    /// Couple's notifications.
    var unregisterDevice: @Sendable (_ userID: String) async -> Void = { _ in }

    /// Fires whenever FCM rotates the token and it has to be stored again.
    var tokenRefreshes: @Sendable () -> AsyncStream<Void> = { .finished }
}

extension PushNotificationClient: DependencyKey {
    static let liveValue = PushNotificationClient.firebase

    /// Push is ambient: it runs on `.task` and on sign-out without being what
    /// those tests are about. Denying authorization by default makes it inert
    /// everywhere, so only a test that opts in has to think about it.
    static let testValue = PushNotificationClient(
        requestAuthorization: { false },
        registerDevice: { _, _ in },
        unregisterDevice: { _ in },
        tokenRefreshes: { .finished }
    )
}

extension DependencyValues {
    nonisolated var pushNotificationClient: PushNotificationClient {
        get { self[PushNotificationClient.self] }
        set { self[PushNotificationClient.self] = newValue }
    }
}

nonisolated enum PushNotificationError: Error, Equatable, Sendable {
    case tokenUnavailable
    case storageFailed
}
