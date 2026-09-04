import Foundation

nonisolated struct Decision: Equatable, Identifiable, Sendable {
    let id: String
    let coupleID: String
    let title: String
    let options: [String]
    let creatorID: String
    let responderID: String
    let status: Status
    let createdAt: Date
    let selectedOptionIndex: Int?
    let resolvedAt: Date?

    enum Status: String, Equatable, Sendable {
        case waitingForPartner
        case resolved
    }

    enum Participation: Equatable, Sendable {
        case waitingForPartner
        case needsMyResponse
        case resolved
        case unavailable
    }

    func participation(for userID: String) -> Participation {
        switch status {
        case .resolved:
            return .resolved
        case .waitingForPartner where creatorID == userID:
            return .waitingForPartner
        case .waitingForPartner where responderID == userID:
            return .needsMyResponse
        case .waitingForPartner:
            return .unavailable
        }
    }

    /// Still warm enough that the couple would want to see it mentioned.
    var isFresh: Bool {
        guard let resolvedAt else { return false }
        return resolvedAt.timeIntervalSinceNow > -CoupleTiming.freshWindow
    }

    var selectedOption: String? {
        guard let selectedOptionIndex,
              options.indices.contains(selectedOptionIndex) else { return nil }
        return options[selectedOptionIndex]
    }
}

nonisolated enum DecisionClientError: Error, Equatable, Sendable {
    case invalidInput
    case notFound
    case notResponder
    case alreadyResolved
    case networkUnavailable
    case permissionDenied
    case unavailable
    case invalidData
    case unknown

    var message: String {
        switch self {
        case .invalidInput:
            "Check the question and its choices."
        case .notFound:
            "This decision is no longer available."
        case .notResponder:
            "This decision is waiting for your person."
        case .alreadyResolved:
            "This decision has already been made."
        case .networkUnavailable:
            "You're offline. Try again when your connection returns."
        case .permissionDenied:
            "This decision belongs to another Couple World."
        case .unavailable:
            "Decisions are temporarily unavailable."
        case .invalidData, .unknown:
            "We couldn't open this decision. Please try again."
        }
    }
}
