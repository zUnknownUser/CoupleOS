import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class TodayFeatureTests: XCTestCase {
    private let experience = DailyExperience(
        id: "2026-09-01",
        periodKey: "2026-09-01",
        prompt: "What would feel most like us today?",
        options: ["Stay in", "Go out"],
        answeredUserIDs: [],
        revealedAnswers: nil
    )

    func testSubmittingAnswerUpdatesPrivateStateAndWaitsForPartner() async {
        let updated = moment(answeredBy: ["me"])
        let store = TestStore(initialState: TodayFeature.State(coupleID: "couple", currentUserID: "me", experience: experience)) { TodayFeature() } withDependencies: {
            $0.dailyExperienceClient.submitAnswer = { _, _, _ in updated }
        }
        await store.send(.optionTapped(0)) { $0.selectedOption = 0 }
        await store.send(.submitTapped) { $0.isSubmitting = true }
        await store.receive(\.response) {
            $0.isSubmitting = false
            $0.experience = updated
            $0.selectedOption = nil
        }
    }

    func testRevealOnlyAppearsAfterRealtimeUpdate() async {
        let store = TestStore(initialState: TodayFeature.State(coupleID: "couple", currentUserID: "me", experience: experience)) { TodayFeature() }
        let revealed = moment(answeredBy: ["me", "you"], revealedAnswers: ["me": 0, "you": 1])
        await store.send(.experienceUpdated(revealed)) { $0.experience = revealed }
    }

    func testPartnerAnsweringFirstStillLetsMeAnswer() async {
        let revealed = moment(answeredBy: ["me", "you"], revealedAnswers: ["me": 1, "you": 0])
        let store = TestStore(initialState: TodayFeature.State(coupleID: "couple", currentUserID: "me", experience: moment(answeredBy: ["you"]))) { TodayFeature() } withDependencies: {
            $0.dailyExperienceClient.submitAnswer = { _, _, _ in revealed }
        }
        await store.send(.optionTapped(1)) { $0.selectedOption = 1 }
        await store.send(.submitTapped) { $0.isSubmitting = true }
        await store.receive(\.response) {
            $0.isSubmitting = false
            $0.experience = revealed
            $0.selectedOption = nil
        }
    }

    func testPartnerAnsweringWhileIChooseKeepsMySelection() async {
        let store = TestStore(initialState: TodayFeature.State(coupleID: "couple", currentUserID: "me", experience: experience)) { TodayFeature() }
        await store.send(.optionTapped(0)) { $0.selectedOption = 0 }
        let partnerAnswered = moment(answeredBy: ["you"])
        await store.send(.experienceUpdated(partnerAnswered)) { $0.experience = partnerAnswered }
    }

    func testAnsweredUserCannotChangeTheirAnswer() async {
        let store = TestStore(initialState: TodayFeature.State(coupleID: "couple", currentUserID: "me", experience: moment(answeredBy: ["me"]))) { TodayFeature() }
        await store.send(.optionTapped(1))
        await store.send(.submitTapped)
    }

    func testRevealedMomentCannotBeAnswered() async {
        let revealed = moment(answeredBy: ["me", "you"], revealedAnswers: ["me": 0, "you": 1])
        let store = TestStore(initialState: TodayFeature.State(coupleID: "couple", currentUserID: "me", experience: revealed)) { TodayFeature() }
        await store.send(.optionTapped(1))
    }

    func testOptionOutsideTheMomentIsIgnored() async {
        let store = TestStore(initialState: TodayFeature.State(coupleID: "couple", currentUserID: "me", experience: experience)) { TodayFeature() }
        await store.send(.optionTapped(7))
    }

    private func moment(
        answeredBy answered: Set<String>,
        revealedAnswers: [String: Int]? = nil
    ) -> DailyExperience {
        DailyExperience(
            id: experience.id,
            periodKey: experience.periodKey,
            prompt: experience.prompt,
            options: experience.options,
            answeredUserIDs: answered,
            revealedAnswers: revealedAnswers
        )
    }
}
