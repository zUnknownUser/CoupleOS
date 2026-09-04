import FirebaseFirestore
import FirebaseFunctions
import Foundation

extension DecisionClient {
    static let firebase = Self(
        create: { coupleID, requestID, title, options in
            do {
                let result = try await FirebaseCallables.functions
                    .httpsCallable("createDecision")
                    .call([
                        "coupleId": coupleID,
                        "decisionId": requestID.uuidString.lowercased(),
                        "title": title,
                        "options": options,
                    ])
                return try FirebaseDecisionMapper.decision(from: result.data)
            } catch {
                throw FirebaseDecisionErrorMapper.map(error)
            }
        },
        resolve: { coupleID, decisionID, optionIndex in
            do {
                let result = try await FirebaseCallables.functions
                    .httpsCallable("resolveDecision")
                    .call([
                        "coupleId": coupleID,
                        "decisionId": decisionID,
                        "optionIndex": optionIndex,
                    ])
                return try FirebaseDecisionMapper.decision(from: result.data)
            } catch {
                throw FirebaseDecisionErrorMapper.map(error)
            }
        },
        observe: { coupleID in
            AsyncThrowingStream { continuation in
                let listener = FirestoreListenerBox()
                let registration = Firestore.firestore()
                    .collection("couples")
                    .document(coupleID)
                    .collection("decisions")
                    .order(by: "createdAt", descending: true)
                    .limit(to: 50)
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            continuation.finish(throwing: FirebaseDecisionErrorMapper.map(error))
                            return
                        }
                        guard let snapshot else {
                            continuation.finish(throwing: DecisionClientError.unavailable)
                            return
                        }
                        do {
                            continuation.yield(try snapshot.documents.map {
                                try FirebaseDecisionMapper.decision(
                                    id: $0.documentID,
                                    coupleID: coupleID,
                                    data: $0.data()
                                )
                            })
                        } catch {
                            continuation.finish(throwing: FirebaseDecisionErrorMapper.map(error))
                        }
                    }
                listener.set(registration)
                continuation.onTermination = { @Sendable _ in listener.remove() }
            }
        }
    )
}

private nonisolated enum FirebaseDecisionMapper {
    static func decision(from value: Any) throws -> Decision {
        guard let envelope = value as? [String: Any],
              let data = envelope["decision"] as? [String: Any],
              let id = data["id"] as? String,
              let coupleID = data["coupleId"] as? String else {
            throw DecisionClientError.invalidData
        }
        return try decision(id: id, coupleID: coupleID, data: data)
    }

    static func decision(
        id: String,
        coupleID: String,
        data: [String: Any]
    ) throws -> Decision {
        guard let title = data["title"] as? String,
              let options = data["options"] as? [String],
              let creatorID = data["creatorId"] as? String,
              let responderID = data["responderId"] as? String,
              let rawStatus = data["status"] as? String,
              let status = Decision.Status(rawValue: rawStatus),
              let createdAt = FirebaseTimestamp.date(in: data, key: "createdAt") else {
            throw DecisionClientError.invalidData
        }

        let selectedOptionIndex = FirebaseTimestamp.integer(data["selectedOptionIndex"])
        let resolvedAt = FirebaseTimestamp.date(in: data, key: "resolvedAt")
        guard !title.isEmpty,
              options.count >= 2,
              creatorID != responderID,
              status == .waitingForPartner
                ? selectedOptionIndex == nil && resolvedAt == nil
                : selectedOptionIndex.map(options.indices.contains) == true && resolvedAt != nil else {
            throw DecisionClientError.invalidData
        }

        return Decision(
            id: id,
            coupleID: coupleID,
            title: title,
            options: options,
            creatorID: creatorID,
            responderID: responderID,
            status: status,
            createdAt: createdAt,
            selectedOptionIndex: selectedOptionIndex,
            resolvedAt: resolvedAt
        )
    }

}

private nonisolated enum FirebaseDecisionErrorMapper {
    static func map(_ error: any Error) -> DecisionClientError {
        if let error = error as? DecisionClientError { return error }
        switch FirebaseErrorClassifier.classify(error) {
        case .domain("invalid-decision"): return .invalidInput
        case .domain("decision-not-found"): return .notFound
        case .domain("not-decision-responder"): return .notResponder
        case .domain("decision-already-resolved"): return .alreadyResolved
        case .domain("permission-denied"), .domain("authentication-required"): return .permissionDenied
        case .permissionDenied: return .permissionDenied
        case .networkUnavailable: return .networkUnavailable
        case .domain, .unknown: return .unknown
        }
    }
}
