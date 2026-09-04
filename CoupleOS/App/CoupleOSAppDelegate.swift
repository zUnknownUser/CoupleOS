import FirebaseMessaging
import UIKit
import UserNotifications

final class CoupleOSAppDelegate: NSObject, UIApplicationDelegate {
    override init() {
        super.init()
        FirebaseBootstrap.configure()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Permission is asked for later, once the Couple exists and a
        // notification would actually mean something; see AuthenticatedFeature.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Handing the APNs token to Messaging is what makes an FCM token
        // available; the registration effect is waiting on it.
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
#if DEBUG
        print("APNS_REGISTRATION_ERROR: \(error.localizedDescription)")
#endif
    }
}

extension CoupleOSAppDelegate: UNUserNotificationCenterDelegate {
    /// A Couple can be looking at the app when their person answers, so the
    /// banner is still worth showing in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        try? await center.setBadgeCount(0)
    }
}
