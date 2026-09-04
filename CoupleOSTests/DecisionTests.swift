import XCTest
@testable import CoupleOS

final class DecisionTests: XCTestCase {
    func testParticipationIsRelativeToTheCurrentMember() {
        let decision = decision(status: .waitingForPartner)

        XCTAssertEqual(decision.participation(for: "creator"), .waitingForPartner)
        XCTAssertEqual(decision.participation(for: "partner"), .needsMyResponse)
        XCTAssertEqual(decision.participation(for: "stranger"), .unavailable)
    }

    func testResolvedDecisionExposesOnlyAValidResult() {
        let resolved = decision(status: .resolved, selectedOptionIndex: 1)
        XCTAssertEqual(resolved.participation(for: "creator"), .resolved)
        XCTAssertEqual(resolved.selectedOption, "B")
    }

    private func decision(
        status: Decision.Status,
        selectedOptionIndex: Int? = nil
    ) -> Decision {
        Decision(
            id: "decision",
            coupleID: "couple",
            title: "Choose one",
            options: ["A", "B"],
            creatorID: "creator",
            responderID: "partner",
            status: status,
            createdAt: Date(timeIntervalSince1970: 1),
            selectedOptionIndex: selectedOptionIndex,
            resolvedAt: status == .resolved ? Date(timeIntervalSince1970: 2) : nil
        )
    }
}
