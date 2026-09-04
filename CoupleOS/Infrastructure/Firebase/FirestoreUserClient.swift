import FirebaseFirestore
import Foundation

extension UserClient {
    static let firestore = Self(
        fetchUser: { id in
            do {
                let document = try await Firestore.firestore()
                    .collection(FirestoreUserDTO.collection)
                    .document(id)
                    .getDocument()
                guard document.exists else { return nil }
                return try FirestoreUserDTO(documentID: document.documentID, data: document.data() ?? [:]).domain
            } catch {
                throw FirestoreUserErrorMapper.map(error)
            }
        },
        createUser: { request in
            let reference = Firestore.firestore()
                .collection(FirestoreUserDTO.collection)
                .document(request.id)
            do {
                let existing = try await reference.getDocument()
                if existing.exists {
                    return try FirestoreUserDTO(
                        documentID: existing.documentID,
                        data: existing.data() ?? [:]
                    ).domain
                }
                try await reference.setData(FirestoreUserDTO.createData(from: request), merge: false)
                let document = try await reference.getDocument(source: .server)
                return try FirestoreUserDTO(
                    documentID: document.documentID,
                    data: document.data() ?? [:]
                ).domain
            } catch {
                throw FirestoreUserErrorMapper.map(error)
            }
        },
        updateUser: { request in
            let reference = Firestore.firestore()
                .collection(FirestoreUserDTO.collection)
                .document(request.id)
            do {
                let existing = try await reference.getDocument(source: .server)
                guard existing.exists else { throw UserClientError.documentNotFound }
                try await reference.updateData(FirestoreUserDTO.updateData(from: request))
                let document = try await reference.getDocument(source: .server)
                return try FirestoreUserDTO(
                    documentID: document.documentID,
                    data: document.data() ?? [:]
                ).domain
            } catch {
                throw FirestoreUserErrorMapper.map(error)
            }
        }
    )
}

private nonisolated struct FirestoreUserDTO {
    static let collection = "users"

    private enum Field {
        static let firstName = "firstName"
        static let createdAt = "createdAt"
        static let onboardingStatus = "onboardingStatus"
        static let legacyEmail = "email"
        static let activeCoupleID = "activeCoupleId"
    }

    let id: String
    let firstName: String
    let createdAt: Date
    let onboardingStatus: OnboardingStatus
    let activeCoupleID: String?

    init(documentID: String, data: [String: Any]) throws {
        guard let firstName = data[Field.firstName] as? String,
              let createdAt = data[Field.createdAt] as? Timestamp,
              let rawStatus = data[Field.onboardingStatus] as? String,
              let onboardingStatus = OnboardingStatus(rawValue: rawStatus) else {
            throw UserClientError.invalidData
        }

        self.id = documentID
        self.firstName = firstName
        self.createdAt = createdAt.dateValue()
        self.onboardingStatus = onboardingStatus
        self.activeCoupleID = data[Field.activeCoupleID] as? String
    }

    var domain: User {
        User(
            id: id,
            firstName: firstName,
            createdAt: createdAt,
            onboardingStatus: onboardingStatus,
            activeCoupleID: activeCoupleID
        )
    }

    static func createData(from request: CreateUserRequest) -> [String: Any] {
        [
            Field.firstName: request.firstName,
            Field.createdAt: FieldValue.serverTimestamp(),
            Field.onboardingStatus: request.onboardingStatus.rawValue
        ]
    }

    static func updateData(from request: UpdateUserRequest) -> [String: Any] {
        [
            Field.firstName: request.firstName,
            Field.onboardingStatus: request.onboardingStatus.rawValue,
            Field.legacyEmail: FieldValue.delete()
        ]
    }
}

private nonisolated enum FirestoreUserErrorMapper {
    static func map(_ error: Error) -> UserClientError {
        if let error = error as? UserClientError { return error }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .networkUnavailable
        }
        guard nsError.domain == FirestoreErrorDomain,
              let code = FirestoreErrorCode.Code(rawValue: nsError.code) else {
            return .unknown
        }

        switch code {
        case .notFound:
            return .documentNotFound
        case .unavailable, .deadlineExceeded, .aborted:
            return .unavailable
        case .permissionDenied, .unauthenticated:
            return .permissionDenied
        case .dataLoss, .failedPrecondition, .invalidArgument:
            return .invalidData
        default:
            return .unknown
        }
    }
}
