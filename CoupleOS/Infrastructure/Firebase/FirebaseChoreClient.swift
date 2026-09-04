import FirebaseFirestore
import FirebaseFunctions
import Foundation

extension ChoreClient {
    static let firebase = Self(
        create: { coupleID, requestID, draft in
            var payload: [String: Any] = [
                "coupleId": coupleID,
                "choreId": requestID.uuidString.lowercased(),
                "title": draft.title,
                "rotation": draft.rotation.rawValue,
                // A one-off is `null`, which is a different thing from absent.
                "cadenceDays": draft.cadence.days as Any? ?? NSNull(),
            ]
            if let firstOwnerID = draft.firstOwnerID, draft.rotation != .anyone {
                payload["firstOwnerId"] = firstOwnerID
            }
            return try await call("createChore", payload) {
                try FirebaseChoreMapper.chore(from: $0)
            }
        },
        complete: { coupleID, choreID, expectedDueAt in
            try await call("completeChore", [
                "coupleId": coupleID,
                "choreId": choreID,
                "expectedDueAtMillis": Int(expectedDueAt.timeIntervalSince1970 * 1_000),
            ]) { try FirebaseChoreMapper.chore(from: $0) }
        },
        remove: { coupleID, choreID in
            _ = try await call("removeChore", [
                "coupleId": coupleID,
                "choreId": choreID,
            ]) { _ in () }
        },
        observe: { coupleID in
            AsyncThrowingStream { continuation in
                let listener = FirestoreListenerBox()
                let registration = Firestore.firestore()
                    .collection("couples")
                    .document(coupleID)
                    .collection("chores")
                    .order(by: "dueAt")
                    .limit(to: 100)
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            continuation.finish(throwing: FirebaseChoreErrorMapper.map(error))
                            return
                        }
                        guard let snapshot else {
                            continuation.finish(throwing: ChoreClientError.unavailable)
                            return
                        }
                        do {
                            continuation.yield(try snapshot.documents.map {
                                try FirebaseChoreMapper.chore(
                                    id: $0.documentID,
                                    coupleID: coupleID,
                                    data: $0.data()
                                )
                            })
                        } catch {
                            continuation.finish(throwing: FirebaseChoreErrorMapper.map(error))
                        }
                    }
                listener.set(registration)
                continuation.onTermination = { @Sendable _ in listener.remove() }
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
            throw FirebaseChoreErrorMapper.map(error)
        }
    }
}

private nonisolated enum FirebaseChoreMapper {
    static func chore(from value: Any) throws -> Chore {
        guard let envelope = value as? [String: Any],
              let data = envelope["chore"] as? [String: Any],
              let id = data["id"] as? String,
              let coupleID = data["coupleId"] as? String else {
            throw ChoreClientError.invalidData
        }
        return try chore(id: id, coupleID: coupleID, data: data)
    }

    static func chore(id: String, coupleID: String, data: [String: Any]) throws -> Chore {
        guard let title = data["title"] as? String, !title.isEmpty,
              let rawRotation = data["rotation"] as? String,
              let rotation = Chore.Rotation(rawValue: rawRotation),
              let rawStatus = data["status"] as? String,
              let status = Chore.Status(rawValue: rawStatus),
              let dueAt = FirebaseTimestamp.date(in: data, key: "dueAt"),
              let createdBy = data["createdBy"] as? String,
              let createdAt = FirebaseTimestamp.date(in: data, key: "createdAt") else {
            throw ChoreClientError.invalidData
        }

        let cadenceDays = FirebaseTimestamp.integer(data["cadenceDays"])
        let ownerID = data["ownerId"] as? String
        // A turn that belongs to nobody only makes sense when nobody was meant
        // to hold it; anything else is a document we should not trust.
        guard rotation == .anyone || ownerID != nil else {
            throw ChoreClientError.invalidData
        }
        guard cadenceDays.map({ $0 >= 1 && $0 <= 365 }) ?? true else {
            throw ChoreClientError.invalidData
        }

        return Chore(
            id: id,
            coupleID: coupleID,
            title: title,
            cadence: cadenceDays.map(Chore.Cadence.everyDays) ?? .once,
            rotation: rotation,
            ownerID: rotation == .anyone ? nil : ownerID,
            status: status,
            dueAt: dueAt,
            lastDoneBy: data["lastDoneBy"] as? String,
            lastDoneAt: FirebaseTimestamp.date(in: data, key: "lastDoneAt"),
            createdBy: createdBy,
            createdAt: createdAt
        )
    }
}

private nonisolated enum FirebaseChoreErrorMapper {
    static func map(_ error: any Error) -> ChoreClientError {
        if let error = error as? ChoreClientError { return error }
        switch FirebaseErrorClassifier.classify(error) {
        case .domain("invalid-chore"): return .invalidInput
        case .domain("chore-not-found"): return .notFound
        case .domain("not-chore-owner"): return .notYourTurn
        case .domain("chore-already-done"): return .alreadyDone
        case .domain("chore-list-full"): return .listFull
        case .domain("permission-denied"), .domain("authentication-required"): return .permissionDenied
        case .permissionDenied: return .permissionDenied
        case .networkUnavailable: return .networkUnavailable
        case .domain, .unknown: return .unknown
        }
    }
}
