import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct CreateDecisionFeature {
    @ObservableState
    struct State: Equatable {
        let coupleID: String
        let currentUserID: String
        let partnerID: String
        var title = ""
        var options = ["", ""]
        var requestID: UUID?
        var isSubmitting = false
        var hasAttemptedSubmit = false
        var error: DecisionClientError?

        var normalizedTitle: String {
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var normalizedOptions: [String] {
            options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        /// What is wrong with the draft, as a fact. The words for it belong
        /// to the catalogue, so this stays the same in every language.
        var validation: DecisionValidation? {
            guard hasAttemptedSubmit else { return nil }
            if normalizedTitle.isEmpty { return .missingTitle }
            if normalizedTitle.count > Limits.titleLength {
                return .titleTooLong(maximum: Limits.titleLength)
            }
            if normalizedOptions.contains(where: { $0.isEmpty }) {
                return .emptyChoice
            }
            if normalizedOptions.contains(where: { $0.count > Limits.optionLength }) {
                return .choiceTooLong(maximum: Limits.optionLength)
            }
            let unique = Set(normalizedOptions.map { $0.lowercased() })
            if unique.count != normalizedOptions.count { return .duplicateChoices }
            return nil
        }

        var canSubmit: Bool {
            !normalizedTitle.isEmpty
                && normalizedTitle.count <= Limits.titleLength
                && normalizedOptions.count >= Limits.minimumOptions
                && normalizedOptions.count <= Limits.maximumOptions
                && normalizedOptions.allSatisfy { !$0.isEmpty && $0.count <= Limits.optionLength }
                && Set(normalizedOptions.map { $0.lowercased() }).count == normalizedOptions.count
                && !isSubmitting
        }
    }

    enum Action: Equatable {
        case titleChanged(String)
        case optionChanged(index: Int, value: String)
        case addOptionTapped
        case removeOptionTapped(Int)
        case submitTapped
        case response(Result<Decision, DecisionClientError>)
        case dismissTapped
    }

    @Dependency(\.decisionClient) var decisionClient
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.uuid) var uuid

    private enum CancelID {
        case create
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .titleChanged(value):
                guard !state.isSubmitting else { return .none }
                state.title = value
                resetSubmissionIdentity(state: &state)
                return .none

            case let .optionChanged(index, value):
                guard !state.isSubmitting,
                      state.options.indices.contains(index) else { return .none }
                state.options[index] = value
                resetSubmissionIdentity(state: &state)
                return .none

            case .addOptionTapped:
                guard !state.isSubmitting,
                      state.options.count < Limits.maximumOptions else { return .none }
                state.options.append("")
                resetSubmissionIdentity(state: &state)
                return .none

            case let .removeOptionTapped(index):
                guard !state.isSubmitting,
                      state.options.count > Limits.minimumOptions,
                      state.options.indices.contains(index) else { return .none }
                state.options.remove(at: index)
                resetSubmissionIdentity(state: &state)
                return .none

            case .submitTapped:
                state.hasAttemptedSubmit = true
                guard state.canSubmit else { return .none }
                let requestID = state.requestID ?? uuid()
                state.requestID = requestID
                state.isSubmitting = true
                state.error = nil
                return create(
                    coupleID: state.coupleID,
                    requestID: requestID,
                    title: state.normalizedTitle,
                    options: state.normalizedOptions
                )

            case .response(.success):
                state.isSubmitting = false
                return .run { _ in await dismiss() }

            case let .response(.failure(error)):
                state.isSubmitting = false
                state.error = error
                return .none

            case .dismissTapped:
                return .run { _ in await dismiss() }
            }
        }
    }

    private func resetSubmissionIdentity(state: inout State) {
        state.requestID = nil
        state.hasAttemptedSubmit = false
        state.error = nil
    }

    private func create(
        coupleID: String,
        requestID: UUID,
        title: String,
        options: [String]
    ) -> Effect<Action> {
        .run { send in
            do {
                await send(.response(.success(try await decisionClient.create(
                    coupleID,
                    requestID,
                    title,
                    options
                ))))
            } catch is CancellationError {
                return
            } catch let error as DecisionClientError {
                await send(.response(.failure(error)))
            } catch {
                await send(.response(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.create, cancelInFlight: true)
    }

    enum Limits {
        static let titleLength = 160
        static let optionLength = 80
        static let minimumOptions = 2
        static let maximumOptions = 6
    }
}
