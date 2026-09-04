import FirebaseFunctions

/// Every callable is deployed to one region. The backend pins the same value in
/// its `callableOptions`, so the two have to move together.
nonisolated enum FirebaseCallables {
    static let region = "us-central1"

    static var functions: Functions { Functions.functions(region: region) }

    static func call(
        _ name: String,
        data: [String: Any]? = nil
    ) async throws -> HTTPSCallableResult {
        try await functions.httpsCallable(name).call(data)
    }
}
