import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct AuthenticatedFeature {
    @ObservableState
    struct State: Equatable {
        let session: Session
        var couple: CoupleState
        var home = HomeFeature.State()
        var decisions = DecisionsFeature.State()
        var market = MarketFeature.State()
        var chores = ChoresFeature.State()
        /// The module screen currently open. Modules stay alive as siblings
        /// whether or not they are on screen — the Home needs their signals
        /// even when nobody is looking — so this carries a route, not state.
        var route: HomeRoute?
        var coupleRequestID: UUID?
        var observationID: UUID?
        var isSigningOut = false
        var errorMessage: String?

        init(session: Session, couple: Couple? = nil) {
            self.session = session
            self.couple = couple.map(CoupleState.connected) ?? .loading
        }

        /// The Home, merged from every area that had something to say.
        ///
        /// This array is the whole registration step for a new module: teach it
        /// `homeContribution`, add it here, and it appears on the Home.
        /// `now` is a parameter rather than a call to `Date()` inside because
        /// staleness depends on it, and a Home that cannot be asked "what did
        /// you look like last Tuesday" cannot be tested.
        func composition(now: Date = Date()) -> HomeComposition {
            let partnerName = home.partnerName
            return HomeComposition([
                market.homeContribution(partnerName: partnerName, now: now),
                chores.homeContribution(partnerName: partnerName, now: now),
                decisions.homeContribution(partnerName: partnerName),
                home.homeContribution(partnerName: partnerName),
            ])
        }
    }

    /// A place the Home can open. Today and a single decision stay where they
    /// were, as their own sheets: they are moments, not places.
    nonisolated enum HomeRoute: String, Equatable, Hashable, Identifiable, Sendable {
        case market
        case chores
        case decisions

        var id: String { rawValue }
    }

    enum CoupleState: Equatable {
        case loading
        case connected(Couple)
        case error(String)
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case openTapped(HomeSignal.Target)
        case retryTapped
        case coupleResponse(CoupleResponse)
        case startObserving(Couple)
        case observationEvent(ObservationEvent)
        case home(HomeFeature.Action)
        case decisions(DecisionsFeature.Action)
        case market(MarketFeature.Action)
        case chores(ChoresFeature.Action)
        case signOutTapped
        case signOutResponse(Result<Void, AuthenticationError>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case signedOut
        }
    }

    struct CoupleResponse: Equatable, Sendable {
        let id: UUID
        let result: Result<Couple?, CoupleClientError>
    }

    struct ObservationEvent: Equatable, Sendable {
        let id: UUID
        let result: Result<Couple, CoupleClientError>
    }

    @Dependency(\.authenticationClient) var authenticationClient
    @Dependency(\.coupleClient) var coupleClient
    @Dependency(\.pushNotificationClient) var pushNotificationClient
    @Dependency(\.uuid) var uuid

    private enum CancelID {
        case coupleLoading
        case coupleObservation
        case pushRegistration
        case signOut
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.decisions, action: \.decisions) {
            DecisionsFeature()
        }
        Scope(state: \.market, action: \.market) {
            MarketFeature()
        }
        Scope(state: \.chores, action: \.chores) {
            ChoresFeature()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .openTapped(target):
                return open(target, state: &state)

            case .task:
                return .merge(
                    openHome(state: &state),
                    registerForNotifications(userID: state.session.user.id)
                )

            case .retryTapped:
                state.couple = .loading
                state.errorMessage = nil
                return loadCouple(state: &state)

            case let .coupleResponse(response):
                guard state.coupleRequestID == response.id else { return .none }
                state.coupleRequestID = nil
                switch response.result {
                case let .success(couple?):
                    return connect(couple, state: &state)
                case .success(nil):
                    state.couple = .error(CoupleClientError.coupleNotFound.message)
                case let .failure(error):
                    state.couple = .error(error.message)
                }
                return .none

            case let .startObserving(couple):
                guard state.observationID == nil else { return .none }
                let observationID = uuid()
                state.observationID = observationID
                return observe(couple, id: observationID)

            case let .observationEvent(event):
                guard state.observationID == event.id else { return .none }
                switch event.result {
                case let .success(couple):
                    guard couple.id == state.session.user.activeCoupleID,
                          couple.memberIDs.contains(state.session.user.id) else {
                        return .none
                    }
                    state.couple = .connected(couple)
                    return .send(.home(.coupleAvailable(
                        coupleID: couple.id,
                        currentUserID: state.session.user.id,
                        memberIDs: couple.memberIDs
                    )))
                case let .failure(error):
                    state.observationID = nil
                    state.couple = .error(error.message)
                    return stopModules()
                }

            case .home, .decisions, .market, .chores:
                return .none

            case .signOutTapped:
                guard !state.isSigningOut else { return .none }
                state.isSigningOut = true
                state.coupleRequestID = nil
                state.observationID = nil
                state.errorMessage = nil
                state.route = nil
                return .concatenate(
                    stopModules(),
                    .merge(
                        .cancel(id: CancelID.coupleLoading),
                        .cancel(id: CancelID.coupleObservation),
                        .cancel(id: CancelID.pushRegistration),
                        .run { [userID = state.session.user.id] send in
                            // Drop the token first: deleting the device document
                            // needs the credentials we are about to give up.
                            await pushNotificationClient.unregisterDevice(userID)
                            do {
                                try await authenticationClient.signOut()
                                await send(.signOutResponse(.success(())))
                            } catch let error as AuthenticationError {
                                await send(.signOutResponse(.failure(error)))
                            } catch {
                                await send(.signOutResponse(.failure(.unknown)))
                            }
                        }
                        .cancellable(id: CancelID.signOut, cancelInFlight: true)
                    )
                )

            case .signOutResponse(.success):
                state.isSigningOut = false
                return .send(.delegate(.signedOut))

            case let .signOutResponse(.failure(error)):
                state.isSigningOut = false
                state.errorMessage = error.message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// Routes one tap from the Home. Every destination in the app is reached
    /// from here, so a new module needs one case rather than a new path.
    private func open(_ target: HomeSignal.Target, state: inout State) -> Effect<Action> {
        switch target {
        case .today:
            return .send(.home(.todayTapped))
        case .decisions:
            state.route = .decisions
            return .none
        case let .decision(id):
            state.route = .decisions
            return .send(.decisions(.decisionTapped(id)))
        case .market:
            state.route = .market
            return .none
        case .chores:
            state.route = .chores
            return .none
        }
    }

    private func stopModules() -> Effect<Action> {
        .merge(.send(.decisions(.stop)), .send(.market(.stop)), .send(.chores(.stop)))
    }

    /// Permission is asked for here rather than at launch: by this point the
    /// Couple exists, so a notification has something to be about. A refused
    /// prompt simply ends the effect — nothing about it is user-visible, and
    /// the daily moment still works without it.
    private func registerForNotifications(userID: String) -> Effect<Action> {
        .run { _ in
            guard await pushNotificationClient.requestAuthorization() else { return }
            try? await pushNotificationClient.registerDevice(userID)
            for await _ in pushNotificationClient.tokenRefreshes() {
                try? await pushNotificationClient.registerDevice(userID)
            }
        }
        .cancellable(id: CancelID.pushRegistration, cancelInFlight: true)
    }

    private func openHome(state: inout State) -> Effect<Action> {
        guard state.coupleRequestID == nil, state.observationID == nil else { return .none }
        switch state.couple {
        case let .connected(couple):
            return connect(couple, state: &state)
        case .loading, .error:
            state.couple = .loading
            return loadCouple(state: &state)
        }
    }

    private func loadCouple(state: inout State) -> Effect<Action> {
        let requestID = uuid()
        state.coupleRequestID = requestID
        return .run { send in
            do {
                await send(.coupleResponse(CoupleResponse(
                    id: requestID,
                    result: .success(try await coupleClient.fetchCurrentCouple())
                )))
            } catch is CancellationError {
                return
            } catch let error as CoupleClientError {
                await send(.coupleResponse(CoupleResponse(id: requestID, result: .failure(error))))
            } catch {
                await send(.coupleResponse(CoupleResponse(id: requestID, result: .failure(.unknown))))
            }
        }
        .cancellable(id: CancelID.coupleLoading, cancelInFlight: true)
    }

    private func connect(_ couple: Couple, state: inout State) -> Effect<Action> {
        state.couple = .connected(couple)
        let partnerID = couple.memberIDs.first { $0 != state.session.user.id }
        return .merge(
            .send(.home(.coupleAvailable(
                coupleID: couple.id,
                currentUserID: state.session.user.id,
                memberIDs: couple.memberIDs
            ))),
            partnerID.map { partnerID in
                .merge(
                    .send(.decisions(.coupleAvailable(
                        coupleID: couple.id,
                        currentUserID: state.session.user.id,
                        partnerID: partnerID
                    ))),
                    .send(.market(.coupleAvailable(
                        coupleID: couple.id,
                        currentUserID: state.session.user.id,
                        partnerID: partnerID
                    ))),
                    .send(.chores(.coupleAvailable(
                        coupleID: couple.id,
                        currentUserID: state.session.user.id,
                        partnerID: partnerID
                    )))
                )
            } ?? .none,
            .send(.startObserving(couple))
        )
    }

    private func observe(_ couple: Couple, id: UUID) -> Effect<Action> {
        .run { send in
            do {
                for try await update in coupleClient.observeCouple(couple.id) {
                    await send(.observationEvent(ObservationEvent(id: id, result: .success(update))))
                }
            } catch is CancellationError {
                return
            } catch let error as CoupleClientError {
                await send(.observationEvent(ObservationEvent(id: id, result: .failure(error))))
            } catch {
                await send(.observationEvent(ObservationEvent(id: id, result: .failure(.unknown))))
            }
        }
        .cancellable(id: CancelID.coupleObservation, cancelInFlight: true)
    }
}
