import ComposableArchitecture
import XCTest
@testable import CoupleOS

final class SignUpFeatureTests: XCTestCase {
    func testAuthenticationSuccessDelegatesIdentityWithoutCreatingProfile() async {
        var state = SignUpFeature.State(firstName: "Alex")
        state.email = " Alex@Example.com "
        state.password = "secret1"
        let authUser = TestFixtures.authenticatedUser
        let store = TestStore(initialState: state) { SignUpFeature() } withDependencies: {
            $0.authenticationClient.signUp = { email, password in
                XCTAssertEqual(email, "alex@example.com")
                XCTAssertEqual(password, "secret1")
                return authUser
            }
        }

        await store.send(.createAccountTapped) { $0.isLoading = true }
        await store.receive(\.authenticationResponse.success)
        await store.receive(\.delegate.authenticated)
    }

    func testAuthenticationFailure() async {
        var state = SignUpFeature.State(firstName: "Alex")
        state.email = "alex@example.com"
        state.password = "secret1"
        let store = TestStore(initialState: state) { SignUpFeature() } withDependencies: {
            $0.authenticationClient.signUp = { _, _ in
                throw AuthenticationError.emailAlreadyInUse
            }
        }

        await store.send(.createAccountTapped) { $0.isLoading = true }
        await store.receive(\.authenticationResponse.failure) {
            $0.isLoading = false
            $0.error = .emailAlreadyInUse
        }
    }

    func testInvalidEmail() async {
        var state = SignUpFeature.State(firstName: "Alex")
        state.email = "not-an-email"
        state.password = "secret1"
        let store = TestStore(initialState: state) { SignUpFeature() }

        await store.send(.createAccountTapped) {
            $0.emailError = .invalidEmail
        }
    }

    func testInvalidPassword() async {
        var state = SignUpFeature.State(firstName: "Alex")
        state.email = "alex@example.com"
        state.password = "123"
        let store = TestStore(initialState: state) { SignUpFeature() }

        await store.send(.createAccountTapped) {
            $0.passwordError = .shortPassword(minimum: CredentialRules.minimumPasswordLength)
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
        var state = SignUpFeature.State(firstName: "Alex")
        state.email = "alex@example.com"
        state.password = "secret1"
        let store = TestStore(initialState: state) { SignUpFeature() } withDependencies: {
            $0.authenticationClient.signUp = { _, _ in
                await gate.wait()
                return TestFixtures.authenticatedUser
            }
        }

        await store.send(.createAccountTapped) { $0.isLoading = true }
        await store.send(.createAccountTapped)
        await gate.open()
        await store.receive(\.authenticationResponse.success)
        await store.receive(\.delegate.authenticated)
        let calls = await gate.calls
        XCTAssertEqual(calls, 1)
    }
}
