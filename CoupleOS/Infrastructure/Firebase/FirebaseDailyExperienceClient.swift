import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

extension DailyExperienceClient {
    static let firebase = Self(
        getToday: { coupleID in
            do {
                let result = try await FirebaseCallables.call("getToday")
                return try FirebaseDailyMapper.experience(from: result.data)
            } catch { throw FirebaseDailyErrorMapper.map(error) }
        },
        submitAnswer: { coupleID, experienceID, optionIndex in
            do {
                let result = try await FirebaseCallables.call("submitTodayAnswer", data: [
                    "coupleId": coupleID,
                    "experienceId": experienceID,
                    "optionIndex": optionIndex
                ])
                return try FirebaseDailyMapper.experience(from: result.data)
            } catch { throw FirebaseDailyErrorMapper.map(error) }
        },
        observeToday: { coupleID, experienceID in
            AsyncThrowingStream { continuation in
                let listener = FirestoreListenerBox()
                let registration = Firestore.firestore()
                    .collection("couples").document(coupleID)
                    .collection("daily").document(experienceID)
                    .addSnapshotListener { snapshot, error in
                        if let error { continuation.finish(throwing: FirebaseDailyErrorMapper.map(error)); return }
                        guard let snapshot, snapshot.exists else {
                            continuation.finish(throwing: DailyExperienceError.notFound); return
                        }
                        do { continuation.yield(try FirebaseDailyMapper.experience(id: snapshot.documentID, data: snapshot.data() ?? [:])) }
                        catch { continuation.finish(throwing: error) }
                    }
                listener.set(registration)
                continuation.onTermination = { @Sendable _ in listener.remove() }
            }
        }
    )
}

private nonisolated enum FirebaseDailyMapper {
    static func experience(from value: Any) throws -> DailyExperience {
        guard let envelope = value as? [String: Any], let data = envelope["experience"] as? [String: Any], let id = data["id"] as? String else { throw DailyExperienceError.invalidData }
        return try experience(id: id, data: data)
    }

    static func experience(id: String, data: [String: Any]) throws -> DailyExperience {
        guard let periodKey = data["periodKey"] as? String,
              let prompt = data["prompt"] as? String,
              let options = data["options"] as? [String],
              let answered = data["answeredUserIds"] as? [String] else { throw DailyExperienceError.invalidData }
        let revealed: [String: Int]?
        if let raw = data["revealedAnswers"] as? [String: Any] {
            revealed = Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                guard let number = value as? NSNumber else { return nil }
                return (key, number.intValue)
            })
        } else { revealed = nil }
        return DailyExperience(id: id, periodKey: periodKey, prompt: prompt, options: options, answeredUserIDs: Set(answered), revealedAnswers: revealed)
    }
}

private nonisolated enum FirebaseDailyErrorMapper {
    static func map(_ error: Error) -> DailyExperienceError {
        if let error = error as? DailyExperienceError { return error }
        let nsError = error as NSError
        if let details = nsError.userInfo[FunctionsErrorDetailsKey] as? [String: Any],
           let code = details["domainCode"] as? String {
            switch code {
            case "already-answered": return .alreadyAnswered
            case "daily-not-found": return .notFound
            case "permission-denied": return .permissionDenied
            default: break
            }
        }
        if nsError.domain == NSURLErrorDomain { return .networkUnavailable }
        if nsError.domain == FunctionsErrorDomain {
            switch FunctionsErrorCode(rawValue: nsError.code) {
            case .permissionDenied, .unauthenticated: return .permissionDenied
            case .unavailable, .deadlineExceeded: return .networkUnavailable
            default: break
            }
        }
        return .unknown
    }
}
