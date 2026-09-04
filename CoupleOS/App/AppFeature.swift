import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct AppFeature {
    @Reducer
    nonisolated enum Destination {
        case launching(LaunchingFeature)
        case unauthenticated(UnauthenticatedFeature)
        case profileProvisioning(ProfileProvisioningFeature)
        case resolvingSession(SessionResolutionFeature)
        case onboarding(OnboardingFeature)
        case authenticated(AuthenticatedFeature)
    }

    @ObservableState
    struct State: Equatable {
        var destination: Destination.State
        var pendingInvite: InviteToken?

        init(
            destination: Destination.State = .launching(LaunchingFeature.State()),
            pendingInvite: InviteToken? = nil
        ) {
            self.destination = destination
            self.pendingInvite = pendingInvite
        }
    }

    enum Action {
        case task
        case openURL(URL)
        case destination(Destination.Action)
        case authStateChanged(AuthenticatedUser?)
        case sessionResponse(
            id: UUID,
            authenticatedUser: AuthenticatedUser,
            Result<User?, UserClientError>
        )
        case provisioningResponse(
            id: UUID,
            authenticatedUser: AuthenticatedUser,
            Result<User, UserClientError>
        )
    }

    @Dependency(\.authenticationClient) var authenticationClient
    @Dependency(\.userClient) var userClient
    @Dependency(\.inviteClient) var inviteClient
    @Dependency(\.uuid) var uuid

    private enum CancelID {
        case authStateListener
        case sessionResolution
        case profileProvisioning
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.destination, action: \.destination) {
            Destination.body
        }

        Reduce { state, action in
            switch action {
            case .task:
                return observeAuthentication()

            case let .openURL(url):
                return handleOpenURL(url, state: &state)

            case let .authStateChanged(user):
                return handleAuthStateChanged(user, state: &state)

            case let .destination(destinationAction):
                return handleDestinationAction(destinationAction, state: &state)

            case let .sessionResponse(id, authenticatedUser, result):
                return handleSessionResponse(
                    id: id,
                    authenticatedUser: authenticatedUser,
                    result: result,
                    state: &state
                )

            case let .provisioningResponse(id, authenticatedUser, result):
                return handleProvisioningResponse(
                    id: id,
                    authenticatedUser: authenticatedUser,
                    result: result,
                    state: &state
                )

            }
        }
    }

    private func observeAuthentication() -> Effect<Action> {
        .run { send in
            for await user in authenticationClient.authStateChanges() {
                await send(.authStateChanged(user))
            }
        }
        .cancellable(id: CancelID.authStateListener, cancelInFlight: true)
    }

    private func handleOpenURL(_ url: URL, state: inout State) -> Effect<Action> {
        guard let token = try? inviteClient.parseInviteURL(url) else {
            return .none
        }

        state.pendingInvite = token
        if let session = activeSession(in: state.destination) {
            state.destination = .onboarding(OnboardingFeature.State(
                destination: .inviteAcceptance(InviteAcceptanceFeature.State(
                    session: session,
                    token: token
                ))
            ))
        } else if case .unauthenticated = state.destination {
            state.destination = publicDestination(pendingInvite: token)
        }
        return .none
    }

    private func handleAuthStateChanged(
        _ user: AuthenticatedUser?,
        state: inout State
    ) -> Effect<Action> {
        guard let user else {
            state.destination = state.pendingInvite.map(publicDestination)
                ?? .unauthenticated(UnauthenticatedFeature.State())
            return cancelSessionWork()
        }

        guard activeUserID(in: state.destination) != user.id,
              !isLoginInFlight(for: user, in: state.destination),
              pendingSignUpName(for: user, in: state.destination) == nil else {
            return .none
        }
        return resolveSession(for: user, state: &state)
    }

    private func handleDestinationAction(
        _ action: Destination.Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case let .unauthenticated(.destination(.login(.delegate(.authenticated(user))))):
            return resolveSession(for: user, state: &state)

        case let .unauthenticated(.destination(.accountCreation(
            .destination(.signUp(.delegate(.authenticated(user, firstName: firstName))))
        ))):
            return provisionProfile(for: user, firstName: firstName, state: &state)

        case let .unauthenticated(.destination(.invite(.delegate(.tokenPrepared(token))))):
            state.pendingInvite = token
            return .none

        case let .onboarding(.delegate(.profileReady(profile))):
            guard let authenticatedUser = activeAuthenticatedUser(in: state.destination) else {
                return .none
            }
            route(authenticatedUser: authenticatedUser, profile: profile, state: &state)
            return .none

        case let .onboarding(.delegate(.inviteAccepted(couple))):
            guard let session = activeSession(in: state.destination) else { return .none }
            state.pendingInvite = nil
            state.destination = .authenticated(AuthenticatedFeature.State(
                session: session,
                couple: couple
            ))
            return .none

        case let .onboarding(.delegate(.partnerJoined(couple))):
            guard let session = activeSession(in: state.destination) else { return .none }
            state.destination = .authenticated(AuthenticatedFeature.State(
                session: session,
                couple: couple
            ))
            return .none

        case .authenticated(.delegate(.signedOut)), .onboarding(.delegate(.signedOut)):
            state.destination = state.pendingInvite.map(publicDestination)
                ?? .unauthenticated(UnauthenticatedFeature.State())
            return cancelSessionWork()

        case .resolvingSession(.retryTapped):
            guard case let .resolvingSession(resolution) = state.destination else {
                return .none
            }
            return resolveSession(for: resolution.authenticatedUser, state: &state)

        case .profileProvisioning(.retryTapped):
            guard case let .profileProvisioning(provisioning) = state.destination else {
                return .none
            }
            return provisionProfile(
                for: provisioning.authenticatedUser,
                firstName: provisioning.firstName,
                state: &state
            )

        default:
            return .none
        }
    }

    private func handleSessionResponse(
        id: UUID,
        authenticatedUser: AuthenticatedUser,
        result: Result<User?, UserClientError>,
        state: inout State
    ) -> Effect<Action> {
        guard case let .resolvingSession(resolution) = state.destination,
              resolution.id == id,
              resolution.authenticatedUser.id == authenticatedUser.id else {
            return .none
        }

        switch result {
        case let .success(profile):
            route(authenticatedUser: authenticatedUser, profile: profile, state: &state)

        case let .failure(error):
            if error == .documentNotFound {
                route(authenticatedUser: authenticatedUser, profile: nil, state: &state)
            } else {
                var updated = resolution
                updated.errorMessage = error.message
                state.destination = .resolvingSession(updated)
            }
        }

        return .none
    }

    private func handleProvisioningResponse(
        id: UUID,
        authenticatedUser: AuthenticatedUser,
        result: Result<User, UserClientError>,
        state: inout State
    ) -> Effect<Action> {
        guard case let .profileProvisioning(provisioning) = state.destination,
              provisioning.id == id,
              provisioning.authenticatedUser.id == authenticatedUser.id else {
            return .none
        }

        switch result {
        case let .success(profile):
            route(authenticatedUser: authenticatedUser, profile: profile, state: &state)

        case let .failure(error):
            var updated = provisioning
            updated.errorMessage = error.message
            state.destination = .profileProvisioning(updated)
        }

        return .none
    }

    private func resolveSession(for user: AuthenticatedUser, state: inout State) -> Effect<Action> {
        if case let .resolvingSession(current) = state.destination,
           current.authenticatedUser.id == user.id,
           current.errorMessage == nil {
            return .none
        }

        let resolutionID = uuid()
        state.destination = .resolvingSession(SessionResolutionFeature.State(
            id: resolutionID,
            authenticatedUser: user
        ))

        return .merge(
            .cancel(id: CancelID.profileProvisioning),
            .run { send in
                do {
                    let profile = try await userClient.fetchUser(user.id)
                    await send(.sessionResponse(
                        id: resolutionID,
                        authenticatedUser: user,
                        .success(profile)
                    ))
                } catch is CancellationError {
                    return
                } catch let error as UserClientError {
                    await send(.sessionResponse(
                        id: resolutionID,
                        authenticatedUser: user,
                        .failure(error)
                    ))
                } catch {
                    await send(.sessionResponse(
                        id: resolutionID,
                        authenticatedUser: user,
                        .failure(.unknown)
                    ))
                }
            }
            .cancellable(id: CancelID.sessionResolution, cancelInFlight: true)
        )
    }

    private func provisionProfile(
        for user: AuthenticatedUser,
        firstName: String,
        state: inout State
    ) -> Effect<Action> {
        if case let .profileProvisioning(current) = state.destination,
           current.authenticatedUser.id == user.id,
           current.errorMessage == nil {
            return .none
        }

        let provisioningID = uuid()
        let normalizedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        state.destination = .profileProvisioning(ProfileProvisioningFeature.State(
            id: provisioningID,
            authenticatedUser: user,
            firstName: normalizedName
        ))

        return .merge(
            .cancel(id: CancelID.sessionResolution),
            .run { send in
                do {
                    let profile = try await userClient.createUser(CreateUserRequest(
                        id: user.id,
                        firstName: normalizedName,
                        onboardingStatus: .readyForPartner
                    ))
                    await send(.provisioningResponse(
                        id: provisioningID,
                        authenticatedUser: user,
                        .success(profile)
                    ))
                } catch is CancellationError {
                    return
                } catch let error as UserClientError {
                    await send(.provisioningResponse(
                        id: provisioningID,
                        authenticatedUser: user,
                        .failure(error)
                    ))
                } catch {
                    await send(.provisioningResponse(
                        id: provisioningID,
                        authenticatedUser: user,
                        .failure(.unknown)
                    ))
                }
            }
            .cancellable(id: CancelID.profileProvisioning, cancelInFlight: true)
        )
    }

    private func route(
        authenticatedUser: AuthenticatedUser,
        profile: User?,
        state: inout State
    ) {
        // A missing profile and an unfinished one both land in recovery; the
        // difference is only whether there is an existing name to prefill.
        guard let profile, profile.onboardingStatus != .profileIncomplete else {
            state.destination = .onboarding(OnboardingFeature.State(
                destination: .profileRecovery(ProfileRecoveryFeature.State(
                    authenticatedUser: authenticatedUser,
                    existingUser: profile
                ))
            ))
            return
        }

        let session = Session(authenticatedUser: authenticatedUser, user: profile)
        if let pendingInvite = state.pendingInvite {
            state.destination = .onboarding(OnboardingFeature.State(
                destination: .inviteAcceptance(InviteAcceptanceFeature.State(
                    session: session,
                    token: pendingInvite
                ))
            ))
            return
        }

        switch profile.onboardingStatus {
        case .profileIncomplete, .readyForPartner:
            state.destination = .onboarding(OnboardingFeature.State(
                destination: .readyForPartner(ReadyForPartnerFeature.State(session: session))
            ))
        case .completed:
            state.destination = .authenticated(AuthenticatedFeature.State(
                session: session
            ))
        }
    }

    private func isLoginInFlight(
        for user: AuthenticatedUser,
        in destination: Destination.State
    ) -> Bool {
        guard case let .unauthenticated(publicState) = destination,
              case let .login(login) = publicState.destination,
              login.isLoading,
              let authenticatedEmail = user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() else {
            return false
        }
        return authenticatedEmail == login.email.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func pendingSignUpName(
        for user: AuthenticatedUser,
        in destination: Destination.State
    ) -> String? {
        guard case let .unauthenticated(publicState) = destination,
              case let .accountCreation(accountCreation) = publicState.destination,
              case let .signUp(signUp) = accountCreation.destination,
              signUp.isLoading,
              let authenticatedEmail = user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
              authenticatedEmail == signUp.email.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() else {
            return nil
        }
        return signUp.firstName
    }

    private func activeUserID(in destination: Destination.State) -> String? {
        switch destination {
        case let .profileProvisioning(state):
            state.authenticatedUser.id
        case let .resolvingSession(state):
            state.authenticatedUser.id
        case let .authenticated(state):
            state.session.authenticatedUser.id
        case let .onboarding(state):
            switch state.destination {
            case let .profileRecovery(state): state.authenticatedUser.id
            case let .readyForPartner(state): state.session.authenticatedUser.id
            case let .inviteAcceptance(state): state.session.authenticatedUser.id
            }
        case .launching, .unauthenticated:
            nil
        }
    }

    private func publicDestination(pendingInvite: InviteToken) -> Destination.State {
        .unauthenticated(UnauthenticatedFeature.State(
            destination: .invite(InviteFeature.State(
                token: pendingInvite,
                presentation: .invitation
            ))
        ))
    }

    private func activeSession(in destination: Destination.State) -> Session? {
        switch destination {
        case let .authenticated(state):
            state.session
        case let .onboarding(state):
            switch state.destination {
            case let .readyForPartner(state): state.session
            case let .inviteAcceptance(state): state.session
            case let .profileRecovery(state):
                state.existingUser.map {
                    Session(authenticatedUser: state.authenticatedUser, user: $0)
                }
            }
        case .launching, .unauthenticated, .profileProvisioning, .resolvingSession:
            nil
        }
    }

    private func activeAuthenticatedUser(in destination: Destination.State) -> AuthenticatedUser? {
        switch destination {
        case let .profileProvisioning(state): state.authenticatedUser
        case let .resolvingSession(state): state.authenticatedUser
        case let .authenticated(state): state.session.authenticatedUser
        case let .onboarding(state):
            switch state.destination {
            case let .profileRecovery(state): state.authenticatedUser
            case let .readyForPartner(state): state.session.authenticatedUser
            case let .inviteAcceptance(state): state.session.authenticatedUser
            }
        case .launching, .unauthenticated: nil
        }
    }

    private func cancelSessionWork() -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.sessionResolution),
            .cancel(id: CancelID.profileProvisioning)
        )
    }
}

extension AppFeature.Destination.State: Equatable {}

@Reducer
nonisolated struct LaunchingFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {}

    var body: some ReducerOf<Self> { EmptyReducer() }
}
