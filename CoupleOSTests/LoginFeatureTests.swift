import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class LoginFeatureTests: XCTestCase {
    func testInvalidEmail() async {
        var state = LoginFeature.State()
        state.email = "not-an-email"
        state.password = "secret1"
        let store = TestStore(initialState: state) { LoginFeature() }

        await store.send(.continueTapped) {
            $0.emailError = "Enter a valid email address."
        }
    }

    func testInvalidPassword() async {
        var state = LoginFeature.State()
        state.email = "alex@example.com"
        state.password = "123"
        let store = TestStore(initialState: state) { LoginFeature() }

        await store.send(.continueTapped) {
            $0.passwordError = "Password must have at least 6 characters."
        }
    }

    func testLoginLoadingAndSuccess() async {
        var state = LoginFeature.State()
        state.email = " Alex@Example.com "
        state.password = "secret1"
        let user = TestFixtures.authenticatedUser
        let store = TestStore(initialState: state) { LoginFeature() } withDependencies: {
            $0.authenticationClient.signIn = { email, password in
                XCTAssertEqual(email, "alex@example.com")
                XCTAssertEqual(password, "secret1")
                return user
            }
        }

        await store.send(.continueTapped) { $0.isLoading = true }
        await store.receive(\.signInResponse.success) {
            $0.isLoading = false
        }
        await store.receive(\.delegate.authenticated)
    }

    func testLoginError() async {
        var state = LoginFeature.State()
        state.email = "alex@example.com"
        state.password = "secret1"
        let store = TestStore(initialState: state) { LoginFeature() } withDependencies: {
            $0.authenticationClient.signIn = { _, _ in throw AuthenticationError.invalidCredentials }
        }

        await store.send(.continueTapped) { $0.isLoading = true }
        await store.receive(\.signInResponse.failure) {
            $0.isLoading = false
            $0.errorMessage = AuthenticationError.invalidCredentials.message
        }
    }

    func testDoubleSubmitIsIgnored() async {
        actor Gate {
            var continuation: CheckedContinuation<Void, Never>?
            var calls = 0
            func wait() async {
                calls += 1
                await withCheckedContinuation { continuation = $0 }
            }
            func open() { continuation?.resume() }
        }

        let gate = Gate()
        var state = LoginFeature.State()
        state.email = "alex@example.com"
        state.password = "secret1"
        let store = TestStore(initialState: state) { LoginFeature() } withDependencies: {
            $0.authenticationClient.signIn = { _, _ in
                await gate.wait()
                return TestFixtures.authenticatedUser
            }
        }

        await store.send(.continueTapped) { $0.isLoading = true }
        await store.send(.continueTapped)
        await gate.open()
        await store.receive(\.signInResponse.success) { $0.isLoading = false }
        await store.receive(\.delegate.authenticated)
        let calls = await gate.calls
        XCTAssertEqual(calls, 1)
    }
}
