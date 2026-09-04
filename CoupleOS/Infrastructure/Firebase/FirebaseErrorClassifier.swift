import FirebaseFirestore
import FirebaseFunctions
import Foundation

/// How a Firebase call failed, said once and without reference to any feature.
///
/// Every module used to carry its own copy of this ladder — the same domains,
/// the same codes, three times over. Three copies of a rule is three chances
/// for them to drift, and the drift would be silent: an error quietly landing
/// in the wrong bucket reads as a mystery, not as a bug.
nonisolated enum FirebaseFailure: Equatable, Sendable {
    /// The backend named the reason itself.
    case domain(String)
    case networkUnavailable
    case permissionDenied
    case unknown
}

nonisolated enum FirebaseErrorClassifier {
    static func classify(_ error: any Error) -> FirebaseFailure {
        if let code = domainCode(error) { return .domain(code) }

        let value = error as NSError
        if value.domain == NSURLErrorDomain { return .networkUnavailable }

        if value.domain == FunctionsErrorDomain,
           let code = FunctionsErrorCode(rawValue: value.code) {
            switch code {
            case .unavailable, .deadlineExceeded, .cancelled: return .networkUnavailable
            case .permissionDenied, .unauthenticated: return .permissionDenied
            default: return .unknown
            }
        }

        if value.domain == FirestoreErrorDomain,
           let code = FirestoreErrorCode.Code(rawValue: value.code) {
            switch code {
            case .unavailable, .deadlineExceeded: return .networkUnavailable
            case .permissionDenied, .unauthenticated: return .permissionDenied
            default: return .unknown
            }
        }

        return .unknown
    }

    /// The `domainCode` a callable attaches when it refuses for a reason the
    /// product has a name for.
    private static func domainCode(_ error: any Error) -> String? {
        let details = (error as NSError).userInfo[FunctionsErrorDetailsKey] as? [String: Any]
        return details?["domainCode"] as? String
    }
}

/// Timestamps arrive either as a Firestore `Timestamp` or, from a callable, as
/// milliseconds under a `…Millis` key. Both shapes, decoded in one place.
nonisolated enum FirebaseTimestamp {
    static func date(in data: [String: Any], key: String) -> Date? {
        if let timestamp = data[key] as? Timestamp { return timestamp.dateValue() }
        guard let milliseconds = number(data["\(key)Millis"]) else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1_000)
    }

    static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        return value as? Int
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return value as? Double
    }
}
