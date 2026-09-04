import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct HomeFeature {
    @Reducer
    nonisolated enum Destination {
        case today(TodayFeature)
    }

    @ObservableState
    struct State: Equatable {
        var partner: PartnerState = .loading
        var partnerID: String?
        var partnerRequestID: UUID?

        var dailyExperience: DailyExperience?
        var dailyRequestID: UUID?
        var dailyObservationID: UUID?
        var dailyCoupleID: String?
        var dailyCurrentUserID: String?
        var dailyErrorMessage: String?
        var opensTodayWhenLoaded = false

        @Presents var destination: Destination.State?

        var dailyStatus: DailyExperience.Status? {
            guard let dailyExperience, let dailyCurrentUserID else { return nil }
            return dailyExperience.status(for: dailyCurrentUserID)
        }
    }

    enum PartnerState: Equatable {
        case loading
        case loaded(User)
        case unavailable
        case error(String)
    }

    enum Action {
        case coupleAvailable(coupleID: String, currentUserID: String, memberIDs: [String])
        case retryPartnerTapped
        case partnerResponse(PartnerResponse)
        case todayTapped
        case retryDailyTapped
        case dailyResponse(DailyResponse)
        case dailyObservationEvent(DailyObservationEvent)
        case destination(PresentationAction<Destination.Action>)
    }

    struct PartnerResponse: Equatable, Sendable {
        let id: UUID
        let partnerID: String
        let result: Result<User?, UserClientError>
    }

    struct DailyResponse: Equatable, Sendable {
        let id: UUID
        let result: Result<DailyExperience, DailyExperienceError>
    }

    struct DailyObservationEvent: Equatable, Sendable {
        let id: UUID
        let result: Result<DailyExperience, DailyExperienceError>
    }

    @Dependency(\.userClient) var userClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.dailyExperienceClient) var dailyClient

    private enum CancelID {
        case partnerProfile
        case daily
        case dailyObservation
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .coupleAvailable(coupleID, currentUserID, memberIDs):
                return receiveCouple(
                    coupleID: coupleID,
                    currentUserID: currentUserID,
                    memberIDs: memberIDs,
                    state: &state
                )

            case .retryPartnerTapped:
                guard let partnerID = state.partnerID,
                      state.partnerRequestID == nil else { return .none }
                return loadPartner(partnerID, state: &state)

            case let .partnerResponse(response):
                guard state.partnerRequestID == response.id,
                      state.partnerID == response.partnerID else { return .none }
                state.partnerRequestID = nil
                switch response.result {
                case let .success(partner?):
                    state.partner = partner.id == response.partnerID ? .loaded(partner) : .unavailable
                case .success(nil):
                    state.partner = .unavailable
                case let .failure(error):
                    state.partner = .error(error.message)
                }
                return .none

            case .todayTapped:
                return openToday(state: &state)

            case .retryDailyTapped:
                return retryDaily(state: &state)

            case let .dailyResponse(response):
                return receiveDaily(response, state: &state)

            case let .dailyObservationEvent(event):
                return receiveDailyObservation(event, state: &state)

            case let .destination(.presented(.today(.response(.success(experience))))):
                state.dailyExperience = experience
                state.dailyErrorMessage = nil
                return .none

            case let .destination(.presented(.today(.experienceUpdated(experience)))):
                state.dailyExperience = experience
                state.dailyErrorMessage = nil
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func receiveCouple(
        coupleID: String,
        currentUserID: String,
        memberIDs: [String],
        state: inout State
    ) -> Effect<Action> {
        guard let partnerID = memberIDs.first(where: { $0 != currentUserID }) else {
            state.partnerID = nil
            state.partnerRequestID = nil
            state.partner = .unavailable
            state.destination = nil
            state.dailyExperience = nil
            state.dailyCoupleID = nil
            state.dailyCurrentUserID = nil
            state.dailyObservationID = nil
            return .merge(
                .cancel(id: CancelID.partnerProfile),
                .cancel(id: CancelID.daily),
                .cancel(id: CancelID.dailyObservation)
            )
        }

        let identityChanged = state.dailyCoupleID != coupleID
            || state.dailyCurrentUserID != currentUserID
        if identityChanged {
            resetDailyContext(coupleID: coupleID, currentUserID: currentUserID, state: &state)
        }

        let partnerEffect: Effect<Action>
        if state.partnerID == partnerID {
            partnerEffect = .none
        } else {
            state.partnerID = partnerID
            partnerEffect = loadPartner(partnerID, state: &state)
        }

        let dailyEffect = state.dailyExperience == nil && state.dailyRequestID == nil
            ? loadToday(coupleID: coupleID, state: &state)
            : .none

        guard identityChanged else {
            return .merge(partnerEffect, dailyEffect)
        }
        return .merge(
            .cancel(id: CancelID.dailyObservation),
            partnerEffect,
            dailyEffect
        )
    }

    private func resetDailyContext(
        coupleID: String,
        currentUserID: String,
        state: inout State
    ) {
        state.destination = nil
        state.dailyExperience = nil
        state.dailyRequestID = nil
        state.dailyObservationID = nil
        state.dailyCoupleID = coupleID
        state.dailyCurrentUserID = currentUserID
        state.dailyErrorMessage = nil
        state.opensTodayWhenLoaded = false
    }

    private func openToday(state: inout State) -> Effect<Action> {
        if let experience = state.dailyExperience,
           let coupleID = state.dailyCoupleID,
           let currentUserID = state.dailyCurrentUserID {
            state.opensTodayWhenLoaded = false
            state.destination = .today(TodayFeature.State(
                coupleID: coupleID,
                currentUserID: currentUserID,
                experience: experience
            ))
            return .none
        }

        guard let coupleID = state.dailyCoupleID else { return .none }
        state.opensTodayWhenLoaded = true
        guard state.dailyRequestID == nil else { return .none }
        return loadToday(coupleID: coupleID, state: &state)
    }

    private func retryDaily(state: inout State) -> Effect<Action> {
        guard let coupleID = state.dailyCoupleID else { return .none }
        state.dailyErrorMessage = nil

        guard let experienceID = state.dailyExperience?.id else {
            guard state.dailyRequestID == nil else { return .none }
            return loadToday(coupleID: coupleID, state: &state)
        }

        return startDailyObservation(
            coupleID: coupleID,
            experienceID: experienceID,
            state: &state
        )
    }

    private func receiveDaily(_ response: DailyResponse, state: inout State) -> Effect<Action> {
        guard state.dailyRequestID == response.id else { return .none }
        state.dailyRequestID = nil

        switch response.result {
        case let .success(experience):
            guard let coupleID = state.dailyCoupleID,
                  let userID = state.dailyCurrentUserID else { return .none }
            state.dailyExperience = experience
            state.dailyErrorMessage = nil

            if state.opensTodayWhenLoaded {
                state.destination = .today(TodayFeature.State(
                    coupleID: coupleID,
                    currentUserID: userID,
                    experience: experience
                ))
                state.opensTodayWhenLoaded = false
            }

            return startDailyObservation(
                coupleID: coupleID,
                experienceID: experience.id,
                state: &state
            )

        case let .failure(error):
            state.opensTodayWhenLoaded = false
            state.dailyErrorMessage = error.message
            return .none
        }
    }

    private func receiveDailyObservation(
        _ event: DailyObservationEvent,
        state: inout State
    ) -> Effect<Action> {
        guard state.dailyObservationID == event.id else { return .none }

        switch event.result {
        case let .success(experience):
            state.dailyExperience = experience
            state.dailyErrorMessage = nil
            guard case .today = state.destination else { return .none }
            return .send(.destination(.presented(.today(.experienceUpdated(experience)))))

        case let .failure(error):
            state.dailyObservationID = nil
            state.dailyErrorMessage = error.message
            return .none
        }
    }

    private func loadPartner(_ partnerID: String, state: inout State) -> Effect<Action> {
        let requestID = uuid()
        state.partnerRequestID = requestID
        state.partner = .loading
        return .run { send in
            do {
                await send(.partnerResponse(PartnerResponse(
                    id: requestID,
                    partnerID: partnerID,
                    result: .success(try await userClient.fetchUser(partnerID))
                )))
            } catch is CancellationError {
                return
            } catch let error as UserClientError {
                await send(.partnerResponse(PartnerResponse(
                    id: requestID,
                    partnerID: partnerID,
                    result: .failure(error)
                )))
            } catch {
                await send(.partnerResponse(PartnerResponse(
                    id: requestID,
                    partnerID: partnerID,
                    result: .failure(.unknown)
                )))
            }
        }
        .cancellable(id: CancelID.partnerProfile, cancelInFlight: true)
    }

    private func loadToday(coupleID: String, state: inout State) -> Effect<Action> {
        let id = uuid()
        state.dailyRequestID = id
        state.dailyErrorMessage = nil
        return .run { send in
            do {
                await send(.dailyResponse(DailyResponse(
                    id: id,
                    result: .success(try await dailyClient.getToday(coupleID))
                )))
            } catch is CancellationError {
                return
            } catch let error as DailyExperienceError {
                await send(.dailyResponse(DailyResponse(id: id, result: .failure(error))))
            } catch {
                await send(.dailyResponse(DailyResponse(id: id, result: .failure(.unknown))))
            }
        }
        .cancellable(id: CancelID.daily, cancelInFlight: true)
    }

    private func startDailyObservation(
        coupleID: String,
        experienceID: String,
        state: inout State
    ) -> Effect<Action> {
        let id = uuid()
        state.dailyObservationID = id
        return .run { send in
            do {
                for try await update in dailyClient.observeToday(coupleID, experienceID) {
                    await send(.dailyObservationEvent(DailyObservationEvent(
                        id: id,
                        result: .success(update)
                    )))
                }
            } catch is CancellationError {
                return
            } catch let error as DailyExperienceError {
                await send(.dailyObservationEvent(DailyObservationEvent(
                    id: id,
                    result: .failure(error)
                )))
            } catch {
                await send(.dailyObservationEvent(DailyObservationEvent(
                    id: id,
                    result: .failure(.unknown)
                )))
            }
        }
        .cancellable(id: CancelID.dailyObservation, cancelInFlight: true)
    }
}

extension HomeFeature.Destination.State: Equatable {}
