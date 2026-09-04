import Foundation

/// A question the app itself asks, identified rather than quoted.
///
/// The daily moment is written by the backend, once per couple per day, and
/// stored as one shared document. Two people can be reading in two languages,
/// so the *text* cannot be what is stored — the identity of the question is,
/// and each phone says it in its own words.
nonisolated enum DailyPrompt: String, Equatable, Hashable, Sendable, CaseIterable {
    case everyday
}

nonisolated struct DailyExperience: Equatable, Sendable {
    let id: String
    let periodKey: String
    /// The question as the backend wrote it, in English. Kept as the fallback
    /// for a prompt this build does not recognise — a new question shipped by
    /// the server should read as itself rather than as nothing.
    let prompt: String
    let options: [String]
    let answeredUserIDs: Set<String>
    let revealedAnswers: [String: Int]?
    let promptID: DailyPrompt?

    init(
        id: String,
        periodKey: String,
        prompt: String,
        options: [String],
        answeredUserIDs: Set<String>,
        revealedAnswers: [String: Int]?,
        promptID: DailyPrompt? = nil
    ) {
        self.id = id
        self.periodKey = periodKey
        self.prompt = prompt
        self.options = options
        self.answeredUserIDs = answeredUserIDs
        self.revealedAnswers = revealedAnswers
        self.promptID = promptID
    }

    var isRevealed: Bool { revealedAnswers != nil }

    func status(for userID: String) -> Status {
        if isRevealed { return .revealAvailable }
        if answeredUserIDs.contains(userID) { return .waitingForPartner }
        return answeredUserIDs.isEmpty ? .available : .waitingForMe
    }

    func canAnswer(as userID: String) -> Bool {
        switch status(for: userID) {
        case .available, .waitingForMe: true
        case .waitingForPartner, .revealAvailable: false
        }
    }

    enum Status: Equatable, Sendable {
        case available
        case waitingForPartner
        case waitingForMe
        case revealAvailable
    }
}

nonisolated enum DailyExperienceError: Error, Equatable, Sendable, CaseIterable {
    case notFound
    case alreadyAnswered
    case notAMember
    case unavailable
    case networkUnavailable
    case permissionDenied
    case invalidData
    case unknown
}
