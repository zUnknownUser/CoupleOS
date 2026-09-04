import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class DecisionDetailFeatureTests: XCTestCase {
    func testOnlyResponderCanChoose() async {
        let store = TestStore(initialState: DecisionDetailFeature.State(
            decision: waitingDecision(),
            currentUserID: "creator"
        )) {
            DecisionDetailFeature()
        }

        await store.send(.optionTapped(0))
        await store.send(.resolveTapped)
    }

    func testResponderResolvesAndSeesResult() async {
        let resolved = resolvedDecision()
        let store = TestStore(initialState: DecisionDetailFeature.State(
            decision: waitingDecision(),
            currentUserID: "partner"
        )) {
            DecisionDetailFeature()
        } withDependencies: {
            $0.decisionClient.resolve = { coupleID, decisionID, optionIndex in
                XCTAssertEqual(coupleID, "couple")
                XCTAssertEqual(decisionID, "decision")
                XCTAssertEqual(optionIndex, 1)
                return resolved
            }
        }

        await store.send(.optionTapped(1)) { $0.selectedOptionIndex = 1 }
        await store.send(.resolveTapped) {
            $0.isResolving = true
            $0.error = nil
        }
        await store.receive(.response(.success(resolved))) {
            $0.decision = resolved
            $0.isResolving = false
            $0.selectedOptionIndex = nil
        }
        XCTAssertEqual(store.state.presentation, .resolved)
        XCTAssertEqual(store.state.decision?.selectedOption, "B")
    }

    func testRealtimeRemovalMakesOpenDetailUnavailable() async {
        let store = TestStore(initialState: DecisionDetailFeature.State(
            decision: waitingDecision(),
            currentUserID: "partner"
        )) {
            DecisionDetailFeature()
        }

        await store.send(.decisionUpdated(nil)) {
            $0.decision = nil
        }
        XCTAssertEqual(store.state.presentation, .unavailable)
    }

    private func waitingDecision() -> Decision {
        Decision(
            id: "decision",
            coupleID: "couple",
            title: "Choose one",
            options: ["A", "B"],
            creatorID: "creator",
            responderID: "partner",
            status: .waitingForPartner,
            createdAt: Date(timeIntervalSince1970: 1),
            selectedOptionIndex: nil,
            resolvedAt: nil
        )
    }

    private func resolvedDecision() -> Decision {
        Decision(
            id: "decision",
            coupleID: "couple",
            title: "Choose one",
            options: ["A", "B"],
            creatorID: "creator",
            responderID: "partner",
            status: .resolved,
            createdAt: Date(timeIntervalSince1970: 1),
            selectedOptionIndex: 1,
            resolvedAt: Date(timeIntervalSince1970: 2)
        )
    }
}
