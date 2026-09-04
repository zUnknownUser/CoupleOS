import FirebaseFirestore
import FirebaseFunctions
import Foundation

extension MarketClient {
    static let firebase = Self(
        addItem: { coupleID, requestID, name, note, isRequest in
            // An absent note leaves the key out rather than sending a boxed
            // `nil`, which the callable serializer has no honest encoding for.
            var payload: [String: Any] = [
                "coupleId": coupleID,
                "itemId": requestID.uuidString.lowercased(),
                "name": name,
                "isRequest": isRequest,
            ]
            if let note, !note.isEmpty { payload["note"] = note }
            return try await call("addMarketItem", payload) {
                try FirebaseMarketMapper.item(from: $0)
            }
        },
        setItemStatus: { coupleID, itemID, status in
            try await call("setMarketItemStatus", [
                "coupleId": coupleID,
                "itemId": itemID,
                "status": status.rawValue,
            ]) { try FirebaseMarketMapper.item(from: $0) }
        },
        removeItem: { coupleID, itemID in
            _ = try await call("removeMarketItem", [
                "coupleId": coupleID,
                "itemId": itemID,
            ]) { _ in () }
        },
        startRun: { coupleID, requestID in
            try await call("startMarketRun", [
                "coupleId": coupleID,
                "runId": requestID.uuidString.lowercased(),
            ]) { try FirebaseMarketMapper.run(from: $0) }
        },
        finishRun: { coupleID, runID in
            try await call("finishMarketRun", [
                "coupleId": coupleID,
                "runId": runID,
            ]) { try FirebaseMarketMapper.run(from: $0) }
        },
        clearGathered: { coupleID in
            _ = try await call("clearGatheredMarketItems", [
                "coupleId": coupleID,
            ]) { _ in () }
        },
        observe: { coupleID in
            AsyncThrowingStream { continuation in
                // Items and the run live in separate collections but reach the
                // Home as one board, so the two listeners fold into one value.
                let board = MarketBoardBox()
                let itemsListener = FirestoreListenerBox()
                let runsListener = FirestoreListenerBox()
                let couple = Firestore.firestore().collection("couples").document(coupleID)

                func fail(_ error: any Error) {
                    continuation.finish(throwing: FirebaseMarketErrorMapper.map(error))
                }

                itemsListener.set(
                    couple.collection("marketItems")
                        .order(by: "requestedAt", descending: true)
                        .limit(to: 200)
                        .addSnapshotListener { snapshot, error in
                            if let error { return fail(error) }
                            guard let snapshot else { return fail(MarketClientError.unavailable) }
                            do {
                                let items = try snapshot.documents.map {
                                    try FirebaseMarketMapper.item(
                                        id: $0.documentID,
                                        coupleID: coupleID,
                                        data: $0.data()
                                    )
                                }
                                continuation.yield(board.withItems(items))
                            } catch {
                                fail(error)
                            }
                        }
                )

                runsListener.set(
                    couple.collection("marketRuns")
                        .whereField("status", isEqualTo: MarketRunStatus.active)
                        .limit(to: 1)
                        .addSnapshotListener { snapshot, error in
                            if let error { return fail(error) }
                            guard let snapshot else { return fail(MarketClientError.unavailable) }
                            do {
                                let run = try snapshot.documents.first.map {
                                    try FirebaseMarketMapper.run(
                                        id: $0.documentID,
                                        coupleID: coupleID,
                                        data: $0.data()
                                    )
                                }
                                continuation.yield(board.withRun(run))
                            } catch {
                                fail(error)
                            }
                        }
                )

                continuation.onTermination = { @Sendable _ in
                    itemsListener.remove()
                    runsListener.remove()
                }
            }
        }
    )

    private static func call<T>(
        _ name: String,
        _ payload: [String: Any],
        _ map: (Any) throws -> T
    ) async throws -> T {
        do {
            return try map(try await FirebaseCallables.call(name, data: payload).data)
        } catch {
            throw FirebaseMarketErrorMapper.map(error)
        }
    }
}

