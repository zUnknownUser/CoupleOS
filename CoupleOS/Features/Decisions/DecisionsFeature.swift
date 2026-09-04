import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct DecisionsFeature {
    @Reducer
    nonisolated enum Destination {
        case create(CreateDecisionFeature)
        case detail(DecisionDetailFeature)
    }

    @ObservableState
    struct State: Equatable {
        var phase: Phase = .idle
        var coupleID: String?
        var currentUserID: String?
        var partnerID: String?
        var observationID: UUID?
        @Presents var destination: Destination.State?

        var decisions: [Decision] {
            guard case let .loaded(decisions) = phase else { return [] }
            return decisions
        }

        var needsMyResponse: [Decision] {
            decisions.filter { $0.participation(for: currentUserID ?? "") == .needsMyResponse }
        }

        var waitingForPartner: [Decision] {
            decisions.filter { $0.participation(for: currentUserID ?? "") == .waitingForPartner }
        }

        var recent: [Decision] {
            decisions
                .filter { $0.status == .resolved }
                .sorted { ($0.resolvedAt ?? $0.createdAt) > ($1.resolvedAt ?? $1.createdAt) }
        }
    }

    enum Phase: Equatable {
        case idle
        case loading
        case loaded([Decision])
        case error(DecisionClientError)
    }

    enum Action {
        case coupleAvailable(coupleID: String, currentUserID: String, partnerID: String)
        case stop
        case retryTapped
        case createTapped
        case decisionTapped(String)
        case observationEvent(ObservationEvent)
        case destination(PresentationAction<Destination.Action>)
    }

    struct ObservationEvent: Equatable, Sendable {
        let id: UUID
        let coupleID: String
        let result: Result<[Decision], DecisionClientError>
    }

    @Dependency(\.decisionClient) var decisionClient
    @Dependency(\.uuid) var uuid

    private enum CancelID {
        case observation
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .coupleAvailable(coupleID, currentUserID, partnerID):
                guard state.coupleID != coupleID
                        || state.currentUserID != currentUserID
                        || state.partnerID != partnerID
                        || state.observationID == nil else { return .none }
                state.coupleID = coupleID
                state.currentUserID = currentUserID
                state.partnerID = partnerID
                state.destination = nil
                state.phase = .loading
                return startObservation(coupleID: coupleID, state: &state)

            case .stop:
                state = State()
                return .cancel(id: CancelID.observation)

            case .retryTapped:
                guard let coupleID = state.coupleID else { return .none }
                state.phase = .loading
                return startObservation(coupleID: coupleID, state: &state)

            case .createTapped:
                guard let coupleID = state.coupleID,
                      let currentUserID = state.currentUserID,
                      let partnerID = state.partnerID else { return .none }
                state.destination = .create(CreateDecisionFeature.State(
                    coupleID: coupleID,
                    currentUserID: currentUserID,
                    partnerID: partnerID
                ))
                return .none

            case let .decisionTapped(id):
                guard let decision = state.decisions.first(where: { $0.id == id }),
                      let currentUserID = state.currentUserID else { return .none }
                state.destination = .detail(DecisionDetailFeature.State(
                    decision: decision,
                    currentUserID: currentUserID
                ))
                return .none

            case let .observationEvent(event):
                guard state.observationID == event.id,
                      state.coupleID == event.coupleID else { return .none }
                switch event.result {
                case let .success(decisions):
                    let valid = decisions.filter { $0.coupleID == event.coupleID }
                    state.phase = .loaded(valid)
                    guard case let .detail(detail) = state.destination,
                          let openDecisionID = detail.decision?.id else { return .none }
                    let updated = valid.first(where: { $0.id == openDecisionID })
                    return .send(.destination(.presented(.detail(.decisionUpdated(updated)))))
                case let .failure(error):
                    state.observationID = nil
                    state.phase = .error(error)
                    return .none
                }

            case let .destination(.presented(.create(.response(.success(decision))))):
                upsert(decision, state: &state)
                return .none

            case let .destination(.presented(.detail(.response(.success(decision))))):
                upsert(decision, state: &state)
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func startObservation(coupleID: String, state: inout State) -> Effect<Action> {
        let observationID = uuid()
        state.observationID = observationID
        return .run { send in
            do {
                for try await decisions in decisionClient.observe(coupleID) {
                    await send(.observationEvent(ObservationEvent(
                        id: observationID,
                        coupleID: coupleID,
                        result: .success(decisions)
                    )))
                }
            } catch is CancellationError {
                return
            } catch let error as DecisionClientError {
                await send(.observationEvent(ObservationEvent(
                    id: observationID,
                    coupleID: coupleID,
                    result: .failure(error)
                )))
            } catch {
                await send(.observationEvent(ObservationEvent(
                    id: observationID,
                    coupleID: coupleID,
                    result: .failure(.unknown)
                )))
            }
        }
        .cancellable(id: CancelID.observation, cancelInFlight: true)
    }

    private func upsert(_ decision: Decision, state: inout State) {
        guard decision.coupleID == state.coupleID else { return }
        var decisions = state.decisions
        decisions.removeAll { $0.id == decision.id }
        decisions.append(decision)
        decisions.sort { $0.createdAt > $1.createdAt }
        state.phase = .loaded(decisions)
    }
}

extension DecisionsFeature.Destination.State: Equatable {}
