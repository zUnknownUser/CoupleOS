import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct OnboardingFeature {
    @Reducer
    nonisolated enum Destination {
        case profileRecovery(ProfileRecoveryFeature)
        case readyForPartner(ReadyForPartnerFeature)
        case inviteAcceptance(InviteAcceptanceFeature)
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
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case profileReady(User)
            case inviteAccepted(Couple)
            case partnerJoined(Couple)
            case signedOut
        }
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.destination, action: \.destination) {
            Destination.body
        }

        Reduce { state, action in
            switch action {
            case let .destination(.profileRecovery(.delegate(.profileCreated(user)))):
                return .send(.delegate(.profileReady(user)))

            case let .destination(.inviteAcceptance(.delegate(.accepted(couple)))):
                return .send(.delegate(.inviteAccepted(couple)))

            case let .destination(.readyForPartner(.delegate(.partnerJoined(couple)))):
                return .send(.delegate(.partnerJoined(couple)))

            case .destination(.readyForPartner(.delegate(.signedOut))):
                return .send(.delegate(.signedOut))

            case .destination, .delegate:
                return .none
            }
        }
    }
}

extension OnboardingFeature.Destination.State: Equatable {}

@Reducer
nonisolated struct ProfileRecoveryFeature {
    @ObservableState
    struct State: Equatable {
        let authenticatedUser: AuthenticatedUser
        let existingUser: User?
        var firstName: String
        var nameError: FieldValidation?
        var error: UserClientError?
        var isLoading = false

        init(authenticatedUser: AuthenticatedUser, existingUser: User? = nil) {
            self.authenticatedUser = authenticatedUser
            self.existingUser = existingUser
            self.firstName = existingUser?.firstName ?? authenticatedUser.displayName ?? ""
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case continueTapped
        case saveResponse(Result<User, UserClientError>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case profileCreated(User)
        }
    }

    @Dependency(\.userClient) var userClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.firstName):
                state.nameError = nil
                state.error = nil
                return .none
            case .binding, .delegate:
                return .none
            case .continueTapped:
                guard !state.isLoading else { return .none }
                let name = state.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    state.nameError = .missingName
                    return .none
                }
                state.isLoading = true
                state.error = nil
                let authenticatedUser = state.authenticatedUser
                let existingUser = state.existingUser
                return .run { send in
                    do {
                        let user: User
                        if existingUser == nil {
                            user = try await userClient.createUser(CreateUserRequest(
                                id: authenticatedUser.id,
                                firstName: name,
                                onboardingStatus: .readyForPartner
                            ))
                        } else {
                            user = try await userClient.updateUser(UpdateUserRequest(
                                id: authenticatedUser.id,
                                firstName: name,
                                onboardingStatus: .readyForPartner
                            ))
                        }
                        await send(.saveResponse(.success(user)))
                    } catch let error as UserClientError {
                        await send(.saveResponse(.failure(error)))
                    } catch {
                        await send(.saveResponse(.failure(.unknown)))
                    }
                }
            case let .saveResponse(.success(user)):
                state.isLoading = false
                return .send(.delegate(.profileCreated(user)))
            case let .saveResponse(.failure(error)):
                state.isLoading = false
                state.error = error
                return .none
            }
        }
    }
}
