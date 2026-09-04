import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct ReadyForPartnerFeature {
    @ObservableState
    struct State: Equatable {
        var session: Session
        var phase: Phase = .preparingWorld
        var observationID: UUID?
        var isSigningOut = false
        var signOutError: AuthenticationError?

        enum Phase: Equatable {
            case preparingWorld
            case readyToInvite(Couple, CoupleInvite)
            case waitingForPartner(Couple, CoupleInvite)
            case partnerJoined(Couple)
            case error(PreparationError)
        }
    }

    /// Preparing a world takes two calls that can fail differently. The phase
    /// carries whichever one did, rather than the sentence it produced, so the
    /// screen can say it in the couple's language.
    enum PreparationError: Equatable, Sendable {
        case couple(CoupleClientError)
        case invite(InviteClientError)
    }

    enum Action {
        case task
        case retryTapped
        case coupleResponse(Result<Couple, CoupleClientError>)
        case inviteResponse(InviteResponse)
        case startObserving(ObservationRequest)
        case observationEvent(ObservationEvent)
        case signOutTapped
        case signOutResponse(Result<Void, AuthenticationError>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case partnerJoined(Couple)
            case signedOut
        }
    }

    struct InviteResponse: Equatable, Sendable {
        let couple: Couple
        let result: Result<CoupleInvite, InviteClientError>
    }

    struct ObservationRequest: Equatable, Sendable {
        let couple: Couple
        let invite: CoupleInvite
    }

    struct ObservationEvent: Equatable, Sendable {
        let id: UUID
        let result: Result<Couple, CoupleClientError>
    }

    @Dependency(\.authenticationClient) var authenticationClient
    @Dependency(\.coupleClient) var coupleClient
    @Dependency(\.inviteClient) var inviteClient
    @Dependency(\.uuid) var uuid

    private enum CancelID { case preparation, observation, signOut }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard case .preparingWorld = state.phase else { return .none }
                return prepareWorld()

            case .retryTapped:
                state.phase = .preparingWorld
                state.observationID = nil
                return .merge(.cancel(id: CancelID.observation), prepareWorld())

            case let .coupleResponse(.success(couple)):
                return .run { send in
                    do {
                        await send(.inviteResponse(InviteResponse(
                            couple: couple,
                            result: .success(try await inviteClient.createInvite(couple.id))
                        )))
                    } catch let error as InviteClientError {
                        await send(.inviteResponse(InviteResponse(couple: couple, result: .failure(error))))
                    } catch is CancellationError {
                        return
                    } catch {
                        await send(.inviteResponse(InviteResponse(couple: couple, result: .failure(.unknown))))
                    }
                }
                .cancellable(id: CancelID.preparation, cancelInFlight: true)

            case let .coupleResponse(.failure(error)):
                state.phase = .error(.couple(error))
                return .none

            case let .inviteResponse(response) where response.result.isSuccess:
                guard case let .success(invite) = response.result else { return .none }
                let couple = response.couple
                state.phase = .readyToInvite(couple, invite)
                return .send(.startObserving(ObservationRequest(couple: couple, invite: invite)))

            case let .inviteResponse(response):
                guard case let .failure(error) = response.result else { return .none }
                state.phase = .error(.invite(error))
                return .none

            case let .startObserving(request):
                let couple = request.couple
                let invite = request.invite
                let observationID = uuid()
                state.observationID = observationID
                state.phase = .waitingForPartner(couple, invite)
                return .run { send in
                    do {
                        for try await update in coupleClient.observeCouple(couple.id) {
                            await send(.observationEvent(ObservationEvent(
                                id: observationID,
                                result: .success(update)
                            )))
                        }
                    } catch is CancellationError {
                        return
                    } catch let error as CoupleClientError {
                        await send(.observationEvent(ObservationEvent(
                            id: observationID,
                            result: .failure(error)
                        )))
                    } catch {
                        await send(.observationEvent(ObservationEvent(
                            id: observationID,
                            result: .failure(.unknown)
                        )))
                    }
                }
                .cancellable(id: CancelID.observation, cancelInFlight: true)

            case let .observationEvent(event) where event.result.isSuccess:
                guard state.observationID == event.id,
                      case let .success(couple) = event.result else { return .none }
                guard couple.status == .active, couple.memberIDs.count == 2 else { return .none }
                state.observationID = nil
                var user = state.session.user
                user.activeCoupleID = couple.id
                user.onboardingStatus = .completed
                state.session = Session(
                    authenticatedUser: state.session.authenticatedUser,
                    user: user
                )
                state.phase = .partnerJoined(couple)
                return .merge(
                    .cancel(id: CancelID.observation),
                    .send(.delegate(.partnerJoined(couple)))
                )

            case let .observationEvent(event):
                guard state.observationID == event.id,
                      case let .failure(error) = event.result else { return .none }
                state.observationID = nil
                state.phase = .error(.couple(error))
                return .none

            case .signOutTapped:
                guard !state.isSigningOut else { return .none }
                state.isSigningOut = true
                state.observationID = nil
                state.signOutError = nil
                return .merge(
                    .cancel(id: CancelID.observation),
                    .run { send in
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

            case .signOutResponse(.success):
                state.isSigningOut = false
                return .send(.delegate(.signedOut))

            case let .signOutResponse(.failure(error)):
                state.isSigningOut = false
                state.signOutError = error
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func prepareWorld() -> Effect<Action> {
        .run { send in
            do {
                await send(.coupleResponse(.success(try await coupleClient.createCouple())))
            } catch let error as CoupleClientError {
                await send(.coupleResponse(.failure(error)))
            } catch is CancellationError {
                return
            } catch {
                await send(.coupleResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.preparation, cancelInFlight: true)
    }
}
