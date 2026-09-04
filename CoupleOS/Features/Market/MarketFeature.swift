import ComposableArchitecture
import Foundation

@Reducer
nonisolated struct MarketFeature {
    @ObservableState
    struct State: Equatable {
        var phase: Phase = .idle
        var coupleID: String?
        var currentUserID: String?
        var partnerID: String?
        var observationID: UUID?
        var board = MarketBoard()
        var draftName = ""
        var draftIsRequest = false
        /// Items with a change in flight, held per id so two quick taps on
        /// different rows never disable each other.
        var settlingItemIDs: Set<String> = []
        var isAddingItem = false
        var isChangingRun = false
        var isClearingBasket = false
        var error: MarketClientError?

        var items: [MarketItem] { board.items }

        /// Asks come first: they are the ones with a person behind them.
        var pending: [MarketItem] {
            items.filter(\.isPending).sorted { first, second in
                first.isRequest == second.isRequest
                    ? first.requestedAt > second.requestedAt
                    : first.isRequest
            }
        }

        var gathered: [MarketItem] {
            items.filter { !$0.isPending }
                .sorted { ($0.gatheredAt ?? $0.requestedAt) > ($1.gatheredAt ?? $1.requestedAt) }
        }

        /// Open asks that came from the other person.
        var requestsForMe: [MarketItem] {
            guard let currentUserID else { return [] }
            return pending.filter { $0.isRequest(for: currentUserID) }
        }

        var activeRun: MarketRun? {
            board.run.flatMap { $0.isActive ? $0 : nil }
        }

        var myRun: MarketRun? {
            guard let currentUserID, let run = activeRun, run.isMine(currentUserID) else {
                return nil
            }
            return run
        }

        var partnerRun: MarketRun? {
            guard let currentUserID, let run = activeRun, !run.isMine(currentUserID) else {
                return nil
            }
            return run
        }

        var trimmedDraft: String {
            draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canSubmitDraft: Bool { !trimmedDraft.isEmpty && !isAddingItem }

        /// Offered only when there is something to clear and no run to do it:
        /// finishing a run already empties the basket.
        var canClearBasket: Bool {
            !gathered.isEmpty && activeRun == nil && !isClearingBasket
        }

        func stale(asOf now: Date) -> [MarketItem] {
            pending.filter { $0.isStale(asOf: now) }
        }
    }

    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case error(MarketClientError)
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case coupleAvailable(coupleID: String, currentUserID: String, partnerID: String)
        case stop
        case retryTapped
        case dismissErrorTapped
        case observationEvent(ObservationEvent)
        case addItemTapped
        case itemTapped(String)
        case removeItemTapped(String)
        case runButtonTapped
        case clearBasketTapped
        /// `id` is `nil` for an item that did not exist yet.
        case itemResponse(id: String?, Result<MarketItem, MarketClientError>)
        case removeResponse(id: String, error: MarketClientError?)
        case clearBasketResponse(MarketClientError?)
        case runResponse(Result<MarketRun, MarketClientError>)
    }

    struct ObservationEvent: Equatable, Sendable {
        let id: UUID
        let coupleID: String
        let result: Result<MarketBoard, MarketClientError>
    }

    @Dependency(\.marketClient) var marketClient
    @Dependency(\.uuid) var uuid

    private enum CancelID {
        case observation
        case run
    }

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
                return .merge(
                    .cancel(id: CancelID.observation),
                    .cancel(id: CancelID.run)
                )

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
                case let .success(board):
                    state.phase = .ready
                    state.board = MarketBoard(
                        items: board.items.filter { $0.coupleID == event.coupleID },
                        run: board.run.flatMap { $0.coupleID == event.coupleID ? $0 : nil }
                    )
                case let .failure(error):
                    state.observationID = nil
                    state.phase = .error(error)
                }
                return .none

            case .addItemTapped:
                return addItem(state: &state)

            case let .itemTapped(id):
                return toggle(id: id, state: &state)

            case let .removeItemTapped(id):
                return remove(id: id, state: &state)

            case .runButtonTapped:
                return changeRun(state: &state)

            case .clearBasketTapped:
                guard let coupleID = state.coupleID, !state.isClearingBasket else {
                    return .none
                }
                state.isClearingBasket = true
                state.error = nil
                return .run { send in
                    guard let result = await settled({
                        try await marketClient.clearGathered(coupleID)
                    }) else { return }
                    await send(.clearBasketResponse(result.failure))
                }

            case let .clearBasketResponse(error):
                state.isClearingBasket = false
                if let error {
                    state.error = error
                } else {
                    // The listener confirms this too, but dropping them now
                    // keeps the basket from lingering for a whole round trip.
                    state.board.items.removeAll { !$0.isPending }
                }
                return .none

            case let .itemResponse(id, result):
                if let id { state.settlingItemIDs.remove(id) } else { state.isAddingItem = false }
                switch result {
                case let .success(item):
                    upsert(item, state: &state)
                case let .failure(error):
                    state.error = error
                }
                return .none

            case let .removeResponse(id, error):
                state.settlingItemIDs.remove(id)
                if let error {
                    state.error = error
                } else {
                    state.board.items.removeAll { $0.id == id }
                }
                return .none

            case let .runResponse(result):
                state.isChangingRun = false
                switch result {
                case let .success(run):
                    guard run.coupleID == state.coupleID else { return .none }
                    state.board.run = run.isActive ? run : nil
                case let .failure(error):
                    state.error = error
                }
                return .none
            }
        }
    }

    private func addItem(state: inout State) -> Effect<Action> {
        let name = state.trimmedDraft
        guard let coupleID = state.coupleID, !name.isEmpty, !state.isAddingItem else {
            return .none
        }
        let requestID = uuid()
        let isRequest = state.draftIsRequest
        state.isAddingItem = true
        state.error = nil
        // Cleared now rather than on success: the field has to be ready for the
        // next thing they remember, which is usually immediately.
        state.draftName = ""
        state.draftIsRequest = false

        return .run { send in
            guard let result = await settled({
                try await marketClient.addItem(coupleID, requestID, name, nil, isRequest)
            }) else { return }
            await send(.itemResponse(id: nil, result))
        }
    }

    private func toggle(id: String, state: inout State) -> Effect<Action> {
        guard let coupleID = state.coupleID,
              let item = state.items.first(where: { $0.id == id }),
              !state.settlingItemIDs.contains(id) else { return .none }
        let status: MarketItem.Status = item.isPending ? .gathered : .pending
        state.settlingItemIDs.insert(id)
        state.error = nil

        return .run { send in
            guard let result = await settled({
                try await marketClient.setItemStatus(coupleID, id, status)
            }) else { return }
            await send(.itemResponse(id: id, result))
        }
    }

    private func remove(id: String, state: inout State) -> Effect<Action> {
        guard let coupleID = state.coupleID, !state.settlingItemIDs.contains(id) else {
            return .none
        }
        state.settlingItemIDs.insert(id)
        state.error = nil

        return .run { send in
            guard let result = await settled({
                try await marketClient.removeItem(coupleID, id)
            }) else { return }
            await send(.removeResponse(id: id, error: result.failure))
        }
    }

    private func changeRun(state: inout State) -> Effect<Action> {
        guard let coupleID = state.coupleID, !state.isChangingRun else { return .none }
        let run = state.myRun
        state.isChangingRun = true
        state.error = nil
        let requestID = uuid()

        return .run { send in
            guard let result = await settled({
                if let run {
                    try await marketClient.finishRun(coupleID, run.id)
                } else {
                    try await marketClient.startRun(coupleID, requestID)
                }
            }) else { return }
            await send(.runResponse(result))
        }
        .cancellable(id: CancelID.run, cancelInFlight: true)
    }

    private func startObservation(coupleID: String, state: inout State) -> Effect<Action> {
        let observationID = uuid()
        state.observationID = observationID
        return .run { send in
            do {
                for try await board in marketClient.observe(coupleID) {
                    await send(.observationEvent(ObservationEvent(
                        id: observationID,
                        coupleID: coupleID,
                        result: .success(board)
                    )))
                }
            } catch is CancellationError {
                return
            } catch {
                await send(.observationEvent(ObservationEvent(
                    id: observationID,
                    coupleID: coupleID,
                    result: .failure(error.asMarketError)
                )))
            }
        }
        .cancellable(id: CancelID.observation, cancelInFlight: true)
    }

    private func upsert(_ item: MarketItem, state: inout State) {
        guard item.coupleID == state.coupleID else { return }
        state.board.items.removeAll { $0.id == item.id }
        state.board.items.append(item)
    }
}

/// Runs one market call, mapping every failure into the module's error type.
///
/// Returns `nil` when the effect was cancelled, which is the one outcome that
/// must not reach the reducer: the state it would settle no longer exists.
private func settled<T>(
    _ operation: () async throws -> T
) async -> Result<T, MarketClientError>? {
    do {
        return .success(try await operation())
    } catch is CancellationError {
        return nil
    } catch {
        return .failure(error.asMarketError)
    }
}

private extension Result {
    var failure: Failure? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

private extension Error {
    var asMarketError: MarketClientError {
        self as? MarketClientError ?? .unknown
    }
}
