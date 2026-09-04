import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class DecisionsFeatureTests: XCTestCase {
    private let observationID = UUID(uuidString: "3E286E48-C764-4F62-B48B-AD216D619300")!

    func testRealtimeBuildsNeedsYouWaitingAndRecent() async {
        let values = [
            decision(id: "needs", creator: "partner", responder: "me", status: .waitingForPartner),
            decision(id: "waiting", creator: "me", responder: "partner", status: .waitingForPartner),
            decision(id: "recent", creator: "me", responder: "partner", status: .resolved, option: 0),
        ]
        let store = TestStore(initialState: DecisionsFeature.State()) {
            DecisionsFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.decisionClient.observe = { coupleID in
                XCTAssertEqual(coupleID, "couple")
                return AsyncThrowingStream { continuation in
                    continuation.yield(values)
                    continuation.finish()
                }
            }
        }

        await store.send(.coupleAvailable(
            coupleID: "couple",
            currentUserID: "me",
            partnerID: "partner"
        )) {
            $0.coupleID = "couple"
            $0.currentUserID = "me"
            $0.partnerID = "partner"
            $0.phase = .loading
            $0.observationID = self.observationID
        }
        await store.receive(\.observationEvent) {
            $0.phase = .loaded(values)
        }
        XCTAssertEqual(store.state.needsMyResponse.map(\.id), ["needs"])
        XCTAssertEqual(store.state.waitingForPartner.map(\.id), ["waiting"])
        XCTAssertEqual(store.state.recent.map(\.id), ["recent"])
    }

    func testStaleObservationCannotReplaceCurrentCouple() async {
        var state = DecisionsFeature.State()
        state.coupleID = "couple"
        state.currentUserID = "me"
        state.partnerID = "partner"
        state.observationID = observationID
        state.phase = .loaded([])
        let store = TestStore(initialState: state) { DecisionsFeature() }

        await store.send(.observationEvent(.init(
            id: UUID(),
            coupleID: "old-couple",
            result: .success([decision(id: "stale")])
        )))
    }

    func testStopClearsStateAndCancelsListener() async {
        let terminated = LockIsolated(false)
        let store = TestStore(initialState: DecisionsFeature.State()) {
            DecisionsFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.decisionClient.observe = { _ in
                AsyncThrowingStream { continuation in
                    continuation.onTermination = { _ in terminated.setValue(true) }
                }
            }
        }

        await store.send(.coupleAvailable(
            coupleID: "couple",
            currentUserID: "me",
            partnerID: "partner"
        )) {
            $0.coupleID = "couple"
            $0.currentUserID = "me"
            $0.partnerID = "partner"
            $0.phase = .loading
            $0.observationID = self.observationID
        }
        await store.send(.stop) { $0 = DecisionsFeature.State() }
        await store.finish()
        XCTAssertTrue(terminated.value)
    }

    private func decision(
        id: String,
        creator: String = "partner",
        responder: String = "me",
        status: Decision.Status = .waitingForPartner,
        option: Int? = nil
    ) -> Decision {
        Decision(
            id: id,
            coupleID: "couple",
            title: "Choose one",
            options: ["A", "B"],
            creatorID: creator,
            responderID: responder,
            status: status,
            createdAt: Date(timeIntervalSince1970: 1),
            selectedOptionIndex: option,
            resolvedAt: status == .resolved ? Date(timeIntervalSince1970: 2) : nil
        )
    }
}
