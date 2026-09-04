import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import Security
import UIKit

extension AuthenticationClient {
    static let firebase = Self(
        currentUser: {
            Auth.auth().currentUser.map(AuthenticatedUser.init(firebaseUser:))
        },
        authStateChanges: {
            AsyncStream { continuation in
                let handle = Auth.auth().addStateDidChangeListener { _, user in
                    continuation.yield(user.map(AuthenticatedUser.init(firebaseUser:)))
                }
                let registration = AuthStateListenerRegistration(handle: handle)
                continuation.onTermination = { _ in
                    Auth.auth().removeStateDidChangeListener(registration.handle)
                }
            }
        },
        signIn: { email, password in
            do {
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                return AuthenticatedUser(firebaseUser: result.user)
            } catch {
                throw FirebaseAuthenticationErrorMapper.map(error)
            }
        },
        signUp: { email, password in
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                return AuthenticatedUser(firebaseUser: result.user)
            } catch {
                throw FirebaseAuthenticationErrorMapper.map(error)
            }
        },
        signInWithApple: {
            do {
                let appleCredential = try await AppleAuthorizationCoordinator().authorize()
                var name = PersonNameComponents()
                name.givenName = appleCredential.givenName
                name.familyName = appleCredential.familyName
                let credential = OAuthProvider.appleCredential(
                    withIDToken: appleCredential.idToken,
                    rawNonce: appleCredential.rawNonce,
                    fullName: name
                )
                let result = try await Auth.auth().signIn(with: credential)
                return AuthenticatedUser(firebaseUser: result.user)
            } catch {
                throw FirebaseAuthenticationErrorMapper.map(error)
            }
        },
        sendPasswordReset: { email in
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
            } catch {
                throw FirebaseAuthenticationErrorMapper.map(error)
            }
        },
        signOut: {
            do {
                try Auth.auth().signOut()
            } catch {
                throw FirebaseAuthenticationErrorMapper.map(error)
            }
        }
    )
}

private extension AuthenticatedUser {
    nonisolated init(firebaseUser: FirebaseAuth.User) {
        self.init(
            id: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName
        )
    }
}

private enum FirebaseAuthenticationErrorMapper {
    nonisolated static func map(_ error: Error) -> AuthenticationError {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            return .cancelled
        }

        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code)?.code else {
            return .unknown
        }

        switch code {
        case .invalidCredential, .wrongPassword, .userNotFound:
            return .invalidCredentials
        case .invalidEmail, .missingEmail:
            return .invalidEmail
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkUnavailable
        case .webContextCancelled:
            return .cancelled
        case .operationNotAllowed:
            return .unavailable
        default:
            return .unknown
        }
    }
}

private nonisolated struct AppleCredential: Sendable {
    let idToken: String
    let rawNonce: String
    let givenName: String?
    let familyName: String?
}

private nonisolated final class AuthStateListenerRegistration: @unchecked Sendable {
    let handle: NSObjectProtocol

    init(handle: NSObjectProtocol) {
        self.handle = handle
    }
}

@MainActor
private final class AppleAuthorizationCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleCredential, Error>?
    private var controller: ASAuthorizationController?
    private var rawNonce = ""

    func authorize() async throws -> AppleCredential {
        rawNonce = try Self.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            finish(throwing: AuthenticationError.invalidCredentials)
            return
        }

        finish(returning: AppleCredential(
            idToken: idToken,
            rawNonce: rawNonce,
            givenName: credential.fullName?.givenName,
            familyName: credential.fullName?.familyName
        ))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finish(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            preconditionFailure("Sign in with Apple requires an active window scene.")
        }
        return scene.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor(windowScene: scene)
    }

    private func finish(returning credential: AppleCredential) {
        continuation?.resume(returning: credential)
        clear()
    }

    private func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        clear()
    }

    private func clear() {
        continuation = nil
        controller = nil
        rawNonce = ""
    }

    private static func randomNonce(length: Int = 32) throws -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var bytes = [UInt8](repeating: 0, count: 16)

        while result.count < length {
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw AuthenticationError.unavailable
            }
            for byte in bytes where result.count < length {
                guard byte < characters.count * (256 / characters.count) else { continue }
                result.append(characters[Int(byte) % characters.count])
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
