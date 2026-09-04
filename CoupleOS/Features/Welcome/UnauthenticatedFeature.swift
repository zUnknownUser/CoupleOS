import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct UnauthenticatedFeature {
    @Reducer
    nonisolated enum Destination {
        case welcome(WelcomeFeature)
        case login(LoginFeature)
        case accountCreation(AccountCreationFeature)
        case invite(InviteFeature)
    }

    @ObservableState
    struct State: Equatable {
        var destination: Destination.State

        init(destination: Destination.State = .welcome(WelcomeFeature.State())) {
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
            case .destination(.welcome(.createWorldTapped)):
                state.destination = .accountCreation(AccountCreationFeature.State(
                    destination: .identity(IdentityFeature.State())
                ))
            case .destination(.welcome(.loginTapped)):
                state.destination = .login(LoginFeature.State())
            case .destination(.welcome(.inviteTapped)):
                state.destination = .invite(InviteFeature.State())
            case .destination(.login(.delegate(.back))), .destination(.invite(.delegate(.back))),
                    .destination(.accountCreation(.destination(.identity(.delegate(.back))))):
                state.destination = .welcome(WelcomeFeature.State())
            case .destination(.invite(.delegate(.createAccount))):
                state.destination = .accountCreation(AccountCreationFeature.State(
                    destination: .identity(IdentityFeature.State())
                ))
            case .destination(.invite(.delegate(.signIn))):
                state.destination = .login(LoginFeature.State())
            case .destination:
                break
            }
            return .none
        }
    }
}

extension UnauthenticatedFeature.Destination.State: Equatable {}

@Reducer
nonisolated struct WelcomeFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case createWorldTapped
        case loginTapped
        case inviteTapped
    }

    var body: some ReducerOf<Self> { EmptyReducer() }
}

@Reducer
nonisolated struct InviteFeature {
    @ObservableState
    struct State: Equatable {
        var inviteCode = ""
        var token: InviteToken?
        var presentation: Presentation = .manualEntry
        var error: InviteClientError?

        enum Presentation: Equatable {
            case manualEntry
            case invitation
            case accountChoice
        }

        init(token: InviteToken? = nil, presentation: Presentation = .manualEntry) {
            self.token = token
            self.presentation = presentation
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case backTapped
        case continueTapped
        case joinTapped
        case createAccountTapped
        case signInTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case back
            case tokenPrepared(InviteToken)
            case createAccount
            case signIn
        }
    }

    @Dependency(\.inviteClient) var inviteClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.inviteCode):
                state.error = nil
                return .none
            case .binding, .delegate:
                return .none
            case .backTapped:
                if state.presentation == .accountChoice {
                    state.presentation = state.token == nil ? .manualEntry : .invitation
                    return .none
                }
                return .send(.delegate(.back))
            case .continueTapped:
                let input = state.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                let token: InviteToken?
                if let url = URL(string: input), url.scheme != nil {
                    token = try? inviteClient.parseInviteURL(url)
                } else {
                    token = InviteToken(rawValue: input)
                }
                guard let token else {
                    state.error = .inviteInvalid
                    return .none
                }
                state.token = token
                state.presentation = .accountChoice
                return .send(.delegate(.tokenPrepared(token)))
            case .joinTapped:
                guard let token = state.token else { return .none }
                state.presentation = .accountChoice
                return .send(.delegate(.tokenPrepared(token)))
            case .createAccountTapped:
                return .send(.delegate(.createAccount))
            case .signInTapped:
                return .send(.delegate(.signIn))
            }
        }
    }
}
