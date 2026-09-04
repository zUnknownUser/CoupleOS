import ComposableArchitecture
import SwiftUI
import UIKit

@main
struct CoupleOSApp: App {
    @UIApplicationDelegateAdaptor(CoupleOSAppDelegate.self) private var appDelegate
    private let store: StoreOf<AppFeature>

    init() {
        FirebaseBootstrap.configure()
        store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
