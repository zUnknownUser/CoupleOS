import XCTest
@testable import CoupleOS

/// The Home's contract with every area, present and future: contribute signals
/// and a summary, and the surface does the rest.
final class HomeCompositionTests: XCTestCase {
    func testUrgencyOrdersTheHomeAcrossModules() {
        let composition = HomeComposition([
            ModuleContribution(
                signals: [signal(id: "settled", module: .decisions, urgency: .settled)],
                summary: summary(.decisions)
            ),
            ModuleContribution(
                signals: [
                    signal(id: "waiting", module: .today, urgency: .waiting),
                    signal(id: "needsYou", module: .today, urgency: .needsYou),
                ],
                summary: summary(.today)
            ),
            ModuleContribution(
                signals: [signal(id: "live", module: .market, urgency: .live)],
                summary: summary(.market)
            ),
        ])

        // Loudest first, regardless of which area contributed it or in what order.
        XCTAssertEqual(
            composition.signals.map(\.id),
            ["live", "needsYou", "waiting", "settled"]
        )
        XCTAssertEqual(composition.leading?.id, "live")
        XCTAssertEqual(composition.attention, 2)
        XCTAssertFalse(composition.isQuiet)
    }

    func testEveryAreaSurvivesEvenWithNothingToSay() {
        let composition = HomeComposition([
            ModuleContribution(summary: summary(.market)),
            ModuleContribution(summary: summary(.decisions)),
            ModuleContribution(summary: summary(.today)),
        ])

        XCTAssertTrue(composition.isQuiet)
        XCTAssertEqual(composition.areas.map(\.module), [.market, .decisions, .today])
    }

    func testSameUrgencyBreaksTiesByRecency() {
        let older = signal(id: "older", module: .decisions, urgency: .needsYou, at: 100)
        let newer = signal(id: "newer", module: .decisions, urgency: .needsYou, at: 900)
        let composition = HomeComposition([
            ModuleContribution(signals: [older, newer], summary: summary(.decisions))
        ])

        XCTAssertEqual(composition.signals.map(\.id), ["newer", "older"])
    }

    func testASignalCanSpeakForTheWorldInItsOwnVoice() {
        var own = signal(id: "live", module: .market, urgency: .live)
        own.worldCaption = "Alex is out in the world."
        let borrowed = signal(id: "plain", module: .decisions, urgency: .needsYou)

        XCTAssertEqual(
            own.worldCaption ?? own.urgency.worldCaption,
            "Alex is out in the world."
        )
        XCTAssertEqual(
            borrowed.worldCaption ?? borrowed.urgency.worldCaption,
            HomeSignal.Urgency.needsYou.worldCaption
        )
        XCTAssertEqual(HomeSignal.Urgency.live.worldActivity, .live)
    }

    // MARK: - What each module says

    func testAPartnerAtTheMarketIsTheLoudestThingTheHomeCanSay() {
        var state = MarketFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.board = MarketBoard(
            items: [TestFixtures.marketItem(id: "a", name: "Milk")],
            run: TestFixtures.marketRun(shopperID: "user-2")
        )

        let contribution = state.homeContribution(partnerName: "Sam")
        let live = contribution.signals.first

        XCTAssertEqual(live?.urgency, .live)
        XCTAssertEqual(live?.title, "Sam is at the market")
        XCTAssertEqual(live?.target, .market)
        XCTAssertNotNil(live?.worldCaption)
        XCTAssertTrue(contribution.summary.isLive)
        XCTAssertEqual(contribution.summary.status, "Sam is there now")
    }

    func testShoppingYourselfFoldsTheAsksIntoTheRunCard() {
        var state = MarketFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.board = MarketBoard(
            items: [TestFixtures.marketItem(id: "a", name: "Milk", isRequest: true)],
            run: TestFixtures.marketRun(shopperID: "user-1")
        )

        let signals = state.homeContribution(partnerName: "Sam").signals

        // One card, not two: you are already holding the basket.
        XCTAssertEqual(signals.count, 1)
        XCTAssertEqual(signals.first?.title, "You're at the market")
        XCTAssertEqual(signals.first?.detail, "1 still to gather")
    }

    func testAnAskWithNobodyShoppingStillReachesYou() {
        var state = MarketFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.board = MarketBoard(
            items: [TestFixtures.marketItem(id: "a", name: "Batteries", isRequest: true)],
            run: nil
        )

        // Pinned to just after the ask: with a live clock this fixture would
        // age past the stale window and the assertion would rot.
        let contribution = state.homeContribution(
            partnerName: "Sam",
            now: Date(timeIntervalSince1970: 1_700_000_200)
        )

        XCTAssertEqual(contribution.signals.first?.urgency, .needsYou)
        XCTAssertEqual(contribution.signals.first?.title, "Batteries")
        XCTAssertEqual(contribution.summary.attention, 1)
        XCTAssertFalse(contribution.summary.isLive)
    }

