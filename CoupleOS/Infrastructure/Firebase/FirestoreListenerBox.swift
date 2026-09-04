import FirebaseFirestore

/// Bridges a Firestore listener into an `AsyncThrowingStream`.
///
/// The registration only exists after `addSnapshotListener` returns, which can
/// be after the consumer has already cancelled the stream. Holding it here lets
/// a late registration be torn down immediately instead of leaking a listener.
nonisolated final class FirestoreListenerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var registration: (any ListenerRegistration)?
    private var isTerminated = false

    func set(_ registration: any ListenerRegistration) {
        lock.lock()
        if isTerminated {
            lock.unlock()
            registration.remove()
            return
        }
        self.registration = registration
        lock.unlock()
    }

    func remove() {
        lock.lock()
        isTerminated = true
        let registration = registration
        self.registration = nil
        lock.unlock()
        registration?.remove()
    }
}
