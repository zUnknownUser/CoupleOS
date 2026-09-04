import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class MarketFeatureTests: XCTestCase {
    private let observationID = UUID(uuidString: "00000000-0000-0000-0000-000000000400")!

    func testListAndRunArriveAsOneBoard() async {
        let board = MarketBoard(
            items: [
                TestFixtures.marketItem(id: "ask", name: "Batteries", isRequest: true),
                TestFixtures.marketItem(id: "plain", name: "Milk"),
                TestFixtures.marketItem(id: "done", name: "Bread", status: .gathered),
            ],
            run: TestFixtures.marketRun()
        )
        let store = makeStore(board: board)

        await open(store)
        await store.receive(\.observationEvent) {
            $0.phase = .ready
            $0.board = board
        }

        // An ask outranks a plain item; gathered things leave the list entirely.
        XCTAssertEqual(store.state.pending.map(\.id), ["ask", "plain"])
        XCTAssertEqual(store.state.gathered.map(\.id), ["done"])
        XCTAssertEqual(store.state.requestsForMe.map(\.id), ["ask"])
        XCTAssertNotNil(store.state.partnerRun)
        XCTAssertNil(store.state.myRun)
    }

    func testMyOwnAskIsNotSomethingIAmAskedFor() async {
        let board = MarketBoard(
            items: [TestFixtures.marketItem(id: "mine", isRequest: true, requestedBy: "user-1")],
            run: nil
        )
        let store = makeStore(board: board)

        await open(store)
        await store.receive(\.observationEvent) {
            $0.phase = .ready
            $0.board = board
        }

        XCTAssertEqual(store.state.pending.map(\.id), ["mine"])
        XCTAssertTrue(store.state.requestsForMe.isEmpty)
    }

    func testAddingClearsTheDraftBeforeTheCallReturns() async {
        let item = TestFixtures.marketItem(id: "new", name: "Rice", requestedBy: "user-1")
        let store = TestStore(initialState: readyState()) {
            MarketFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.marketClient.addItem = { coupleID, _, name, _, isRequest in
                XCTAssertEqual(coupleID, "couple-1")
                XCTAssertEqual(name, "Rice")
                XCTAssertTrue(isRequest)
                return item
            }
        }

        await store.send(.binding(.set(\.draftName, "  Rice  "))) { $0.draftName = "  Rice  " }
        await store.send(.binding(.set(\.draftIsRequest, true))) { $0.draftIsRequest = true }
        await store.send(.addItemTapped) {
            $0.isAddingItem = true
            $0.draftName = ""
            $0.draftIsRequest = false
        }
        await store.receive(\.itemResponse) {
            $0.isAddingItem = false
            $0.board.items = [item]
        }
    }

    func testBlankDraftNeverReachesTheClient() async {
        var state = readyState()
        state.draftName = "   "
        let store = TestStore(initialState: state) { MarketFeature() }

        await store.send(.addItemTapped)
    }

    func testOneRowSettlingLeavesTheOthersTappable() async {
        var state = readyState()
        state.board.items = [
            TestFixtures.marketItem(id: "a", name: "A"),
            TestFixtures.marketItem(id: "b", name: "B"),
        ]
        let gathered = TestFixtures.marketItem(id: "a", name: "A", status: .gathered)
        let store = TestStore(initialState: state) {
            MarketFeature()
        } withDependencies: {
            $0.marketClient.setItemStatus = { _, itemID, status in
                XCTAssertEqual(itemID, "a")
                XCTAssertEqual(status, .gathered)
                return gathered
            }
        }

        await store.send(.itemTapped("a")) { $0.settlingItemIDs = ["a"] }
        // The second row is untouched while the first is in flight.
        XCTAssertFalse(store.state.settlingItemIDs.contains("b"))
        await store.receive(\.itemResponse) {
            $0.settlingItemIDs = []
            $0.board.items = [
                TestFixtures.marketItem(id: "b", name: "B"),
                gathered,
            ]
        }
    }

    func testARemovalThatFailsKeepsTheItem() async {
        var state = readyState()
        state.board.items = [TestFixtures.marketItem(id: "a", name: "A")]
        let store = TestStore(initialState: state) {
            MarketFeature()
        } withDependencies: {
            $0.marketClient.removeItem = { _, _ in throw MarketClientError.networkUnavailable }
        }

        await store.send(.removeItemTapped("a")) { $0.settlingItemIDs = ["a"] }
        await store.receive(\.removeResponse) {
            $0.settlingItemIDs = []
            $0.errorMessage = MarketClientError.networkUnavailable.message
        }
        XCTAssertEqual(store.state.items.map(\.id), ["a"])
    }

    func testTheRunButtonStartsAndThenEndsTheSameRun() async {
        let mine = TestFixtures.marketRun(id: "run-9", shopperID: "user-1")
        let finished = TestFixtures.marketRun(
            id: "run-9",
            shopperID: "user-1",
            endedAt: Date(timeIntervalSince1970: 1_700_000_900)
        )
        let store = TestStore(initialState: readyState()) {
            MarketFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.marketClient.startRun = { _, _ in mine }
            $0.marketClient.finishRun = { _, runID in
                XCTAssertEqual(runID, "run-9")
                return finished
            }
        }

        await store.send(.runButtonTapped) { $0.isChangingRun = true }
        await store.receive(\.runResponse) {
            $0.isChangingRun = false
            $0.board.run = mine
        }
        XCTAssertNotNil(store.state.myRun)

        await store.send(.runButtonTapped) { $0.isChangingRun = true }
        await store.receive(\.runResponse) {
            $0.isChangingRun = false
            // A finished run leaves the board rather than lingering as inactive.
            $0.board.run = nil
        }
    }

    func testClearingTheBasketEmptiesOnlyWhatWasGathered() async {
        var state = readyState()
        state.board.items = [
            TestFixtures.marketItem(id: "a", name: "A"),
            TestFixtures.marketItem(id: "b", name: "B", status: .gathered),
        ]
        let cleared = LockIsolated(false)
        let store = TestStore(initialState: state) {
            MarketFeature()
        } withDependencies: {
            $0.marketClient.clearGathered = { coupleID in
                XCTAssertEqual(coupleID, "couple-1")
                cleared.setValue(true)
            }
        }

        XCTAssertTrue(store.state.canClearBasket)
        await store.send(.clearBasketTapped) { $0.isClearingBasket = true }
        await store.receive(\.clearBasketResponse) {
            $0.isClearingBasket = false
            $0.board.items = [TestFixtures.marketItem(id: "a", name: "A")]
        }
        XCTAssertTrue(cleared.value)
    }

    func testTheBasketCannotBeClearedWhileSomeoneIsShopping() async {
        var state = readyState()
        state.board.items = [TestFixtures.marketItem(id: "b", status: .gathered)]
        state.board.run = TestFixtures.marketRun(shopperID: "user-1")

        // Finishing the run is what empties it; a second way to do the same
        // thing would only be a way to do it at the wrong moment.
        XCTAssertFalse(state.canClearBasket)
    }

    func testAFailedClearKeepsTheBasket() async {
        var state = readyState()
        state.board.items = [TestFixtures.marketItem(id: "b", status: .gathered)]
        let store = TestStore(initialState: state) {
            MarketFeature()
        } withDependencies: {
            $0.marketClient.clearGathered = { _ in throw MarketClientError.networkUnavailable }
        }

        await store.send(.clearBasketTapped) { $0.isClearingBasket = true }
        await store.receive(\.clearBasketResponse) {
            $0.isClearingBasket = false
            $0.errorMessage = MarketClientError.networkUnavailable.message
        }
        XCTAssertEqual(store.state.gathered.map(\.id), ["b"])
    }

    func testAnotherCouplesBoardCannotLand() async {
        var state = readyState()
        state.observationID = observationID
        let store = TestStore(initialState: state) { MarketFeature() }

        await store.send(.observationEvent(.init(
            id: observationID,
            coupleID: "another-couple",
            result: .success(MarketBoard(items: [TestFixtures.marketItem(id: "x")], run: nil))
        )))
    }

    func testStopClearsStateAndCancelsTheListener() async {
        let terminated = LockIsolated(false)
        let store = TestStore(initialState: MarketFeature.State()) {
            MarketFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.marketClient.observe = { _ in
                AsyncThrowingStream { continuation in
                    continuation.onTermination = { _ in terminated.setValue(true) }
                }
            }
        }

        await open(store)
        await store.send(.stop) { $0 = MarketFeature.State() }
        await store.finish()
        XCTAssertTrue(terminated.value)
    }

    // MARK: - Helpers

    private func makeStore(board: MarketBoard) -> TestStoreOf<MarketFeature> {
        TestStore(initialState: MarketFeature.State()) {
            MarketFeature()
        } withDependencies: {
            $0.uuid = .constant(self.observationID)
            $0.marketClient.observe = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(board)
                    continuation.finish()
                }
            }
        }
    }

    private func open(_ store: TestStoreOf<MarketFeature>) async {
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

    private func readyState() -> MarketFeature.State {
        var state = MarketFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.observationID = observationID
        return state
    }
}