    func testDecisionsKeepTheirOwnWordsButCollapseWhileWaiting() {
        var state = DecisionsFeature.State()
        state.currentUserID = "user-1"
        state.coupleID = "couple-1"
        state.phase = .loaded([
            decision(id: "mine", creator: "user-2", responder: "user-1", title: "Where do we eat?"),
            decision(id: "w1", creator: "user-1", responder: "user-2", title: "Film tonight?"),
            decision(id: "w2", creator: "user-1", responder: "user-2", title: "Beach or hills?"),
        ])

        let signals = state.homeContribution(partnerName: "Sam").signals

        XCTAssertEqual(signals.first?.title, "Where do we eat?")
        XCTAssertEqual(signals.first?.target, .decision(id: "mine"))
        // Two unanswerable ones become a single quiet line.
        XCTAssertEqual(signals.filter { $0.urgency == .waiting }.count, 1)
        XCTAssertEqual(
            signals.first(where: { $0.urgency == .waiting })?.title,
            "2 decisions with Sam"
        )
    }

    func testAnAreaWithNoPartnerNameStillReadsAsASentence() {
        var state = MarketFeature.State()
        state.phase = .ready
        state.currentUserID = "user-1"
        state.coupleID = "couple-1"
        state.board = MarketBoard(items: [], run: TestFixtures.marketRun(shopperID: "user-2"))

        let contribution = state.homeContribution(partnerName: nil)

        XCTAssertEqual(contribution.signals.first?.title, "Your person is at the market")
        XCTAssertEqual(contribution.summary.status, "Your person is there now")
    }

    func testAnAskNobodyActedOnForWeeksStopsShouting() {
        let asked = Date(timeIntervalSince1970: 1_700_000_000)
        var state = MarketFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.board = MarketBoard(
            items: [TestFixtures.marketItem(
                id: "old",
                name: "Batteries",
                isRequest: true,
                requestedAt: asked
            )],
            run: nil
        )

        let fresh = state.homeContribution(partnerName: "Sam", now: asked.addingTimeInterval(60))
        XCTAssertEqual(fresh.signals.first?.urgency, .needsYou)
        XCTAssertEqual(fresh.summary.attention, 1)
        XCTAssertEqual(fresh.summary.status, "1 to bring")

        // Fifteen days later the item is still on the list, but it has stopped
        // competing with things that are actually current.
        let later = asked.addingTimeInterval(15 * 24 * 60 * 60)
        let stale = state.homeContribution(partnerName: "Sam", now: later)
        XCTAssertTrue(stale.signals.isEmpty)
        XCTAssertEqual(stale.summary.attention, 0)
        XCTAssertEqual(stale.summary.status, "Nothing current")
        XCTAssertEqual(state.items.count, 1, "A stale item is quieted, never dropped")
    }

    func testAStaleItemIsStillCountedAsWaiting() {
        let asked = Date(timeIntervalSince1970: 1_700_000_000)
        let item = TestFixtures.marketItem(id: "old", isRequest: true, requestedAt: asked)

        XCTAssertFalse(item.isStale(asOf: asked.addingTimeInterval(13 * 24 * 60 * 60)))
        XCTAssertTrue(item.isStale(asOf: asked.addingTimeInterval(15 * 24 * 60 * 60)))
        XCTAssertEqual(item.daysWaiting(asOf: asked.addingTimeInterval(15 * 24 * 60 * 60)), 15)
    }

    // MARK: - What the house says

    func testALateChoreOfYoursSpeaksForTheWorld() {
        let now = Date(timeIntervalSince1970: 1_700_500_000)
        var state = ChoresFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.chores = [TestFixtures.chore(
            id: "dishes",
            title: "Dishes",
            ownerID: "user-1",
            dueAt: now.addingTimeInterval(-3 * 24 * 60 * 60)
        )]

        let contribution = state.homeContribution(partnerName: "Sam", now: now)
        let signal = contribution.signals.first

        XCTAssertEqual(signal?.urgency, .needsYou)
        XCTAssertEqual(signal?.title, "Dishes")
        XCTAssertEqual(signal?.detail, "Late")
        XCTAssertEqual(signal?.target, .chores)
        XCTAssertEqual(signal?.worldCaption, "The house is waiting on you.")
        XCTAssertEqual(contribution.summary.status, "1 for you")
    }

