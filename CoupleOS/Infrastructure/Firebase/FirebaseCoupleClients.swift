import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import Foundation

extension CoupleClient {
    static let firebase = Self(
        createCouple: {
            do {
                let result = try await FirebaseCallables.functions
                    .httpsCallable("createCouple")
                    .call(["timeZone": TimeZone.current.identifier])
                return try FirebaseCoupleMapper.couple(from: result.data)
            } catch {
#if DEBUG
                let diagnostic = error as NSError
                print("CREATE_COUPLE_ERROR domain=\(diagnostic.domain) code=\(diagnostic.code)")
#endif
                throw FirebaseDomainErrorMapper.couple(error)
            }
        },
        fetchCurrentCouple: {
            guard let userID = Auth.auth().currentUser?.uid else {
                throw CoupleClientError.permissionDenied
            }
            do {
                let user = try await Firestore.firestore().collection("users").document(userID)
                    .getDocument(source: .server)
                guard let coupleID = user.get("activeCoupleId") as? String else { return nil }
                let snapshot = try await Firestore.firestore().collection("couples").document(coupleID)
                    .getDocument(source: .server)
                guard snapshot.exists else { throw CoupleClientError.coupleNotFound }
                return try FirebaseCoupleMapper.couple(id: snapshot.documentID, data: snapshot.data() ?? [:])
            } catch {
                throw FirebaseDomainErrorMapper.couple(error)
            }
        },
        observeCouple: { id in
            AsyncThrowingStream { continuation in
                let listener = FirestoreListenerBox()
                let registration = Firestore.firestore().collection("couples").document(id)
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            continuation.finish(throwing: FirebaseDomainErrorMapper.couple(error))
                            return
                        }
                        guard let snapshot, snapshot.exists else {
                            continuation.finish(throwing: CoupleClientError.coupleNotFound)
                            return
                        }
                        do {
                            continuation.yield(try FirebaseCoupleMapper.couple(
                                id: snapshot.documentID,
                                data: snapshot.data() ?? [:]
                            ))
                        } catch {
                            continuation.finish(throwing: FirebaseDomainErrorMapper.couple(error))
                        }
                    }
                listener.set(registration)
                continuation.onTermination = { @Sendable _ in listener.remove() }
            }
        }
    )
}

extension InviteClient {
    static let firebase = Self(
        createInvite: { coupleID in
            do {
                let result = try await FirebaseCallables.functions
                    .httpsCallable("createInvite")
                    .call(["coupleId": coupleID])
                guard let response = result.data as? [String: Any],
                      let rawToken = response["token"] as? String,
                      let token = InviteToken(rawValue: rawToken),
                      let expiresAtMillis = FirebaseCoupleMapper.number(response["expiresAtMillis"])
                else {
#if DEBUG
                    let response = result.data as? [String: Any]
                    let tokenLength = (response?["token"] as? String)?.count ?? -1
                    let expirationType = response?["expiresAtMillis"].map {
                        String(describing: type(of: $0))
                    } ?? "missing"
                    print(
                        "CREATE_INVITE_INVALID_RESPONSE tokenLength=\(tokenLength) " +
                        "expirationType=\(expirationType)"
                    )
#endif
                    throw InviteClientError.unknown
                }

                guard let url = InviteLinkConfiguration.url(for: token) else {
                    throw InviteClientError.configurationMissing
                }
                return CoupleInvite(
                    token: token,
                    url: url,
                    expiresAt: Date(timeIntervalSince1970: expiresAtMillis / 1_000)
                )
            } catch {
                throw FirebaseDomainErrorMapper.invite(error)
            }
        },
        acceptInvite: { token in
            do {
                let result = try await FirebaseCallables.functions
                    .httpsCallable("acceptInvite")
                    .call(["token": token.rawValue])
                return try FirebaseCoupleMapper.couple(from: result.data)
            } catch {
                throw FirebaseDomainErrorMapper.invite(error)
            }
        },
        parseInviteURL: { url in
            try InviteLinkConfiguration.token(from: url)
        }
    )
}

private nonisolated enum InviteLinkConfiguration {
    private static let fallbackBaseURL = URL(string: "https://coupleos-lc7.web.app")!

    static var baseURL: URL? {
        if let configuredURL = Bundle.main.object(
            forInfoDictionaryKey: "COUPLE_INVITE_BASE_URL"
        ) as? String,
           let url = URL(string: configuredURL) {
            return url
        }

        if let projectID = FirebaseApp.app()?.options.projectID,
           !projectID.isEmpty {
            return URL(string: "https://\(projectID).web.app")
        }
        return fallbackBaseURL
    }

    static func url(for token: InviteToken) -> URL? {
        baseURL?.appending(path: "invite").appending(path: token.rawValue)
    }

    static func token(from url: URL) throws -> InviteToken {
        guard let baseURL,
              url.scheme?.lowercased() == baseURL.scheme?.lowercased(),
              url.host?.lowercased() == baseURL.host?.lowercased() else {
            throw InviteClientError.inviteInvalid
        }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 2,
              components[0] == "invite",
              let token = InviteToken(rawValue: components[1]) else {
            throw InviteClientError.inviteInvalid
        }
        return token
    }
}

