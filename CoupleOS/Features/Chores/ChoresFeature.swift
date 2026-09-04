import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct ChoresFeature {
    @ObservableState
    struct State: Equatable {
        var phase: Phase = .idle
        var coupleID: String?
        var currentUserID: String?
        var partnerID: String?
        var observationID: UUID?
        var chores: [Chore] = []
        var draftTitle = ""
        var draftCadence: DraftCadence = .everyDays(7)
        var draftRotation: Chore.Rotation = .alternates
        var draftStartsWithMe = true
        var isCreating = false
        /// Chores with a completion in flight, held per id so one row settling
        /// never blocks another.
        var settlingChoreIDs: Set<String> = []
        var error: ChoreClientError?

        var active: [Chore] { chores.filter { $0.status == .active } }

        var trimmedDraft: String {
            draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canSubmitDraft: Bool { !trimmedDraft.isEmpty && !isCreating }

        func mine(asOf now: Date) -> [Chore] {
            guard let currentUserID else { return [] }
            return active
                .filter { $0.needsMe(currentUserID, asOf: now) }
                .sorted { $0.dueAt < $1.dueAt }
        }

        func theirs(asOf now: Date) -> [Chore] {
            guard let currentUserID else { return [] }
            return active
                .filter { $0.isWaitingOnPartner(currentUserID) && !$0.needsMe(currentUserID, asOf: now) }
                .sorted { $0.dueAt < $1.dueAt }
        }

        func upcoming(asOf now: Date) -> [Chore] {
            guard let currentUserID else { return [] }
            return active
                .filter { chore in
                    !chore.needsMe(currentUserID, asOf: now)
                        && !chore.isWaitingOnPartner(currentUserID)
                }
                .sorted { $0.dueAt < $1.dueAt }
        }

        /// The draft as the domain understands it.
        func draft(currentUserID: String?) -> ChoreDraft {
            ChoreDraft(
                title: trimmedDraft,
                cadence: draftCadence.cadence,
                rotation: draftRotation,
                firstOwnerID: draftStartsWithMe ? currentUserID : partnerID
            )
        }
    }

    /// The cadences worth offering. A free-form number of days is a setting
    /// nobody wants to fill in for "the dishes".
    enum DraftCadence: Equatable, Hashable, CaseIterable {
        case once
        case daily
        case everyDays(Int)

        static var allCases: [DraftCadence] {
            [.once, .daily, .everyDays(3), .everyDays(7), .everyDays(14), .everyDays(30)]
        }

        var cadence: Chore.Cadence {
            switch self {
            case .once: .once
            case .daily: .everyDays(1)
            case let .everyDays(days): .everyDays(days)
            }
        }
    }

    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case error(ChoreClientError)
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case coupleAvailable(coupleID: String, currentUserID: String, partnerID: String)
        case stop
        case retryTapped
        case dismissErrorTapped
        case observationEvent(ObservationEvent)
        case createTapped
        case completeTapped(String)
        case removeTapped(String)
        case createResponse(Result<Chore, ChoreClientError>)
        case completeResponse(id: String, Result<Chore, ChoreClientError>)
        case removeResponse(id: String, error: ChoreClientError?)
    }

    struct ObservationEvent: Equatable, Sendable {
        let id: UUID
        let coupleID: String
        let result: Result<[Chore], ChoreClientError>
    }

    @Dependency(\.choreClient) var choreClient
    @Dependency(\.uuid) var uuid

    private enum CancelID { case observation }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .coupleAvailable(coupleID, currentUserID, partnerID):
                guard state.coupleID != coupleID
                        || state.currentUserID != currentUserID
                        || state.partnerID != partnerID
                        || state.observationID == nil else { return .none }
                state.coupleID = coupleID
                state.currentUserID = currentUserID
                state.partnerID = partnerID
                state.phase = .loading
                state.error = nil
                return startObservation(coupleID: coupleID, state: &state)

            case .stop:
                state = State()
                return .cancel(id: CancelID.observation)

            case .retryTapped:
                guard let coupleID = state.coupleID else { return .none }
                state.phase = .loading
                state.error = nil
                return startObservation(coupleID: coupleID, state: &state)

            case .dismissErrorTapped:
                state.error = nil
                return .none

            case let .observationEvent(event):
                guard state.observationID == event.id,
                      state.coupleID == event.coupleID else { return .none }
                switch event.result {
                case let .success(chores):
                    state.phase = .ready
                    state.chores = chores.filter { $0.coupleID == event.coupleID }
                case let .failure(error):
                    state.observationID = nil
                    state.phase = .error(error)
                }
                return .none

            case .createTapped:
                return create(state: &state)

            case let .completeTapped(id):
                return complete(id: id, state: &state)

            case let .removeTapped(id):
                return remove(id: id, state: &state)

            case let .createResponse(result):
                state.isCreating = false
                switch result {
                case let .success(chore):
                    upsert(chore, state: &state)
                case let .failure(error):
                    state.error = error
                }
                return .none

            case let .completeResponse(id, result):
                state.settlingChoreIDs.remove(id)
                switch result {
                case let .success(chore):
                    upsert(chore, state: &state)
                case let .failure(error):
                    state.error = error
                }
                return .none

            case let .removeResponse(id, error):
                state.settlingChoreIDs.remove(id)
                if let error {
                    state.error = error
                } else {
                    state.chores.removeAll { $0.id == id }
                }
                return .none
            }
        }
    }

    private func create(state: inout State) -> Effect<Action> {
        let draft = state.draft(currentUserID: state.currentUserID)
        guard let coupleID = state.coupleID, draft.isValid, !state.isCreating else {
            return .none
        }
        let requestID = uuid()
        state.isCreating = true
        state.error = nil
        state.draftTitle = ""

        return .run { send in
            guard let result = await settled({
                try await choreClient.create(coupleID, requestID, draft)
            }) else { return }
            await send(.createResponse(result))
        }
    }

    private func complete(id: String, state: inout State) -> Effect<Action> {
        guard let coupleID = state.coupleID,
              let chore = state.chores.first(where: { $0.id == id }),
              chore.status == .active,
              !state.settlingChoreIDs.contains(id) else { return .none }
        // The cycle the tap meant. If the other person finishes it first, the
        // backend answers with the chore as it now stands instead of burning a
        // second cycle.
        let expectedDueAt = chore.dueAt
        state.settlingChoreIDs.insert(id)
        state.error = nil

        return .run { send in
            guard let result = await settled({
                try await choreClient.complete(coupleID, id, expectedDueAt)
            }) else { return }
            await send(.completeResponse(id: id, result))
        }
    }

    private func remove(id: String, state: inout State) -> Effect<Action> {
        guard let coupleID = state.coupleID, !state.settlingChoreIDs.contains(id) else {
            return .none
        }
        state.settlingChoreIDs.insert(id)
        state.error = nil

        return .run { send in
            guard let result = await settled({
                try await choreClient.remove(coupleID, id)
            }) else { return }
            await send(.removeResponse(id: id, error: result.failure))
        }
    }

    private func startObservation(coupleID: String, state: inout State) -> Effect<Action> {
        let observationID = uuid()
        state.observationID = observationID
        return .run { send in
            do {
                for try await chores in choreClient.observe(coupleID) {
                    await send(.observationEvent(ObservationEvent(
                        id: observationID,
                        coupleID: coupleID,
                        result: .success(chores)
                    )))
                }
            } catch is CancellationError {
                return
            } catch {
                await send(.observationEvent(ObservationEvent(
                    id: observationID,
                    coupleID: coupleID,
                    result: .failure(error.asChoreError)
                )))
            }
        }
        .cancellable(id: CancelID.observation, cancelInFlight: true)
    }

    private func upsert(_ chore: Chore, state: inout State) {
        guard chore.coupleID == state.coupleID else { return }
        state.chores.removeAll { $0.id == chore.id }
        state.chores.append(chore)
        state.chores.sort { $0.dueAt < $1.dueAt }
    }
}

/// Runs one chore call, mapping every failure into the module's error type.
/// `nil` means the effect was cancelled and must settle nothing.
private func settled<T>(
    _ operation: () async throws -> T
) async -> Result<T, ChoreClientError>? {
    do {
        return .success(try await operation())
    } catch is CancellationError {
        return nil
    } catch {
        return .failure(error.asChoreError)
    }
}

private extension Result {
    var failure: Failure? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

private extension Error {
    var asChoreError: ChoreClientError {
        self as? ChoreClientError ?? .unknown
    }
}
