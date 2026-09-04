import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class ReadyForPartnerFeatureTests: XCTestCase {
    private let observationID = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!

    func testCreatesCoupleInviteAndEntersWaitingState() async {
        let couple = TestFixtures.couple()
        let invite = TestFixtures.invite
        let calls = LockIsolated(0)
        let store = TestStore(initialState: ReadyForPartnerFeature.State(
            session: TestFixtures.session
        )) { ReadyForPartnerFeature() } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.coupleClient.createCouple = {
                calls.withValue { $0 += 1 }
                return couple
            }
            $0.inviteClient.createInvite = { id in
                XCTAssertEqual(id, couple.id)
                return invite
            }
            $0.coupleClient.observeCouple = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(couple)
                    continuation.finish()
                }
            }
        }

        await store.send(.task)
        await store.receive(\.coupleResponse.success)
        await store.receive(\.inviteResponse) {
            $0.phase = .readyToInvite(couple, invite)
        }
        await store.receive(\.startObserving) {
            $0.phase = .waitingForPartner(couple, invite)
            $0.observationID = self.observationID
        }
        await store.receive(\.observationEvent)
        XCTAssertEqual(calls.value, 1)
    }

    func testRetryUsesIdempotentClientAndBuildsTheSameWorld() async {
        let couple = TestFixtures.couple()
        let invite = TestFixtures.invite
        let calls = LockIsolated(0)
        let store = TestStore(initialState: ReadyForPartnerFeature.State(
            session: TestFixtures.session,
            phase: .error(.couple(.unknown))
        )) { ReadyForPartnerFeature() } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.coupleClient.createCouple = {
                calls.withValue { $0 += 1 }
                return couple
            }
            $0.inviteClient.createInvite = { _ in invite }
            $0.coupleClient.observeCouple = { _ in
                AsyncThrowingStream { $0.finish() }
            }
        }

        await store.send(.retryTapped) { $0.phase = .preparingWorld }
        await store.receive(\.coupleResponse.success)
        await store.receive(\.inviteResponse) {
            $0.phase = .readyToInvite(couple, invite)
        }
        await store.receive(\.startObserving) {
            $0.phase = .waitingForPartner(couple, invite)
            $0.observationID = self.observationID
        }
        XCTAssertEqual(calls.value, 1)
    }

    func testRealtimeActiveEmitsPartnerJoined() async {
        let waiting = TestFixtures.couple()
        let active = TestFixtures.couple(status: .active)
        let invite = TestFixtures.invite
        let store = TestStore(initialState: ReadyForPartnerFeature.State(
            session: TestFixtures.session,
            phase: .waitingForPartner(waiting, invite),
            observationID: observationID
        )) { ReadyForPartnerFeature() }

        await store.send(.observationEvent(.init(id: observationID, result: .success(active)))) {
            var user = TestFixtures.session.user
            user.activeCoupleID = active.id
            user.onboardingStatus = .completed
            $0.session = Session(
                authenticatedUser: TestFixtures.authenticatedUser,
                user: user
            )
            $0.phase = .partnerJoined(active)
            $0.observationID = nil
        }
        await store.receive(\.delegate.partnerJoined)
    }

    func testStaleRealtimeEmissionIsIgnored() async {
        let waiting = TestFixtures.couple()
        let store = TestStore(initialState: ReadyForPartnerFeature.State(
            session: TestFixtures.session,
            phase: .waitingForPartner(waiting, TestFixtures.invite),
            observationID: observationID
        )) { ReadyForPartnerFeature() }

        await store.send(.observationEvent(.init(
            id: UUID(),
            result: .success(TestFixtures.couple(status: .active))
        )))
    }

}
