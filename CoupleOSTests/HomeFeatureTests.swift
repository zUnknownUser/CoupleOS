import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class HomeFeatureTests: XCTestCase {
    private let requestID = UUID(uuidString: "00000000-0000-0000-0000-000000000200")!

    func testCoupleLoadsItsPartnerOnce() async {
        let partner = partnerUser()
        let calls = LockIsolated(0)
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.uuid = .constant(self.requestID)
            $0.userClient.fetchUser = { id in
                XCTAssertEqual(id, partner.id)
                calls.withValue { $0 += 1 }
                return partner
            }
            $0.dailyExperienceClient.getToday = { _ in DailyExperience(id: "2026-09-01", periodKey: "2026-09-01", prompt: "Prompt", options: ["A"], answeredUserIDs: [], revealedAnswers: nil) }
            $0.dailyExperienceClient.observeToday = { _, _ in AsyncThrowingStream { $0.finish() } }
        }

        await store.send(.coupleAvailable(
            coupleID: "couple-1",
            currentUserID: TestFixtures.authenticatedUser.id,
            memberIDs: TestFixtures.couple(status: .active).memberIDs
        )) {
            $0.partnerID = partner.id
            $0.partnerRequestID = self.requestID
            $0.dailyRequestID = self.requestID
            $0.dailyCoupleID = "couple-1"
            $0.dailyCurrentUserID = TestFixtures.authenticatedUser.id
        }
        await store.receive(\.partnerResponse) {
            $0.partnerRequestID = nil
            $0.partner = .loaded(partner)
        }
        await store.receive(\.dailyResponse) {
            $0.dailyRequestID = nil
            $0.dailyObservationID = self.requestID
            $0.dailyExperience = DailyExperience(id: "2026-09-01", periodKey: "2026-09-01", prompt: "Prompt", options: ["A"], answeredUserIDs: [], revealedAnswers: nil)
        }
        await store.send(.coupleAvailable(
            coupleID: "couple-1",
            currentUserID: TestFixtures.authenticatedUser.id,
            memberIDs: TestFixtures.couple(status: .active).memberIDs
        ))
        XCTAssertEqual(calls.value, 1)
    }

    func testStalePartnerResponseIsIgnored() async {
        var state = HomeFeature.State()
        state.partnerID = "user-2"
        state.partnerRequestID = requestID
        let store = TestStore(initialState: state) { HomeFeature() }

        await store.send(.partnerResponse(.init(
            id: UUID(),
            partnerID: "user-2",
            result: .success(partnerUser())
        )))
    }

    func testTodayPresentationIsOwnedByHome() async {
        let experience = dailyExperience()
        var state = HomeFeature.State()
        state.dailyCoupleID = "couple-1"
        state.dailyCurrentUserID = TestFixtures.authenticatedUser.id
        state.dailyExperience = experience
        let store = TestStore(initialState: state) { HomeFeature() }

        await store.send(.todayTapped) {
            $0.destination = .today(TodayFeature.State(
                coupleID: "couple-1",
                currentUserID: TestFixtures.authenticatedUser.id,
                experience: experience
            ))
        }
    }

    func testDroppedDailyListenerSurfacesAndReconnects() async {
        let experience = dailyExperience()
        var state = HomeFeature.State()
        state.dailyCoupleID = "couple-1"
        state.dailyCurrentUserID = TestFixtures.authenticatedUser.id
        state.dailyObservationID = requestID
        state.dailyExperience = experience

        let reattached = LockIsolated(0)
        let store = TestStore(initialState: state) {
            HomeFeature()
        } withDependencies: {
            $0.uuid = .constant(self.requestID)
            $0.dailyExperienceClient.observeToday = { _, experienceID in
                XCTAssertEqual(experienceID, experience.id)
                reattached.withValue { $0 += 1 }
                return AsyncThrowingStream { $0.finish() }
            }
        }

        await store.send(.dailyObservationEvent(.init(
            id: requestID,
            result: .failure(.networkUnavailable)
        ))) {
            $0.dailyObservationID = nil
            $0.dailyError = .networkUnavailable
        }

        await store.send(.retryDailyTapped) {
            $0.dailyError = nil
            $0.dailyObservationID = self.requestID
        }
        XCTAssertEqual(reattached.value, 1)
    }

    func testRetryingBeforeTodayLoadsFetchesItAgain() async {
        var state = HomeFeature.State()
        state.dailyCoupleID = "couple-1"
        state.dailyCurrentUserID = TestFixtures.authenticatedUser.id
        state.dailyError = .notFound
        let experience = dailyExperience()

        let store = TestStore(initialState: state) {
            HomeFeature()
        } withDependencies: {
            $0.uuid = .constant(self.requestID)
            $0.dailyExperienceClient.getToday = { _ in experience }
            $0.dailyExperienceClient.observeToday = { _, _ in AsyncThrowingStream { $0.finish() } }
        }

        await store.send(.retryDailyTapped) {
            $0.dailyError = nil
            $0.dailyRequestID = self.requestID
        }
        await store.receive(\.dailyResponse) {
            $0.dailyRequestID = nil
            $0.dailyObservationID = self.requestID
            $0.dailyExperience = experience
        }
    }

    private func dailyExperience() -> DailyExperience {
        DailyExperience(
            id: "2026-09-01",
            periodKey: "2026-09-01",
            prompt: "Prompt",
            options: ["A"],
            answeredUserIDs: [],
            revealedAnswers: nil
        )
    }

    private func partnerUser() -> User {
        User(
            id: "user-2",
            firstName: "Sam",
            createdAt: Date(timeIntervalSince1970: 1_700_000_001),
            onboardingStatus: .completed,
            activeCoupleID: "couple-1"
        )
    }
}
