import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct LoginFeature {
    @ObservableState
    struct State: Equatable {
        var email = ""
        var password = ""
        var isPasswordVisible = false
        var isLoading = false
        var emailError: String?
        var passwordError: String?
        var errorMessage: String?
        var confirmationMessage: String?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case backTapped
        case continueTapped
        case appleSignInTapped
        case forgotPasswordTapped
        case passwordVisibilityTapped
        case signInResponse(Result<AuthenticatedUser, AuthenticationError>)
        case passwordResetResponse(Result<Void, AuthenticationError>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case back
            case authenticated(AuthenticatedUser)
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
                state.confirmationMessage = nil
                return .none

            case .binding:
                return .none

            case .backTapped:
                return .send(.delegate(.back))

            case .passwordVisibilityTapped:
                state.isPasswordVisible.toggle()
                return .none

            case .continueTapped:
                guard !state.isLoading else { return .none }
                guard validate(&state) else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                let email = EmailAddress.normalized(state.email)
                let password = state.password
                return .run { send in
                    do {
                        await send(.signInResponse(.success(
                            try await authenticationClient.signIn(email, password)
                        )))
                    } catch let error as AuthenticationError {
                        await send(.signInResponse(.failure(error)))
                    } catch {
                        await send(.signInResponse(.failure(.unknown)))
                    }
                }

            case let .signInResponse(.success(user)):
                state.isLoading = false
                return .send(.delegate(.authenticated(user)))

            case let .signInResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none

            case .appleSignInTapped:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        await send(.signInResponse(.success(
                            try await authenticationClient.signInWithApple()
                        )))
                    } catch let error as AuthenticationError {
                        await send(.signInResponse(.failure(error)))
                    } catch {
                        await send(.signInResponse(.failure(.unknown)))
                    }
                }

            case .forgotPasswordTapped:
                guard !state.isLoading else { return .none }
                guard validateEmail(&state) else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                let email = EmailAddress.normalized(state.email)
                return .run { send in
                    do {
                        try await authenticationClient.sendPasswordReset(email)
                        await send(.passwordResetResponse(.success(())))
                    } catch let error as AuthenticationError {
                        await send(.passwordResetResponse(.failure(error)))
                    } catch {
                        await send(.passwordResetResponse(.failure(.unknown)))
                    }
                }

            case .passwordResetResponse(.success):
                state.isLoading = false
                state.confirmationMessage = "Check your inbox for a reset link."
                return .none

            case let .passwordResetResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func validate(_ state: inout State) -> Bool {
        let validEmail = validateEmail(&state)
        let validPassword = state.password.count >= 6
        state.passwordError = validPassword ? nil : "Password must have at least 6 characters."
        return validEmail && validPassword
    }

    private func validateEmail(_ state: inout State) -> Bool {
        let isValid = EmailAddress.isWellFormed(state.email)
        state.emailError = isValid ? nil : "Enter a valid email address."
        return isValid
    }
}
