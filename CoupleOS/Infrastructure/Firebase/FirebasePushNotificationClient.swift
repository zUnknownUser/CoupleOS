import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

/// The three FCM calls below are deprecated in favour of the Firebase Installation
/// ID registration model (`register`/`unregister`/`messaging(_:didReceiveRegistration:)`),
/// and are deliberately kept.
///
/// That model is not a rename: it activates only with `FirebaseMessagingInstallationIdEnabled`
/// in Info.plist, at which point `token()` is documented to always fail, and it yields an
/// installation id rather than an FCM token. Our delivery path is
/// `sendEachForMulticast({ tokens })` in `notifications.ts`, and firebase-admin 14.3.0 can
/// only target a token, a topic or a condition — it cannot address an installation id.
///
/// Adopting the new API today would therefore leave the backend with nothing to send to.
/// Revisit when firebase-admin can target an installation id; until then the deprecation
/// warnings are the correct trade.
extension PushNotificationClient {
    static let firebase = Self(
        requestAuthorization: {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                guard granted else { return false }
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                return true
            } catch {
                return false
            }
        },
        registerDevice: { userID, language in
            guard let token = try? await Messaging.messaging().token(), !token.isEmpty else {
                throw PushNotificationError.tokenUnavailable
            }
            do {
                try await DeviceRegistry.document(for: userID).setData(
                    [
                        "token": token,
                        "platform": "ios",
                        "language": language.tag,
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    merge: false
                )
            } catch {
                throw PushNotificationError.storageFailed
            }
        },
        unregisterDevice: { userID in
            try? await DeviceRegistry.document(for: userID).delete()
            try? await Messaging.messaging().deleteToken()
        },
        tokenRefreshes: {
            AsyncStream { continuation in
                let observer = ObserverToken(NotificationCenter.default.addObserver(
                    forName: .MessagingRegistrationTokenRefreshed,
                    object: nil,
                    queue: nil
                ) { _ in
                    continuation.yield(())
                })
                continuation.onTermination = { @Sendable _ in
                    NotificationCenter.default.removeObserver(observer.value)
                }
            }
        }
    )
}

/// `NotificationCenter` hands back a non-Sendable token, but the stream's
/// termination handler is `@Sendable`, so it travels boxed.
private nonisolated final class ObserverToken: @unchecked Sendable {
    let value: any NSObjectProtocol

    init(_ value: any NSObjectProtocol) {
        self.value = value
    }
}

/// One document per install rather than per token: FCM rotates tokens, and
/// keying on the token itself would leave a dead document behind every time.
private nonisolated enum DeviceRegistry {
    private static let installIDKey = "com.coupleos.installID"

    static func document(for userID: String) -> DocumentReference {
        Firestore.firestore()
            .collection("users")
            .document(userID)
            .collection("devices")
            .document(installID)
    }

    private static var installID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: installIDKey), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: installIDKey)
        return generated
    }
}