nonisolated enum MarketRunStatus {
    static let active = "active"
    static let finished = "finished"
}

/// Holds the halves of the board between two listeners that fire independently.
private nonisolated final class MarketBoardBox: @unchecked Sendable {
    private let lock = NSLock()
    private var board = MarketBoard()

    func withItems(_ items: [MarketItem]) -> MarketBoard {
        lock.lock()
        defer { lock.unlock() }
        board.items = items
        return board
    }

    func withRun(_ run: MarketRun?) -> MarketBoard {
        lock.lock()
        defer { lock.unlock() }
        board.run = run
        return board
    }
}

private nonisolated enum FirebaseMarketMapper {
    static func item(from value: Any) throws -> MarketItem {
        guard let envelope = value as? [String: Any],
              let data = envelope["item"] as? [String: Any],
              let id = data["id"] as? String,
              let coupleID = data["coupleId"] as? String else {
            throw MarketClientError.invalidData
        }
        return try item(id: id, coupleID: coupleID, data: data)
    }

    static func item(id: String, coupleID: String, data: [String: Any]) throws -> MarketItem {
        guard let name = data["name"] as? String, !name.isEmpty,
              let requestedBy = data["requestedBy"] as? String,
              let rawStatus = data["status"] as? String,
              let status = MarketItem.Status(rawValue: rawStatus),
              let requestedAt = FirebaseTimestamp.date(in: data, key: "requestedAt") else {
            throw MarketClientError.invalidData
        }

        let gatheredBy = data["gatheredBy"] as? String
        let gatheredAt = FirebaseTimestamp.date(in: data, key: "gatheredAt")
        guard status == .gathered ? gatheredBy != nil && gatheredAt != nil : true else {
            throw MarketClientError.invalidData
        }

        return MarketItem(
            id: id,
            coupleID: coupleID,
            name: name,
            note: (data["note"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            isRequest: data["isRequest"] as? Bool ?? false,
            requestedBy: requestedBy,
            requestedAt: requestedAt,
            status: status,
            gatheredBy: status == .gathered ? gatheredBy : nil,
            gatheredAt: status == .gathered ? gatheredAt : nil
        )
    }

    static func run(from value: Any) throws -> MarketRun {
        guard let envelope = value as? [String: Any],
              let data = envelope["run"] as? [String: Any],
              let id = data["id"] as? String,
              let coupleID = data["coupleId"] as? String else {
            throw MarketClientError.invalidData
        }
        return try run(id: id, coupleID: coupleID, data: data)
    }

    static func run(id: String, coupleID: String, data: [String: Any]) throws -> MarketRun {
        guard let shopperID = data["shopperId"] as? String,
              let startedAt = FirebaseTimestamp.date(in: data, key: "startedAt"),
              let status = data["status"] as? String else {
            throw MarketClientError.invalidData
        }
        let endedAt = FirebaseTimestamp.date(in: data, key: "endedAt")
        guard status == MarketRunStatus.active ? endedAt == nil : endedAt != nil else {
            throw MarketClientError.invalidData
        }

        return MarketRun(
            id: id,
            coupleID: coupleID,
            shopperID: shopperID,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

}

private nonisolated enum FirebaseMarketErrorMapper {
    static func map(_ error: any Error) -> MarketClientError {
        if let error = error as? MarketClientError { return error }
        switch FirebaseErrorClassifier.classify(error) {
        case .domain("invalid-market-item"): return .invalidInput
        case .domain("market-item-not-found"): return .itemNotFound
        case .domain("market-run-not-found"): return .runNotFound
        case .domain("not-market-shopper"): return .notShopper
        case .domain("market-run-finished"): return .runAlreadyFinished
        case .domain("market-list-full"): return .listFull
        case .domain("permission-denied"), .domain("authentication-required"): return .permissionDenied
        case .permissionDenied: return .permissionDenied
        case .networkUnavailable: return .networkUnavailable
        case .domain, .unknown: return .unknown
        }
    }
}
