import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct SignUpFeature {
    @ObservableState
    struct State: Equatable {
        let firstName: String
        var email = ""
        var password = ""
        var isPasswordVisible = false
        var isLoading = false
        var emailError: String?
        var passwordError: String?
        var errorMessage: String?

        init(firstName: String) {
            self.firstName = firstName
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case backTapped
        case createAccountTapped
        case passwordVisibilityTapped
        case authenticationResponse(Result<AuthenticatedUser, AuthenticationError>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case back(firstName: String)
            case authenticated(AuthenticatedUser, firstName: String)
        }
    }

    @Dependency(\.authenticationClient) var authenticationClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.email), .binding(\.password):
                state.emailError = nil
                state.passwordError = nil
                state.errorMessage = nil
                return .none

            case .binding:
                return .none

            case .backTapped:
                guard !state.isLoading else { return .none }
                return .send(.delegate(.back(firstName: state.firstName)))

            case .passwordVisibilityTapped:
                state.isPasswordVisible.toggle()
                return .none

            case .createAccountTapped:
                guard !state.isLoading else { return .none }
                guard validate(&state) else { return .none }
                state.isLoading = true
                state.errorMessage = nil

                let email = EmailAddress.normalized(state.email)
                let password = state.password
                return .run { send in
                    do {
                        await send(.authenticationResponse(.success(
                            try await authenticationClient.signUp(email, password)
                        )))
                    } catch let error as AuthenticationError {
                        await send(.authenticationResponse(.failure(error)))
                    } catch {
                        await send(.authenticationResponse(.failure(.unknown)))
                    }
                }

            case let .authenticationResponse(.success(user)):
                return .send(.delegate(.authenticated(user, firstName: state.firstName)))

            case let .authenticationResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func validate(_ state: inout State) -> Bool {
        let validEmail = EmailAddress.isWellFormed(state.email)
        let validPassword = state.password.count >= 6
        state.emailError = validEmail ? nil : "Enter a valid email address."
        state.passwordError = validPassword ? nil : "Password must have at least 6 characters."
        return validEmail && validPassword
    }
}