    func testAChoreDueNextWeekStaysOffTheHome() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = ChoresFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.chores = [TestFixtures.chore(
            id: "windows",
            ownerID: "user-1",
            dueAt: now.addingTimeInterval(7 * 24 * 60 * 60)
        )]

        let contribution = state.homeContribution(partnerName: "Sam", now: now)

        // Real, but not now. A Home that always has something on it is a Home
        // nobody reads.
        XCTAssertTrue(contribution.signals.isEmpty)
        XCTAssertEqual(contribution.summary.status, "All caught up")
        XCTAssertEqual(contribution.summary.attention, 0)
    }

    func testYourPersonsTurnIsShownButNotAsSomethingToDo() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = ChoresFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.chores = [TestFixtures.chore(id: "bins", title: "Bins", ownerID: "user-2", dueAt: now)]

        let contribution = state.homeContribution(partnerName: "Sam", now: now)

        XCTAssertEqual(contribution.signals.first?.urgency, .waiting)
        XCTAssertEqual(contribution.signals.first?.detail, "Sam's turn")
        // Nothing here is yours to act on, so nothing here counts against you.
        XCTAssertEqual(contribution.summary.attention, 0)
        XCTAssertEqual(contribution.summary.status, "1 with Sam")
    }

    func testWhatYourPersonJustDidIsWorthSaying() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = ChoresFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.chores = [TestFixtures.chore(
            id: "dishes",
            title: "Dishes",
            ownerID: "user-1",
            dueAt: now.addingTimeInterval(2 * 24 * 60 * 60),
            lastDoneBy: "user-2",
            lastDoneAt: now.addingTimeInterval(-600)
        )]

        let settled = state.homeContribution(partnerName: "Sam", now: now)
            .signals.first { $0.urgency == .settled }

        XCTAssertEqual(settled?.title, "Dishes")
        XCTAssertEqual(settled?.detail, "Sam took care of this")
    }

    func testYourOwnCompletionIsNotAnnouncedBackToYou() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = ChoresFeature.State()
        state.phase = .ready
        state.coupleID = "couple-1"
        state.currentUserID = "user-1"
        state.partnerID = "user-2"
        state.chores = [TestFixtures.chore(
            id: "dishes",
            ownerID: "user-2",
            dueAt: now.addingTimeInterval(2 * 24 * 60 * 60),
            lastDoneBy: "user-1",
            lastDoneAt: now.addingTimeInterval(-600)
        )]

        let signals = state.homeContribution(partnerName: "Sam", now: now).signals
        XCTAssertFalse(signals.contains { $0.urgency == .settled })
    }

    func testTheHouseTakesItsPlaceInTheOrderLikeAnyOtherArea() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var chores = ChoresFeature.State()
        chores.phase = .ready
        chores.coupleID = "couple-1"
        chores.currentUserID = "user-1"
        chores.partnerID = "user-2"
        chores.chores = [TestFixtures.chore(id: "dishes", ownerID: "user-1", dueAt: now)]

        var market = MarketFeature.State()
        market.phase = .ready
        market.coupleID = "couple-1"
        market.currentUserID = "user-1"
        market.partnerID = "user-2"
        market.board = MarketBoard(items: [], run: TestFixtures.marketRun(shopperID: "user-2"))

        let composition = HomeComposition([
            market.homeContribution(partnerName: "Sam", now: now),
            chores.homeContribution(partnerName: "Sam", now: now),
        ])

        // Someone standing in a store outranks a chore due today, because only
        // one of the two stops being actionable in ten minutes.
        XCTAssertEqual(composition.signals.map(\.module), [.market, .chores])
        XCTAssertEqual(composition.leading?.urgency, .live)
        XCTAssertEqual(composition.areas.map(\.module), [.market, .chores])
    }

    // MARK: - Helpers

    private func signal(
        id: String,
        module: CoupleModule,
        urgency: HomeSignal.Urgency,
        at seconds: TimeInterval = 0
    ) -> HomeSignal {
        HomeSignal(
            id: id,
            module: module,
            urgency: urgency,
            title: id,
            detail: "",
            symbol: "circle",
            at: Date(timeIntervalSince1970: seconds),
            target: .market,
            worldCaption: nil
        )
    }

    private func summary(_ module: CoupleModule) -> ModuleSummary {
        ModuleSummary(module: module, status: "", target: .market)
    }

    private func decision(
        id: String,
        creator: String,
        responder: String,
        title: String
    ) -> Decision {
        Decision(
            id: id,
            coupleID: "couple-1",
            title: title,
            options: ["A", "B"],
            creatorID: creator,
            responderID: responder,
            status: .waitingForPartner,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            selectedOptionIndex: nil,
            resolvedAt: nil
        )
    }
}