private nonisolated enum FirebaseCoupleMapper {
    static func couple(from value: Any) throws -> Couple {
        guard let envelope = value as? [String: Any],
              let data = envelope["couple"] as? [String: Any],
              let id = data["id"] as? String else {
            throw CoupleClientError.invalidData
        }
        return try couple(id: id, data: data)
    }

    static func couple(id: String, data: [String: Any]) throws -> Couple {
        let metadata = try metadata(from: data)
        let createdAt = try date(in: data, key: "createdAt", required: true)!
        let activatedAt = try date(in: data, key: "activatedAt", required: false)
        return Couple(
            id: id,
            memberIDs: metadata.memberIDs,
            status: metadata.status,
            createdBy: metadata.createdBy,
            createdAt: createdAt,
            activatedAt: activatedAt
        )
    }

    private static func metadata(from data: [String: Any]) throws -> (memberIDs: [String], status: Couple.Status, createdBy: String) {
        guard let memberIDs = data["memberIds"] as? [String],
              let rawStatus = data["status"] as? String,
              let status = Couple.Status(rawValue: rawStatus),
              let createdBy = data["createdBy"] as? String else {
            throw CoupleClientError.invalidData
        }
        return (memberIDs, status, createdBy)
    }

    private static func date(in data: [String: Any], key: String, required: Bool) throws -> Date? {
        if let timestamp = data[key] as? Timestamp {
            return timestamp.dateValue()
        }
        guard let millis = number(data["\(key)Millis"]) else {
            if required { throw CoupleClientError.invalidData }
            return nil
        }
        return Date(timeIntervalSince1970: millis / 1_000)
    }

    static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            number.doubleValue
        case let number as Double:
            number
        case let number as Int:
            Double(number)
        case let number as Int64:
            Double(number)
        default:
            nil
        }
    }
}

private nonisolated enum FirebaseDomainErrorMapper {
    static func couple(_ error: Error) -> CoupleClientError {
        if let error = error as? CoupleClientError { return error }
        switch domainCode(error) {
        case "profile-required": return .profileRequired
        case "already-in-couple": return .alreadyInCouple
        case "couple-not-found": return .coupleNotFound
        case "couple-already-full": return .coupleAlreadyFull
        case "permission-denied", "authentication-required": return .permissionDenied
        default: return transport(error).couple
        }
    }

    static func invite(_ error: Error) -> InviteClientError {
        if let error = error as? InviteClientError { return error }
        switch domainCode(error) {
        case "invite-invalid": return .inviteInvalid
        case "invite-expired": return .inviteExpired
        case "invite-already-used": return .inviteAlreadyUsed
        case "cannot-accept-own-invite": return .cannotAcceptOwnInvite
        case "already-in-couple": return .alreadyInCouple
        case "couple-not-found": return .coupleNotFound
        case "couple-already-full": return .coupleAlreadyFull
        case "permission-denied", "authentication-required": return .permissionDenied
        default: return transport(error).invite
        }
    }

    private static func domainCode(_ error: Error) -> String? {
        let details = (error as NSError).userInfo[FunctionsErrorDetailsKey] as? [String: Any]
        return details?["domainCode"] as? String
    }

    private static func transport(_ error: Error) -> TransportError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return .network }
        if nsError.domain == FunctionsErrorDomain,
           let code = FunctionsErrorCode(rawValue: nsError.code) {
            switch code {
            case .unavailable, .deadlineExceeded, .cancelled: return .network
            case .permissionDenied, .unauthenticated: return .permissionDenied
            default: return .unknown
            }
        }
        if nsError.domain == FirestoreErrorDomain,
           let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
            switch code {
            case .unavailable, .deadlineExceeded: return .network
            case .permissionDenied, .unauthenticated: return .permissionDenied
            default: return .unknown
            }
        }
        return .unknown
    }

    private enum TransportError {
        case network
        case permissionDenied
        case unknown

        var couple: CoupleClientError {
            switch self {
            case .network: .networkUnavailable
            case .permissionDenied: .permissionDenied
            case .unknown: .unknown
            }
        }

        var invite: InviteClientError {
            switch self {
            case .network: .networkUnavailable
            case .permissionDenied: .permissionDenied
            case .unknown: .unknown
            }
        }
    }
}
