import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class ChoresFeatureTests: XCTestCase {
    private let observationID = UUID(uuidString: "00000000-0000-0000-0000-000000000500")!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testTheListSplitsByWhoseTurnItIs() async {
        let chores = [
            TestFixtures.chore(id: "mine", title: "Dishes", ownerID: "user-1"),
            TestFixtures.chore(id: "theirs", title: "Bins", ownerID: "user-2"),
            TestFixtures.chore(
                id: "later",
                title: "Windows",
                ownerID: "user-1",
                dueAt: Date(timeIntervalSince1970: 1_700_500_000)
            ),
        ]
        let store = makeStore(chores: chores)

        await open(store)
        await store.receive(\.observationEvent) {
            $0.phase = .ready
            $0.chores = chores
        }

        XCTAssertEqual(store.state.mine(asOf: now).map(\.id), ["mine"])
        XCTAssertEqual(store.state.theirs(asOf: now).map(\.id), ["theirs"])
        XCTAssertEqual(store.state.upcoming(asOf: now).map(\.id), ["later"])
    }

    func testAChoreNobodyOwnsBelongsToBoth() async {
        let chore = TestFixtures.chore(id: "shared", rotation: .anyone, ownerID: nil)

        XCTAssertTrue(chore.isMine("user-1"))
        XCTAssertTrue(chore.isMine("user-2"))
        XCTAssertFalse(chore.isWaitingOnPartner("user-1"))
    }

    // MARK: - Two people, one chore

    func testCompletingSendsTheCycleTheTapMeant() async {
        let chore = TestFixtures.chore(id: "dishes")
        let sent = LockIsolated<Date?>(nil)
        var state = readyState()
        state.chores = [chore]
        let store = TestStore(initialState: state) {
            ChoresFeature()
        } withDependencies: {
            $0.choreClient.complete = { coupleID, choreID, expectedDueAt in
                XCTAssertEqual(coupleID, "couple-1")
                XCTAssertEqual(choreID, "dishes")
                sent.setValue(expectedDueAt)
                return TestFixtures.chore(
                    id: "dishes",
                    ownerID: "user-2",
                    dueAt: expectedDueAt.addingTimeInterval(2 * 24 * 60 * 60),
                    lastDoneBy: "user-1",
                    lastDoneAt: expectedDueAt
                )
            }
        }

        await store.send(.completeTapped("dishes")) { $0.settlingChoreIDs = ["dishes"] }
        await store.receive(\.completeResponse) {
            $0.settlingChoreIDs = []
            $0.chores = [TestFixtures.chore(
                id: "dishes",
                ownerID: "user-2",
                dueAt: chore.dueAt.addingTimeInterval(2 * 24 * 60 * 60),
                lastDoneBy: "user-1",
                lastDoneAt: chore.dueAt
            )]
        }

        // The guard that lets both people hold this screen: the request names
        // the cycle it meant to close, so a late tap cannot burn a second one.
        XCTAssertEqual(sent.value, chore.dueAt)
        XCTAssertEqual(store.state.mine(asOf: now).map(\.id), [])
    }

    func testLosingTheRaceLandsOnWhatTheOtherPersonLeftBehind() async {
        // The partner got there first: the backend answers with the chore as it
        // now stands rather than failing, and the turn has already moved on.
        let advanced = TestFixtures.chore(
            id: "dishes",
            ownerID: "user-1",
            dueAt: Date(timeIntervalSince1970: 1_700_200_000),
            lastDoneBy: "user-2",
            lastDoneAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
        var state = readyState()
        state.chores = [TestFixtures.chore(id: "dishes", ownerID: "user-1")]
        let store = TestStore(initialState: state) {
            ChoresFeature()
        } withDependencies: {
            $0.choreClient.complete = { _, _, _ in advanced }
        }

        await store.send(.completeTapped("dishes")) { $0.settlingChoreIDs = ["dishes"] }
        await store.receive(\.completeResponse) {
            $0.settlingChoreIDs = []
            $0.chores = [advanced]
        }
        XCTAssertNil(store.state.errorMessage, "A lost race is not an error")
    }

    func testASecondTapWhileTheFirstIsInFlightGoesNowhere() async {
        var state = readyState()
        state.chores = [TestFixtures.chore(id: "dishes")]
        // Already settling: the first tap's call has not come back yet.
        state.settlingChoreIDs = ["dishes"]
        // `choreClient.complete` is deliberately left unimplemented — reaching
        // the network here is the failure this test is looking for.
        let store = TestStore(initialState: state) { ChoresFeature() }

        await store.send(.completeTapped("dishes"))
    }

    func testAFinishedChoreCannotBeCompletedAgain() async {
        var state = readyState()
        state.chores = [TestFixtures.chore(id: "shelf", cadence: .once, status: .done)]
        let store = TestStore(initialState: state) { ChoresFeature() }

        await store.send(.completeTapped("shelf"))
    }

    func testTakingSomeoneElsesTurnSurfacesTheRefusal() async {
        var state = readyState()
        state.chores = [TestFixtures.chore(id: "bins", ownerID: "user-2")]
        let store = TestStore(initialState: state) {
            ChoresFeature()
        } withDependencies: {
            $0.choreClient.complete = { _, _, _ in throw ChoreClientError.notYourTurn }
        }

        await store.send(.completeTapped("bins")) { $0.settlingChoreIDs = ["bins"] }
        await store.receive(\.completeResponse) {
            $0.settlingChoreIDs = []
            $0.errorMessage = ChoreClientError.notYourTurn.message
        }
    }

    // MARK: - Adding

    func testCreatingCarriesTheDraftAndClearsTheField() async {
        let created = TestFixtures.chore(id: "new", title: "Water the plants")
        let seen = LockIsolated<ChoreDraft?>(nil)
        var state = readyState()
        state.draftCadence = .everyDays(3)
        state.draftRotation = .alternates
        let store = TestStore(initialState: state) {
            ChoresFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.choreClient.create = { _, _, draft in
                seen.setValue(draft)
                return created
            }
        }

        await store.send(.binding(.set(\.draftTitle, "  Water the plants  "))) {
            $0.draftTitle = "  Water the plants  "
        }
        await store.send(.createTapped) {
            $0.isCreating = true
            $0.draftTitle = ""
        }
        await store.receive(\.createResponse) {
            $0.isCreating = false
            $0.chores = [created]
        }

        XCTAssertEqual(seen.value?.title, "Water the plants")
        XCTAssertEqual(seen.value?.cadence, .everyDays(3))
        XCTAssertEqual(seen.value?.firstOwnerID, "user-1")
    }

    func testABlankChoreNeverReachesTheClient() async {
        var state = readyState()
        state.draftTitle = "   "
        let store = TestStore(initialState: state) { ChoresFeature() }

        await store.send(.createTapped)
    }

    func testAnotherCouplesChoresCannotLand() async {
        var state = readyState()
        state.observationID = observationID
        let store = TestStore(initialState: state) { ChoresFeature() }

        await store.send(.observationEvent(.init(
            id: observationID,
            coupleID: "another-couple",
            result: .success([TestFixtures.chore(id: "x")])
        )))
    }

    func testStopClearsStateAndCancelsTheListener() async {
        let terminated = LockIsolated(false)
        let store = TestStore(initialState: ChoresFeature.State()) {
            ChoresFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.choreClient.observe = { _ in
                AsyncThrowingStream { continuation in
                    continuation.onTermination = { _ in terminated.setValue(true) }
                }
            }
        }

        await open(store)
        await store.send(.stop) { $0 = ChoresFeature.State() }
        await store.finish()
        XCTAssertTrue(terminated.value)
    }

    // MARK: - Helpers

    private func makeStore(chores: [Chore]) -> TestStoreOf<ChoresFeature> {
        TestStore(initialState: ChoresFeature.State()) {
            ChoresFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.choreClient.observe = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(chores)
                    continuation.finish()
                }
            }
        }
    }

    private func open(_ store: TestStoreOf<ChoresFeature>) async {
        await store.send(.coupleAvailable(
            coupleID: "couple-1",
            currentUserID: "user-1",
            partnerID: "user-2"
        )) {
            $0.coupleID = "couple-1"
            $0.currentUserID = "user-1"
            $0.partnerID = "user-2"
            $0.phase = .loading
            $0.observationID = self.observationID
        }
    }

    private func readyState() -> ChoresFeature.State {
        var state = ChoresFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.observationID = observationID
        return state
    }
}
