import Foundation

/// Something one of them needs the other to bring home.
nonisolated struct MarketItem: Equatable, Identifiable, Sendable {
    let id: String
    let coupleID: String
    let name: String
    let note: String?
    /// A direct ask — "bring *this*" — rather than something the house needs
    /// eventually. The difference is the whole point of the module: a standing
    /// list is easy to ignore, a request from your person is not.
    let isRequest: Bool
    let requestedBy: String
    let requestedAt: Date
    let status: Status
    let gatheredBy: String?
    let gatheredAt: Date?

    nonisolated enum Status: String, Equatable, Sendable {
        case pending
        case gathered
    }

    var isPending: Bool { status == .pending }

    /// Still pending long after it was asked for. Shown quietly rather than
    /// removed, and kept out of anything that counts.
    func isStale(asOf now: Date) -> Bool {
        isPending && now.timeIntervalSince(requestedAt) > CoupleTiming.staleWindow
    }

    /// Whole days this has been waiting. Used to tell someone how long, which
    /// is the one fact that makes "do you still want this?" answerable.
    func daysWaiting(asOf now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(requestedAt) / (24 * 60 * 60)))
    }

    /// A request only counts as *for you* while it is still open and it was the
    /// other person who asked.
    func isRequest(for userID: String) -> Bool {
        isRequest && isPending && requestedBy != userID
    }
}

/// A trip to the store, while it is happening.
///
/// This is the module's reason to exist. A shared list solves nothing on its
/// own — both people still have to remember to open it. A run is the moment
/// the app can speak up while it still changes the outcome.
nonisolated struct MarketRun: Equatable, Identifiable, Sendable {
    let id: String
    let coupleID: String
    let shopperID: String
    let startedAt: Date
    let endedAt: Date?

    var isActive: Bool { endedAt == nil }

    func isMine(_ userID: String) -> Bool { shopperID == userID }
}

/// The Market as one value: what the house needs, and whether anyone is out
/// getting it. Stored apart because the two change on different rhythms —
/// items move all day, a run flips twice — but they are read as one thing.
nonisolated struct MarketBoard: Equatable, Sendable {
    var items: [MarketItem] = []
    var run: MarketRun?
}

nonisolated enum MarketClientError: Error, Equatable, Sendable, CaseIterable {
    case invalidInput
    case itemNotFound
    case runNotFound
    case notShopper
    case runAlreadyFinished
    case listFull
    case networkUnavailable
    case permissionDenied
    case unavailable
    case invalidData
    case unknown
}
