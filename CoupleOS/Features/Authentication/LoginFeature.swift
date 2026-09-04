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
        var emailError: FieldValidation?
        var passwordError: FieldValidation?
        var error: AuthenticationError?
        /// The one success worth saying out loud on this screen.
        var passwordResetSent = false
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
                state.error = nil
                state.passwordResetSent = false
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
                state.error = nil
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
                state.error = error
                return .none

            case .appleSignInTapped:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.error = nil
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
                state.error = nil
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
                state.passwordResetSent = true
                return .none

            case let .passwordResetResponse(.failure(error)):
                state.isLoading = false
                state.error = error
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func validate(_ state: inout State) -> Bool {
        let validEmail = validateEmail(&state)
        let validPassword = state.password.count >= CredentialRules.minimumPasswordLength
        state.passwordError = validPassword
            ? nil
            : .shortPassword(minimum: CredentialRules.minimumPasswordLength)
        return validEmail && validPassword
    }

    private func validateEmail(_ state: inout State) -> Bool {
        let isValid = EmailAddress.isWellFormed(state.email)
        state.emailError = isValid ? nil : .invalidEmail
        return isValid
    }
}
