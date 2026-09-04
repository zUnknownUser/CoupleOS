import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class AuthenticatedFeatureTests: XCTestCase {
    private let observationID = UUID(uuidString: "00000000-0000-0000-0000-000000000300")!

    func testExistingSessionLoadsCorrectCoupleAndStartsHome() async {
        let couple = TestFixtures.couple(status: .active)
        let session = completedSession(coupleID: couple.id)
        let experience = dailyExperience()
        let store = TestStore(initialState: AuthenticatedFeature.State(session: session)) {
            AuthenticatedFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.coupleClient.fetchCurrentCouple = { couple }
            $0.userClient.fetchUser = { _ in nil }
            $0.coupleClient.observeCouple = { id in
                XCTAssertEqual(id, couple.id)
                return AsyncThrowingStream { $0.finish() }
            }
            $0.dailyExperienceClient.getToday = { _ in experience }
            $0.dailyExperienceClient.observeToday = { _, _ in AsyncThrowingStream { $0.finish() } }
            $0.decisionClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.marketClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.choreClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
        }

        await store.send(.task) {
            $0.coupleRequestID = self.observationID
        }
        await store.receive(\.coupleResponse) {
            $0.coupleRequestID = nil
            $0.couple = .connected(couple)
        }
        await store.receive(\.home.coupleAvailable) {
            $0.home.partnerID = "user-2"
            $0.home.partnerRequestID = self.observationID
            $0.home.dailyRequestID = self.observationID
            $0.home.dailyCoupleID = couple.id
            $0.home.dailyCurrentUserID = session.user.id
        }
        await store.receive(\.decisions.coupleAvailable) {
            $0.decisions.phase = .loading
            $0.decisions.coupleID = couple.id
            $0.decisions.currentUserID = session.user.id
            $0.decisions.partnerID = "user-2"
            $0.decisions.observationID = self.observationID
        }
        await store.receive(\.market.coupleAvailable) {
            $0.market.phase = .loading
            $0.market.coupleID = couple.id
            $0.market.currentUserID = session.user.id
            $0.market.partnerID = "user-2"
            $0.market.observationID = self.observationID
        }
        await store.receive(\.chores.coupleAvailable) {
            $0.chores.phase = .loading
            $0.chores.coupleID = couple.id
            $0.chores.currentUserID = session.user.id
            $0.chores.partnerID = "user-2"
            $0.chores.observationID = self.observationID
        }
        await store.receive(\.startObserving) {
            $0.observationID = self.observationID
        }
        await store.receive(\.home.partnerResponse) {
            $0.home.partnerRequestID = nil
            $0.home.partner = .unavailable
        }
        await store.receive(\.home.dailyResponse) {
            $0.home.dailyRequestID = nil
            $0.home.dailyObservationID = self.observationID
            $0.home.dailyExperience = experience
        }
    }

    func testRealtimeUpdateAndStaleEventProtection() async {
        let couple = TestFixtures.couple(status: .active)
        let session = completedSession(coupleID: couple.id)
        let experience = dailyExperience()
        var state = AuthenticatedFeature.State(session: session, couple: couple)
        state.observationID = observationID
        state.home.partnerID = "user-2"
        let store = TestStore(initialState: state) {
            AuthenticatedFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.dailyExperienceClient.getToday = { _ in experience }
            $0.dailyExperienceClient.observeToday = { _, _ in AsyncThrowingStream { $0.finish() } }
            $0.decisionClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.marketClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.choreClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
        }

        await store.send(.observationEvent(.init(
            id: UUID(),
            result: .success(couple)
        )))

        var updated = couple
        updated = Couple(
            id: updated.id,
            memberIDs: Array(updated.memberIDs.reversed()),
            status: updated.status,
            createdBy: updated.createdBy,
            createdAt: updated.createdAt,
            activatedAt: updated.activatedAt
        )
        await store.send(.observationEvent(.init(
            id: observationID,
            result: .success(updated)
        ))) {
            $0.couple = .connected(updated)
        }
        await store.receive(\.home.coupleAvailable) {
            $0.home.dailyRequestID = self.observationID
            $0.home.dailyCoupleID = couple.id
            $0.home.dailyCurrentUserID = session.user.id
        }
        await store.receive(\.home.dailyResponse) {
            $0.home.dailyRequestID = nil
            $0.home.dailyObservationID = self.observationID
            $0.home.dailyExperience = experience
        }
    }

    func testNotificationsRegisterOnceTheCoupleIsOpen() async {
        let couple = TestFixtures.couple(status: .active)
        let session = completedSession(coupleID: couple.id)
        let experience = dailyExperience()
        let registered = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: AuthenticatedFeature.State(session: session, couple: couple)
        ) {
            AuthenticatedFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.userClient.fetchUser = { _ in nil }
            $0.coupleClient.observeCouple = { _ in AsyncThrowingStream { $0.finish() } }
            $0.dailyExperienceClient.getToday = { _ in experience }
            $0.dailyExperienceClient.observeToday = { _, _ in AsyncThrowingStream { $0.finish() } }
            $0.decisionClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.marketClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.choreClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.pushNotificationClient.requestAuthorization = { true }
            $0.pushNotificationClient.registerDevice = { userID in
                registered.withValue { $0.append(userID) }
            }
        }
        store.exhaustivity = .off

        await store.send(.task)
        await store.finish()

        XCTAssertEqual(registered.value, [session.user.id])
    }

    func testRefusedPermissionNeverStoresADevice() async {
        let couple = TestFixtures.couple(status: .active)
        let session = completedSession(coupleID: couple.id)
        let experience = dailyExperience()
        let store = TestStore(
            initialState: AuthenticatedFeature.State(session: session, couple: couple)
        ) {
            AuthenticatedFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.userClient.fetchUser = { _ in nil }
            $0.coupleClient.observeCouple = { _ in AsyncThrowingStream { $0.finish() } }
            $0.dailyExperienceClient.getToday = { _ in experience }
            $0.dailyExperienceClient.observeToday = { _, _ in AsyncThrowingStream { $0.finish() } }
            $0.decisionClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.marketClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.choreClient.observe = { _ in AsyncThrowingStream { $0.finish() } }
            $0.pushNotificationClient.requestAuthorization = { false }
            $0.pushNotificationClient.registerDevice = { _ in
                XCTFail("A refused prompt must not store a device.")
            }
        }
        store.exhaustivity = .off

        await store.send(.task)
        await store.finish()
    }

    func testSignOutDropsTheDeviceBeforeGivingUpCredentials() async {
        let couple = TestFixtures.couple(status: .active)
        let session = completedSession(coupleID: couple.id)
        let steps = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: AuthenticatedFeature.State(session: session, couple: couple)
        ) {
            AuthenticatedFeature()
        } withDependencies: {
            $0.pushNotificationClient.unregisterDevice = { userID in
                XCTAssertEqual(userID, session.user.id)
                steps.withValue { $0.append("unregister") }
            }
            $0.authenticationClient.signOut = {
                steps.withValue { $0.append("signOut") }
            }
        }

        await store.send(.signOutTapped) { $0.isSigningOut = true }
        await store.receive(\.decisions.stop)
        await store.receive(\.market.stop)
        await store.receive(\.chores.stop)
        await store.receive(\.signOutResponse) { $0.isSigningOut = false }
        await store.receive(\.delegate.signedOut)

        XCTAssertEqual(steps.value, ["unregister", "signOut"])
    }

    private func dailyExperience() -> DailyExperience {
        DailyExperience(
            id: "2026-09-01",
            periodKey: "2026-09-01",
            prompt: "What would feel most like us today?",
            options: ["Stay in", "Go out"],
            answeredUserIDs: [],
            revealedAnswers: nil
        )
    }

    private func completedSession(coupleID: String) -> Session {
        var user = TestFixtures.session.user
        user.activeCoupleID = coupleID
        user.onboardingStatus = .completed
        return Session(
            authenticatedUser: TestFixtures.session.authenticatedUser,
            user: user
        )
    }
}
