import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class InviteAcceptanceFeatureTests: XCTestCase {
    private let requestID = UUID(uuidString: "00000000-0000-0000-0000-000000000200")!

    func testAcceptSuccessCompletesLocalIdentityAndDelegates() async {
        let active = TestFixtures.couple(status: .active)
        let store = makeStore { _ in active }

        await store.send(.task) { $0.requestID = self.requestID }
        await store.receive(.response(.init(id: self.requestID, result: .success(active)))) {
            var user = TestFixtures.session.user
            user.activeCoupleID = active.id
            user.onboardingStatus = .completed
            $0.session = Session(authenticatedUser: TestFixtures.authenticatedUser, user: user)
            $0.phase = .joined(active)
            $0.requestID = nil
        }
        await store.receive(\.delegate.accepted)
    }

    func testExpiredInvite() async { await assertFailure(.inviteExpired) }
    func testInvalidInvite() async { await assertFailure(.inviteInvalid) }
    func testAlreadyUsedInvite() async { await assertFailure(.inviteAlreadyUsed) }
    func testOwnInvite() async { await assertFailure(.cannotAcceptOwnInvite) }
    func testAlreadyInCouple() async { await assertFailure(.alreadyInCouple) }

    func testDoubleSubmitIsIgnored() async {
        let operation = ControlledInviteAcceptance()
        let calls = LockIsolated(0)
        let store = makeStore { _ in
            calls.withValue { $0 += 1 }
            return try await operation.run()
        }

        await store.send(.task) { $0.requestID = self.requestID }
        await operation.waitUntilStarted()
        await store.send(.retryTapped)
        await operation.succeed(TestFixtures.couple(status: .active))
        await store.receive(.response(.init(
            id: self.requestID,
            result: .success(TestFixtures.couple(status: .active))
        ))) {
            var user = TestFixtures.session.user
            user.activeCoupleID = "couple-1"
            user.onboardingStatus = .completed
            $0.session = Session(authenticatedUser: TestFixtures.authenticatedUser, user: user)
            $0.phase = .joined(TestFixtures.couple(status: .active))
            $0.requestID = nil
        }
        await store.receive(\.delegate.accepted)
        XCTAssertEqual(calls.value, 1)
    }

    private func assertFailure(_ error: InviteClientError) async {
        let store = makeStore { _ in throw error }
        await store.send(.task) { $0.requestID = self.requestID }
        await store.receive(.response(.init(id: self.requestID, result: .failure(error)))) {
            $0.phase = .error(error)
            $0.requestID = nil
        }
    }

    private func makeStore(
        accept: @escaping @Sendable (InviteToken) async throws -> Couple
    ) -> TestStoreOf<InviteAcceptanceFeature> {
        TestStore(initialState: InviteAcceptanceFeature.State(
            session: TestFixtures.session,
            token: TestFixtures.inviteToken
        )) { InviteAcceptanceFeature() } withDependencies: {
            $0.uuid = .constant(self.requestID)
            $0.inviteClient.acceptInvite = accept
        }
    }
}

private actor ControlledInviteAcceptance {
    private var continuation: CheckedContinuation<Couple, any Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func run() async throws -> Couple {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let waiters = waiters
            self.waiters.removeAll()
            waiters.forEach { $0.resume() }
        }
    }

    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func succeed(_ couple: Couple) {
        continuation?.resume(returning: couple)
        continuation = nil
    }
}
