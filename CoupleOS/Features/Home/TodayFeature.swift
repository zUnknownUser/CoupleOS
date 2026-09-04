import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct TodayFeature {
    @ObservableState
    struct State: Equatable {
        let coupleID: String
        let currentUserID: String
        var experience: DailyExperience
        var selectedOption: Int?
        var isSubmitting = false
        var errorMessage: String?

        var status: DailyExperience.Status { experience.status(for: currentUserID) }

        init(coupleID: String, currentUserID: String, experience: DailyExperience) {
            self.coupleID = coupleID
            self.currentUserID = currentUserID
            self.experience = experience
        }
    }

    enum Action: Equatable {
        case optionTapped(Int)
        case submitTapped
        case response(Result<DailyExperience, DailyExperienceError>)
        case experienceUpdated(DailyExperience)
        case dismissTapped
    }

    @Dependency(\.dailyExperienceClient) var dailyClient
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .optionTapped(index):
                guard state.experience.canAnswer(as: state.currentUserID),
                      state.experience.options.indices.contains(index) else { return .none }
                state.selectedOption = index
                state.errorMessage = nil
                return .none
            case .submitTapped:
                guard let option = state.selectedOption, !state.isSubmitting else { return .none }
                state.isSubmitting = true
                state.errorMessage = nil
                return .run { [coupleID = state.coupleID, experienceID = state.experience.id] send in
                    do { await send(.response(.success(try await dailyClient.submitAnswer(coupleID, experienceID, option)))) }
                    catch is CancellationError { return }
                    catch let error as DailyExperienceError { await send(.response(.failure(error))) }
                    catch { await send(.response(.failure(.unknown))) }
                }
                .cancellable(id: CancelID.submit, cancelInFlight: true)
            case let .response(.success(experience)):
                let completedNow = !state.experience.isRevealed && experience.isRevealed
                state.isSubmitting = false
                state.experience = experience
                state.selectedOption = nil
                return completedNow ? dismissEffect() : .none
            case let .response(.failure(error)):
                state.isSubmitting = false
                state.errorMessage = error.message
                return .none
            case let .experienceUpdated(experience):
                let completedNow = !state.experience.isRevealed && experience.isRevealed
                state.experience = experience
                return completedNow ? dismissEffect() : .none
            case .dismissTapped:
                return dismissEffect()
            }
        }
    }

    private enum CancelID { case submit }

    private func dismissEffect() -> Effect<Action> {
        .run { _ in await dismiss() }
    }
}
