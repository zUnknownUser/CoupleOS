import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class CreateDecisionFeatureTests: XCTestCase {
    private let requestID = UUID(uuidString: "5A559C84-40E2-471F-8611-26FC22BBC139")!

    func testInvalidDraftDoesNotCallClient() async {
        let store = TestStore(initialState: state()) {
            CreateDecisionFeature()
        } withDependencies: {
            $0.decisionClient.create = { _, _, _, _ in
                XCTFail("Invalid input must not reach the backend.")
                throw DecisionClientError.unknown
            }
        }

        await store.send(.submitTapped) {
            $0.hasAttemptedSubmit = true
        }
        XCTAssertEqual(store.state.validation, .missingTitle)
    }

    func testCreateUsesOneStableIdempotencyIDAndDismisses() async {
        let result = decision()
        let dismissed = LockIsolated(false)
        let store = TestStore(initialState: state()) {
            CreateDecisionFeature()
        } withDependencies: {
            $0.uuid = .constant(self.requestID)
            $0.decisionClient.create = { coupleID, requestID, title, options in
                XCTAssertEqual(coupleID, "couple")
                XCTAssertEqual(requestID, self.requestID)
                XCTAssertEqual(title, "What should we watch?")
                XCTAssertEqual(options, ["Dune", "Arrival"])
                return result
            }
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(.titleChanged("  What should we watch?  ")) {
            $0.title = "  What should we watch?  "
        }
        await store.send(.optionChanged(index: 0, value: " Dune ")) {
            $0.options[0] = " Dune "
        }
        await store.send(.optionChanged(index: 1, value: "Arrival")) {
            $0.options[1] = "Arrival"
        }
        await store.send(.submitTapped) {
            $0.hasAttemptedSubmit = true
            $0.requestID = self.requestID
            $0.isSubmitting = true
        }
        await store.receive(.response(.success(result))) {
            $0.isSubmitting = false
        }
        await store.finish()
        XCTAssertTrue(dismissed.value)
    }

    func testFailureKeepsRequestIDForSafeRetry() async {
        let store = TestStore(initialState: validState()) {
            CreateDecisionFeature()
        } withDependencies: {
            $0.uuid = .constant(self.requestID)
            $0.decisionClient.create = { _, _, _, _ in
                throw DecisionClientError.networkUnavailable
            }
        }

        await store.send(.submitTapped) {
            $0.hasAttemptedSubmit = true
            $0.requestID = self.requestID
            $0.isSubmitting = true
        }
        await store.receive(.response(.failure(.networkUnavailable))) {
            $0.isSubmitting = false
            $0.error = .networkUnavailable
        }
        XCTAssertEqual(store.state.requestID, requestID)
    }

    private func state() -> CreateDecisionFeature.State {
        CreateDecisionFeature.State(
            coupleID: "couple",
            currentUserID: "creator",
            partnerID: "partner"
        )
    }

    private func validState() -> CreateDecisionFeature.State {
        var state = state()
        state.title = "Choose one"
        state.options = ["A", "B"]
        return state
    }

    private func decision() -> Decision {
        Decision(
            id: requestID.uuidString.lowercased(),
            coupleID: "couple",
            title: "What should we watch?",
            options: ["Dune", "Arrival"],
            creatorID: "creator",
            responderID: "partner",
            status: .waitingForPartner,
            createdAt: Date(timeIntervalSince1970: 1),
            selectedOptionIndex: nil,
            resolvedAt: nil
        )
    }
}
