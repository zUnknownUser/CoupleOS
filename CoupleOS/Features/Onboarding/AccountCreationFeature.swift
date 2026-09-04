import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct AccountCreationFeature {
    @Reducer
    nonisolated enum Destination {
        case identity(IdentityFeature)
        case signUp(SignUpFeature)
    }

    @ObservableState
    struct State: Equatable {
        var destination: Destination.State

        init(destination: Destination.State) {
            self.destination = destination
        }
    }

    enum Action {
        case destination(Destination.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.destination, action: \.destination) {
            Destination.body
        }

        Reduce { state, action in
            switch action {
            case let .destination(.identity(.delegate(.continueWithName(firstName)))):
                state.destination = .signUp(SignUpFeature.State(firstName: firstName))
                return .none

            case let .destination(.signUp(.delegate(.back(firstName)))):
                state.destination = .identity(IdentityFeature.State(firstName: firstName))
                return .none

            case .destination:
                return .none
            }
        }
    }
}

extension AccountCreationFeature.Destination.State: Equatable {}

@Reducer
nonisolated struct IdentityFeature {
    @ObservableState
    struct State: Equatable {
        var firstName = ""
        var nameError: String?

        init(firstName: String = "") {
            self.firstName = firstName
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case backTapped
        case continueTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case back
            case continueWithName(String)
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.firstName):
                state.nameError = nil
                return .none
            case .binding, .delegate:
                return .none
            case .backTapped:
                return .send(.delegate(.back))
            case .continueTapped:
                let name = state.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    state.nameError = "Tell us what we should call you."
                    return .none
                }
                return .send(.delegate(.continueWithName(name)))
            }
        }
    }
}
