import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct DecisionDetailFeature {
    @ObservableState
    struct State: Equatable {
        var decision: Decision?
        let currentUserID: String
        var selectedOptionIndex: Int?
        var isResolving = false
        var error: DecisionClientError?

        init(decision: Decision, currentUserID: String) {
            self.decision = decision
            self.currentUserID = currentUserID
        }

        var presentation: Presentation {
            guard let decision else { return .unavailable }
            if isResolving { return .resolving }
            switch decision.participation(for: currentUserID) {
            case .needsMyResponse: return .needsMyResponse
            case .waitingForPartner: return .waitingForPartner
            case .resolved: return .resolved
            case .unavailable: return .unavailable
            }
        }
    }

    enum Presentation: Equatable {
        case needsMyResponse
        case waitingForPartner
        case resolving
        case resolved
        case unavailable
    }

    enum Action: Equatable {
        case optionTapped(Int)
        case resolveTapped
        case response(Result<Decision, DecisionClientError>)
        case decisionUpdated(Decision?)
        case dismissTapped
    }

    @Dependency(\.decisionClient) var decisionClient
    @Dependency(\.dismiss) var dismiss

    private enum CancelID {
        case resolve
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .optionTapped(index):
                guard !state.isResolving,
                      state.presentation == .needsMyResponse,
                      let decision = state.decision,
                      decision.options.indices.contains(index) else { return .none }
                state.selectedOptionIndex = index
                state.error = nil
                return .none

            case .resolveTapped:
                guard !state.isResolving,
                      state.presentation == .needsMyResponse,
                      let decision = state.decision,
                      let optionIndex = state.selectedOptionIndex else { return .none }
                state.isResolving = true
                state.error = nil
                return resolve(decision: decision, optionIndex: optionIndex)

            case let .response(.success(decision)):
                state.decision = decision
                state.isResolving = false
                state.selectedOptionIndex = nil
                return .none

            case let .response(.failure(error)):
                state.isResolving = false
                state.error = error
                return .none

            case let .decisionUpdated(decision):
                guard decision?.coupleID == state.decision?.coupleID else {
                    state.decision = nil
                    state.isResolving = false
                    state.selectedOptionIndex = nil
                    return .cancel(id: CancelID.resolve)
                }
                state.decision = decision
                if decision?.status == .resolved {
                    state.isResolving = false
                    state.selectedOptionIndex = nil
                }
                return .none

            case .dismissTapped:
                return .run { _ in await dismiss() }
            }
        }
    }

    private func resolve(decision: Decision, optionIndex: Int) -> Effect<Action> {
        .run { send in
            do {
                await send(.response(.success(try await decisionClient.resolve(
                    decision.coupleID,
                    decision.id,
                    optionIndex
                ))))
            } catch is CancellationError {
                return
            } catch let error as DecisionClientError {
                await send(.response(.failure(error)))
            } catch {
                await send(.response(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.resolve, cancelInFlight: true)
    }
}
