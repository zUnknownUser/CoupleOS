import FirebaseAppCheck
import FirebaseCore

/// The single entry point for Firebase start-up.
///
/// The App Check provider factory has to be installed *before*
/// `FirebaseApp.configure()`, so both the `App` and the `UIApplicationDelegate`
/// funnel through here rather than calling `configure()` themselves. Whichever
/// runs first wins; the rest are no-ops.
enum FirebaseBootstrap {
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        AppCheck.setAppCheckProviderFactory(CoupleAppCheckProviderFactory())
        FirebaseApp.configure()
    }
}

/// Debug builds and the simulator cannot attest, so they fall back to the debug
/// provider. Its token has to be registered once per device in the Firebase
/// console (App Check → Manage debug tokens); the token is printed to the
/// console on first launch.
private final class CoupleAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
#if DEBUG
        AppCheckDebugProvider(app: app)
#else
        AppAttestProvider(app: app)
#endif
    }
}
