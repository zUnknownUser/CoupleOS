import Foundation

/// Something the home needs done, and whose turn it is.
///
/// The turn is the whole point. A shared checklist without one produces the
/// argument it was meant to prevent — both people see the same list and each
/// assumes the other will get to it. Naming an owner makes the division a fact
/// rather than a negotiation.
nonisolated struct Chore: Equatable, Identifiable, Sendable {
    let id: String
    let coupleID: String
    let title: String
    let cadence: Cadence
    let rotation: Rotation
    /// Whose turn it is. `nil` only when the chore belongs to whoever gets there.
    let ownerID: String?
    let status: Status
    let dueAt: Date
    let lastDoneBy: String?
    let lastDoneAt: Date?
    let createdBy: String
    let createdAt: Date

    /// How often the home needs this again.
    nonisolated enum Cadence: Equatable, Sendable {
        /// A one-off. Doing it finishes it, and it leaves the list the way a
        /// bought item leaves the basket.
        case once
        case everyDays(Int)

        var days: Int? {
            guard case let .everyDays(days) = self else { return nil }
            return days
        }
    }

    /// How the turn moves.
    nonisolated enum Rotation: String, Equatable, Sendable, CaseIterable {
        /// The turn passes to the other person on every completion. This is the
        /// fairness mechanism: it divides the work without anyone keeping score,
        /// which is the version of fairness a couple can live with.
        case alternates
        /// Always the same person — someone genuinely owns this one.
        case fixed
        /// Whoever gets there first.
        case anyone
    }

    nonisolated enum Status: String, Equatable, Sendable {
        case active
        case done
    }

    /// Where this chore stands relative to now.
    nonisolated enum Standing: Equatable, Sendable {
        case overdue(days: Int)
        case dueToday
        case upcoming(days: Int)
        case settled
    }

    static let dayLength: TimeInterval = 24 * 60 * 60

    func standing(asOf now: Date) -> Standing {
        guard status == .active else { return .settled }
        let days = Int((dueAt.timeIntervalSince(now) / Self.dayLength).rounded(.down))
        if days < 0 { return .overdue(days: -days) }
        return days == 0 ? .dueToday : .upcoming(days: days)
    }

    /// Whether this is the caller's to do. A chore nobody owns is everybody's.
    func isMine(_ userID: String) -> Bool {
        rotation == .anyone || ownerID == userID
    }

    func isWaitingOnPartner(_ userID: String) -> Bool {
        rotation != .anyone && ownerID != nil && ownerID != userID
    }

    /// Needs doing now — today or already late — and it is yours.
    func needsMe(_ userID: String, asOf now: Date) -> Bool {
        guard isMine(userID) else { return false }
        switch standing(asOf: now) {
        case .overdue, .dueToday: return true
        case .upcoming, .settled: return false
        }
    }

    /// Just done, and still worth mentioning.
    func isFresh(asOf now: Date) -> Bool {
        guard let lastDoneAt else { return false }
        return now.timeIntervalSince(lastDoneAt) < CoupleTiming.freshWindow
    }
}

/// The intent to add a chore, before the backend decides its first due date
/// and settles whose turn it is.
nonisolated struct ChoreDraft: Equatable, Sendable {
    let title: String
    let cadence: Chore.Cadence
    let rotation: Chore.Rotation
    /// Who takes the first turn. Ignored when the rotation is `.anyone`.
    let firstOwnerID: String?

    var isValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { return false }
        guard let days = cadence.days else { return true }
        return days >= 1 && days <= 365
    }
}

nonisolated enum ChoreClientError: Error, Equatable, Sendable {
    case invalidInput
    case notFound
    case notYourTurn
    case alreadyDone
    case listFull
    case networkUnavailable
    case permissionDenied
    case unavailable
    case invalidData
    case unknown

    var message: String {
        switch self {
        case .invalidInput:
            "Check the chore and how often it comes around."
        case .notFound:
            "This chore is no longer on your list."
        case .notYourTurn:
            "This one is your person's turn."
        case .alreadyDone:
            "This one is already taken care of."
        case .listFull:
            "Your list is full. Finish or remove a few first."
        case .networkUnavailable:
            "You're offline. Try again when your connection returns."
        case .permissionDenied, .unavailable, .invalidData, .unknown:
            // Deliberately does not name a cause it cannot know.
            "We couldn't open your chores. If this keeps happening, sign out and back in."
        }
    }
}
