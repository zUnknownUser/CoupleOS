import Foundation

nonisolated struct DailyExperience: Equatable, Sendable {
    let id: String
    let periodKey: String
    let prompt: String
    let options: [String]
    let answeredUserIDs: Set<String>
    let revealedAnswers: [String: Int]?

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

nonisolated enum DailyExperienceError: Error, Equatable, Sendable {
    case notFound
    case alreadyAnswered
    case notAMember
    case unavailable
    case networkUnavailable
    case permissionDenied
    case invalidData
    case unknown

    var message: String {
        switch self {
        case .notFound: "Today is unavailable right now."
        case .alreadyAnswered: "Your answer is already part of this moment."
        case .notAMember, .permissionDenied: "This moment belongs to your Couple World."
        case .unavailable: "Today is temporarily unavailable."
        case .networkUnavailable: "You're offline. Your answer is safe—try again soon."
        case .invalidData, .unknown: "We couldn't open today's moment. Please try again."
        }
    }
}
