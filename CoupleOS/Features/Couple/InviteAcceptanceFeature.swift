import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct InviteAcceptanceFeature {
    @ObservableState
    struct State: Equatable {
        var session: Session
        let token: InviteToken
        var phase: Phase = .accepting
        var requestID: UUID?

        enum Phase: Equatable {
            case accepting
            case joined(Couple)
            case error(InviteClientError)
        }
    }

    enum Action: Equatable {
        case task
        case retryTapped
        case response(Response)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case accepted(Couple)
        }
    }

    struct Response: Equatable, Sendable {
        let id: UUID
        let result: Result<Couple, InviteClientError>
    }

    @Dependency(\.inviteClient) var inviteClient
    @Dependency(\.uuid) var uuid

    private enum CancelID { case acceptance }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task, .retryTapped:
                guard state.requestID == nil else { return .none }
                let requestID = uuid()
                let token = state.token
                state.requestID = requestID
                state.phase = .accepting
                return .run { send in
                    do {
                        await send(.response(Response(
                            id: requestID,
                            result: .success(try await inviteClient.acceptInvite(token))
                        )))
                    } catch let error as InviteClientError {
                        await send(.response(Response(id: requestID, result: .failure(error))))
                    } catch is CancellationError {
                        return
                    } catch {
                        await send(.response(Response(id: requestID, result: .failure(.unknown))))
                    }
                }
                .cancellable(id: CancelID.acceptance, cancelInFlight: true)

            case let .response(response) where response.result.isSuccess:
                guard state.requestID == response.id,
                      case let .success(couple) = response.result else { return .none }
                state.requestID = nil
                var user = state.session.user
                user.activeCoupleID = couple.id
                user.onboardingStatus = .completed
                state.session = Session(
                    authenticatedUser: state.session.authenticatedUser,
                    user: user
                )
                state.phase = .joined(couple)
                return .send(.delegate(.accepted(couple)))

            case let .response(response):
                guard state.requestID == response.id,
                      case let .failure(error) = response.result else { return .none }
                state.requestID = nil
                state.phase = .error(error)
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
