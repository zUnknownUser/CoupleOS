import XCTest
@testable import CoupleOS

final class DailyExperienceTests: XCTestCase {
    func testUntouchedMomentIsAvailableToBothPartners() {
        let today = moment(answeredBy: [])
        XCTAssertEqual(today.status(for: "me"), .available)
        XCTAssertEqual(today.status(for: "you"), .available)
        XCTAssertTrue(today.canAnswer(as: "me"))
        XCTAssertTrue(today.canAnswer(as: "you"))
    }

    func testPartnerAnsweringFirstLeavesTheMomentOpenToMe() {
        let today = moment(answeredBy: ["you"])
        XCTAssertEqual(today.status(for: "me"), .waitingForMe)
        XCTAssertEqual(today.status(for: "you"), .waitingForPartner)
        XCTAssertTrue(today.canAnswer(as: "me"))
        XCTAssertFalse(today.canAnswer(as: "you"))
    }

    func testAnsweringClosesTheMomentForMeOnly() {
        let today = moment(answeredBy: ["me"])
        XCTAssertEqual(today.status(for: "me"), .waitingForPartner)
        XCTAssertEqual(today.status(for: "you"), .waitingForMe)
        XCTAssertFalse(today.canAnswer(as: "me"))
        XCTAssertTrue(today.canAnswer(as: "you"))
    }

    func testRevealedMomentIsClosedToBothPartners() {
        let today = moment(answeredBy: ["me", "you"], revealedAnswers: ["me": 0, "you": 1])
        XCTAssertTrue(today.isRevealed)
        XCTAssertEqual(today.status(for: "me"), .revealAvailable)
        XCTAssertEqual(today.status(for: "you"), .revealAvailable)
        XCTAssertFalse(today.canAnswer(as: "me"))
        XCTAssertFalse(today.canAnswer(as: "you"))
    }

    private func moment(
        answeredBy answered: Set<String>,
        revealedAnswers: [String: Int]? = nil
    ) -> DailyExperience {
        DailyExperience(
            id: "2026-09-01",
            periodKey: "2026-09-01",
            prompt: "What would feel most like us today?",
            options: ["Stay in", "Go out"],
            answeredUserIDs: answered,
            revealedAnswers: revealedAnswers
        )
    }
}
