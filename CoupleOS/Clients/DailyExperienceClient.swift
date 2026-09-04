import ComposableArchitecture
import Foundation

@DependencyClient
nonisolated struct DailyExperienceClient: Sendable {
    var getToday: @Sendable (_ coupleID: String) async throws -> DailyExperience
    var submitAnswer: @Sendable (_ coupleID: String, _ experienceID: String, _ optionIndex: Int) async throws -> DailyExperience
    var observeToday: @Sendable (_ coupleID: String, _ experienceID: String) -> AsyncThrowingStream<DailyExperience, any Error> = { _, _ in
        AsyncThrowingStream { $0.finish() }
    }
}

extension DailyExperienceClient: DependencyKey {
    static let liveValue = DailyExperienceClient.firebase
    static let testValue = DailyExperienceClient(
        getToday: { _ in
            DailyExperience(
                id: "test-day",
                periodKey: "test-day",
                prompt: "What would feel most like us today?",
                options: ["Stay in", "Go somewhere new"],
                answeredUserIDs: [],
                revealedAnswers: nil
            )
        },
        submitAnswer: { _, _, _ in throw DailyExperienceError.unknown },
        observeToday: { _, _ in AsyncThrowingStream { $0.finish() } }
    )
}

extension DependencyValues {
    nonisolated var dailyExperienceClient: DailyExperienceClient {
        get { self[DailyExperienceClient.self] }
        set { self[DailyExperienceClient.self] = newValue }
    }
}
