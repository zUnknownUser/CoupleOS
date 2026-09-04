import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class AppFeatureTests: XCTestCase {
    private let fixedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func testLaunchSignedOutShowsWelcome() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.authenticationClient.authStateChanges = { Self.authStream(nil) }
        }

        await store.send(.task)
        await store.receive({ action in
            guard case .authStateChanged(nil) = action else { return false }
            return true
        }) {
            $0.destination = .unauthenticated(UnauthenticatedFeature.State())
        }
    }

    func testLaunchAuthenticatedWithCompletedProfile() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .completed)
        let store = makeStore(fetchUser: { _ in profile })

        await store.send(.authStateChanged(authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await store.receive({ action in
            guard case .sessionResponse(self.fixedID, authUser, .success(profile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .authenticated(AuthenticatedFeature.State(
                session: Session(authenticatedUser: authUser, user: profile)
            ))
        }
    }

    func testAuthenticatedWithoutProfileEntersRecovery() async {
        let authUser = TestFixtures.authenticatedUser
        let store = makeStore(fetchUser: { _ in nil })

        await store.send(.authStateChanged(authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await store.receive({ action in
            guard case .sessionResponse(self.fixedID, authUser, .success(nil)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .onboarding(OnboardingFeature.State(
                destination: .profileRecovery(ProfileRecoveryFeature.State(
                    authenticatedUser: authUser
                ))
            ))
        }
    }

    func testDocumentNotFoundErrorEntersRecovery() async {
        let authUser = TestFixtures.authenticatedUser
        let store = makeStore(fetchUser: { _ in throw UserClientError.documentNotFound })

        await store.send(.authStateChanged(authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await store.receive({ action in
            guard case .sessionResponse(self.fixedID, authUser, .failure(.documentNotFound)) = action
            else { return false }
            return true
        }) {
            $0.destination = .onboarding(OnboardingFeature.State(
                destination: .profileRecovery(ProfileRecoveryFeature.State(
                    authenticatedUser: authUser
                ))
            ))
        }
    }

    func testIncompleteProfileReturnsToAuthenticatedOnboarding() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .profileIncomplete)
        let store = makeStore(fetchUser: { _ in profile })

        await store.send(.authStateChanged(authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await store.receive({ action in
            guard case .sessionResponse(self.fixedID, authUser, .success(profile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .onboarding(OnboardingFeature.State(
                destination: .profileRecovery(ProfileRecoveryFeature.State(
                    authenticatedUser: authUser,
                    existingUser: profile
                ))
            ))
        }
    }

    func testReadyForPartnerContinuesAuthenticatedOnboarding() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .readyForPartner)
        let store = makeStore(fetchUser: { _ in profile })

        await store.send(.authStateChanged(authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await store.receive({ action in
            guard case .sessionResponse(self.fixedID, authUser, .success(profile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .onboarding(OnboardingFeature.State(
                destination: .readyForPartner(ReadyForPartnerFeature.State(
                    session: Session(authenticatedUser: authUser, user: profile)
                ))
            ))
        }
    }

    func testLogoutReturnsToWelcome() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .completed)
        let store = TestStore(initialState: AppFeature.State(
            destination: .authenticated(AuthenticatedFeature.State(
                session: Session(authenticatedUser: authUser, user: profile)
            ))
        )) { AppFeature() } withDependencies: {
            $0.authenticationClient.signOut = {}
        }

        await store.send(.destination(.authenticated(.signOutTapped))) {
            var authenticated = AuthenticatedFeature.State(
                session: Session(authenticatedUser: authUser, user: profile)
            )
            authenticated.isSigningOut = true
            $0.destination = .authenticated(authenticated)
        }
        await store.receive(\.destination.authenticated.decisions.stop)
        await store.receive(\.destination.authenticated.market.stop)
        await store.receive(\.destination.authenticated.chores.stop)
        await store.receive({ action in
            guard case .destination(.authenticated(.signOutResponse(.success))) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .authenticated(AuthenticatedFeature.State(
                session: Session(authenticatedUser: authUser, user: profile)
            ))
        }
        await store.receive({ action in
            guard case .destination(.authenticated(.delegate(.signedOut))) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .unauthenticated(UnauthenticatedFeature.State())
        }
    }

    func testSignUpAuthEmissionDuringSlowProfileCreationDoesNotOpenRecovery() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .readyForPartner)
        let creation = ControlledOperation<User>()
        let fetchCalls = LockIsolated(0)
        let store = TestStore(initialState: signUpState()) { AppFeature() } withDependencies: {
            $0.uuid = .constant(self.fixedID)
            $0.userClient.createUser = { request in
                XCTAssertEqual(request.id, authUser.id)
                XCTAssertEqual(request.firstName, "Alex")
                return try await creation.run()
            }
            $0.userClient.fetchUser = { _ in
                fetchCalls.withValue { $0 += 1 }
                return nil
            }
        }

        await store.send(signUpDelegate(user: authUser)) {
            $0.destination = .profileProvisioning(ProfileProvisioningFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser,
                firstName: "Alex"
            ))
        }
        await creation.waitUntilStarted()
        await store.send(.authStateChanged(authUser))

        guard case .profileProvisioning = store.state.destination else {
            return XCTFail("The app must remain in profile provisioning.")
        }
        XCTAssertEqual(fetchCalls.value, 0)

        await creation.succeed(profile)
        await store.receive({ action in
            guard case .provisioningResponse(self.fixedID, authUser, .success(profile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .onboarding(OnboardingFeature.State(
                destination: .readyForPartner(ReadyForPartnerFeature.State(
                    session: Session(authenticatedUser: authUser, user: profile)
                ))
            ))
        }
    }

    func testSignUpAuthEmissionWaitsForChildSuccessBeforeChangingDestination() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .readyForPartner)
        let creation = ControlledOperation<User>()
        let store = TestStore(initialState: signUpState()) { AppFeature() } withDependencies: {
            $0.uuid = .constant(self.fixedID)
            $0.userClient.createUser = { _ in try await creation.run() }
        }

        await store.send(.authStateChanged(authUser))

        await store.send(.destination(.unauthenticated(.destination(.accountCreation(
            .destination(.signUp(.authenticationResponse(.success(authUser))))
        )))))

        await store.receive({ action in
            guard case let .destination(.unauthenticated(.destination(.accountCreation(
                .destination(.signUp(.delegate(.authenticated(user, firstName: firstName))))
            )))) = action else { return false }
            return user == authUser && firstName == "Alex"
        }) {
            $0.destination = .profileProvisioning(ProfileProvisioningFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser,
                firstName: "Alex"
            ))
        }
        await creation.waitUntilStarted()
        await creation.succeed(profile)
        await store.receive({ action in
            guard case .provisioningResponse(self.fixedID, authUser, .success(profile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .onboarding(OnboardingFeature.State(
                destination: .readyForPartner(ReadyForPartnerFeature.State(
                    session: Session(authenticatedUser: authUser, user: profile)
                ))
            ))
        }
    }

    func testProfileProvisioningFailureRetriesWithoutReauthentication() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .readyForPartner)
        let calls = LockIsolated(0)
        let store = TestStore(initialState: signUpState()) { AppFeature() } withDependencies: {
            $0.uuid = .incrementing
            $0.userClient.createUser = { _ in
                let call = calls.withValue { value -> Int in
                    value += 1
                    return value
                }
                if call == 1 { throw UserClientError.networkUnavailable }
                return profile
            }
        }
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let retryID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        await store.send(signUpDelegate(user: authUser)) {
            $0.destination = .profileProvisioning(ProfileProvisioningFeature.State(
                id: firstID,
                authenticatedUser: authUser,
                firstName: "Alex"
            ))
        }
        await store.receive({ action in
            guard case .provisioningResponse(firstID, authUser, .failure(.networkUnavailable)) = action
            else { return false }
            return true
        }) {
            $0.destination = .profileProvisioning(ProfileProvisioningFeature.State(
                id: firstID,
                authenticatedUser: authUser,
                firstName: "Alex",
                errorMessage: UserClientError.networkUnavailable.message
            ))
        }
        await store.send(.destination(.profileProvisioning(.retryTapped))) {
            $0.destination = .profileProvisioning(ProfileProvisioningFeature.State(
                id: retryID,
                authenticatedUser: authUser,
                firstName: "Alex"
            ))
        }
        await store.receive({ action in
            guard case .provisioningResponse(retryID, authUser, .success(profile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .onboarding(OnboardingFeature.State(
                destination: .readyForPartner(ReadyForPartnerFeature.State(
                    session: Session(authenticatedUser: authUser, user: profile)
                ))
            ))
        }
        XCTAssertEqual(calls.value, 2)
    }

    func testAuthListenerWaitsForInFlightLoginDelegate() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .completed)
        var state = loginState()
        guard case var .unauthenticated(unauthenticated) = state.destination,
              case var .login(login) = unauthenticated.destination else {
            return XCTFail("Expected the login destination.")
        }
        login.email = authUser.email ?? ""
        login.isLoading = true
        unauthenticated.destination = .login(login)
        state.destination = .unauthenticated(unauthenticated)

        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.uuid = .constant(self.fixedID)
            $0.userClient.fetchUser = { _ in profile }
        }

        await store.send(.authStateChanged(authUser))
        await store.send(loginDelegate(user: authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await store.receive({ action in
            guard case .sessionResponse(self.fixedID, authUser, .success(profile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .authenticated(AuthenticatedFeature.State(
                session: Session(authenticatedUser: authUser, user: profile)
            ))
        }
    }

    func testLoginDelegateAndAuthListenerResolveProfileOnce() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .completed)
        let fetch = ControlledOperation<User?>()
        let fetchCalls = LockIsolated(0)
        let store = TestStore(initialState: loginState()) { AppFeature() } withDependencies: {
            $0.uuid = .constant(self.fixedID)
            $0.userClient.fetchUser = { _ in
                fetchCalls.withValue { $0 += 1 }
                return try await fetch.run()
            }
        }

        await store.send(loginDelegate(user: authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await fetch.waitUntilStarted()
        await store.send(.authStateChanged(authUser))
        XCTAssertEqual(fetchCalls.value, 1)

        await fetch.succeed(profile)
        await store.receive({ action in
            guard case .sessionResponse(self.fixedID, authUser, .success(profile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .authenticated(AuthenticatedFeature.State(
                session: Session(authenticatedUser: authUser, user: profile)
            ))
        }
    }

    func testTwoRapidAuthEmissionsOnlyLatestResolutionWins() async {
        let firstUser = TestFixtures.authenticatedUser
        let secondUser = AuthenticatedUser(
            id: "user-2",
            email: "sam@example.com",
            displayName: "Sam"
        )
        let secondProfile = User(
            id: secondUser.id,
            firstName: "Sam",
            createdAt: Date(timeIntervalSince1970: 1_700_000_001),
            onboardingStatus: .completed
        )
        let firstFetch = ControlledOperation<User?>()
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.uuid = .incrementing
            $0.userClient.fetchUser = { id in
                if id == firstUser.id { return try await firstFetch.run() }
                return secondProfile
            }
        }
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        await store.send(.authStateChanged(firstUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: firstID,
                authenticatedUser: firstUser
            ))
        }
        await firstFetch.waitUntilStarted()
        await store.send(.authStateChanged(secondUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: secondID,
                authenticatedUser: secondUser
            ))
        }
        await store.receive({ action in
            guard case .sessionResponse(secondID, secondUser, .success(secondProfile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .authenticated(AuthenticatedFeature.State(
                session: Session(authenticatedUser: secondUser, user: secondProfile)
            ))
        }
        let firstWasCancelled = await firstFetch.cancellationObserved()
        XCTAssertTrue(firstWasCancelled)

        await store.send(.sessionResponse(
            id: firstID,
            authenticatedUser: firstUser,
            .success(TestFixtures.user(status: .completed))
        ))
    }

    func testLogoutDuringFetchCannotRestoreStaleSession() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .completed)
        let fetch = ControlledOperation<User?>()
        let store = makeStore(fetchUser: { _ in try await fetch.run() })

        await store.send(.authStateChanged(authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await fetch.waitUntilStarted()
        await store.send(.authStateChanged(nil)) {
            $0.destination = .unauthenticated(UnauthenticatedFeature.State())
        }
        let fetchWasCancelled = await fetch.cancellationObserved()
        XCTAssertTrue(fetchWasCancelled)

        await store.send(.sessionResponse(
            id: fixedID,
            authenticatedUser: authUser,
            .success(profile)
        ))
    }

    func testOfflineDuringBootstrapStaysInResolutionError() async {
        await assertResolutionError(.networkUnavailable)
    }

    func testUnavailableDuringBootstrapStaysInResolutionError() async {
        await assertResolutionError(.unavailable)
    }

    func testMalformedProfileStaysInResolutionError() async {
        await assertResolutionError(.invalidData)
    }

    func testDeepLinkWhileSignedOutPreservesInviteAndShowsInvitationEntry() async {
        let token = TestFixtures.inviteToken
        let url = TestFixtures.invite.url
        let store = TestStore(initialState: AppFeature.State(
            destination: .unauthenticated(UnauthenticatedFeature.State())
        )) { AppFeature() } withDependencies: {
            $0.inviteClient.parseInviteURL = { receivedURL in
                XCTAssertEqual(receivedURL, url)
                return token
            }
        }

        await store.send(.openURL(url)) {
            $0.pendingInvite = token
            $0.destination = .unauthenticated(UnauthenticatedFeature.State(
                destination: .invite(InviteFeature.State(
                    token: token,
                    presentation: .invitation
                ))
            ))
        }
    }

    func testDeepLinkWhileAuthenticatedStartsAcceptance() async {
        let token = TestFixtures.inviteToken
        let session = Session(
            authenticatedUser: TestFixtures.authenticatedUser,
            user: TestFixtures.user(status: .completed)
        )
        let url = TestFixtures.invite.url
        let store = TestStore(initialState: AppFeature.State(
            destination: .authenticated(AuthenticatedFeature.State(session: session))
        )) { AppFeature() } withDependencies: {
            $0.inviteClient.parseInviteURL = { _ in token }
        }

        await store.send(.openURL(url)) {
            $0.pendingInvite = token
            $0.destination = .onboarding(OnboardingFeature.State(
                destination: .inviteAcceptance(InviteAcceptanceFeature.State(
                    session: session,
                    token: token
                ))
            ))
        }
    }

    func testPendingInviteCrossesAuthenticationAndSessionResolution() async {
        let authUser = TestFixtures.authenticatedUser
        let profile = TestFixtures.user(status: .readyForPartner)
        let token = TestFixtures.inviteToken
        let store = TestStore(initialState: AppFeature.State(
            destination: .unauthenticated(UnauthenticatedFeature.State(
                destination: .login(LoginFeature.State())
            )),
            pendingInvite: token
        )) { AppFeature() } withDependencies: {
            $0.uuid = .constant(self.fixedID)
            $0.userClient.fetchUser = { _ in profile }
        }

        await store.send(.authStateChanged(authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await store.receive({ action in
            guard case .sessionResponse(self.fixedID, authUser, .success(profile)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .onboarding(OnboardingFeature.State(
                destination: .inviteAcceptance(InviteAcceptanceFeature.State(
                    session: Session(authenticatedUser: authUser, user: profile),
                    token: token
                ))
            ))
        }
        XCTAssertEqual(store.state.pendingInvite, token)
    }

    func testAcceptedInviteOpensHomeWithTheAcceptedCouple() async {
        let active = TestFixtures.couple(status: .active)
        var acceptance = InviteAcceptanceFeature.State(
            session: TestFixtures.session,
            token: TestFixtures.inviteToken
        )
        var acceptedUser = acceptance.session.user
        acceptedUser.activeCoupleID = active.id
        acceptedUser.onboardingStatus = .completed
        acceptance.session = Session(
            authenticatedUser: acceptance.session.authenticatedUser,
            user: acceptedUser
        )
        acceptance.phase = .joined(active)
        let store = TestStore(initialState: AppFeature.State(
            destination: .onboarding(OnboardingFeature.State(
                destination: .inviteAcceptance(acceptance)
            )),
            pendingInvite: TestFixtures.inviteToken
        )) { AppFeature() }

        await store.send(.destination(.onboarding(.delegate(.inviteAccepted(active))))) {
            $0.pendingInvite = nil
            var user = TestFixtures.session.user
            user.activeCoupleID = active.id
            user.onboardingStatus = .completed
            $0.destination = .authenticated(AuthenticatedFeature.State(
                session: Session(
                    authenticatedUser: TestFixtures.session.authenticatedUser,
                    user: user
                ),
                couple: active
            ))
        }
    }

    private func assertResolutionError(_ error: UserClientError) async {
        let authUser = TestFixtures.authenticatedUser
        let store = makeStore(fetchUser: { _ in throw error })

        await store.send(.authStateChanged(authUser)) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser
            ))
        }
        await store.receive({ action in
            guard case .sessionResponse(self.fixedID, authUser, .failure(error)) = action else {
                return false
            }
            return true
        }) {
            $0.destination = .resolvingSession(SessionResolutionFeature.State(
                id: self.fixedID,
                authenticatedUser: authUser,
                errorMessage: error.message
            ))
        }
    }

    private func makeStore(
        fetchUser: @escaping @Sendable (String) async throws -> User?
    ) -> TestStoreOf<AppFeature> {
        TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.uuid = .constant(self.fixedID)
            $0.userClient.fetchUser = fetchUser
        }
    }

    private func signUpState() -> AppFeature.State {
        var signUp = SignUpFeature.State(firstName: "Alex")
        signUp.email = "alex@example.com"
        signUp.password = "secret1"
        signUp.isLoading = true
        return AppFeature.State(destination: .unauthenticated(UnauthenticatedFeature.State(
            destination: .accountCreation(AccountCreationFeature.State(
                destination: .signUp(signUp)
            ))
        )))
    }

    private func loginState() -> AppFeature.State {
        AppFeature.State(destination: .unauthenticated(UnauthenticatedFeature.State(
            destination: .login(LoginFeature.State())
        )))
    }

    private func signUpDelegate(user: AuthenticatedUser) -> AppFeature.Action {
        .destination(.unauthenticated(.destination(.accountCreation(.destination(.signUp(
            .delegate(.authenticated(user, firstName: "Alex"))
        ))))))
    }

    private func loginDelegate(user: AuthenticatedUser) -> AppFeature.Action {
        .destination(.unauthenticated(.destination(.login(.delegate(.authenticated(user))))))
    }

    private nonisolated static func authStream(
        _ user: AuthenticatedUser?
    ) -> AsyncStream<AuthenticatedUser?> {
        AsyncStream { continuation in
            continuation.yield(user)
            continuation.finish()
        }
    }
}

private actor ControlledOperation<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, any Error>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var wasCancelled = false
    private var completion: Completion?

    private enum Completion {
        case success(Value)
        case cancelled
    }

    func run() async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if let completion {
                    resume(continuation, with: completion)
                } else {
                    self.continuation = continuation
                    let waiters = startWaiters
                    startWaiters.removeAll()
                    waiters.forEach { $0.resume() }
                }
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func waitUntilStarted() async {
        if continuation != nil || completion != nil { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func succeed(_ value: Value) {
        complete(with: .success(value))
    }

    func cancellationObserved() -> Bool {
        wasCancelled
    }

    private func cancel() {
        wasCancelled = true
        complete(with: .cancelled)
    }

    private func complete(with completion: Completion) {
        guard self.completion == nil else { return }
        self.completion = completion
        if let continuation {
            self.continuation = nil
            resume(continuation, with: completion)
        }
    }

    private func resume(
        _ continuation: CheckedContinuation<Value, any Error>,
        with completion: Completion
    ) {
        switch completion {
        case let .success(value): continuation.resume(returning: value)
        case .cancelled: continuation.resume(throwing: CancellationError())
        }
    }
}
