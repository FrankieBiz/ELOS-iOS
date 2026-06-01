import Foundation
import Combine
import CryptoKit
import AuthenticationServices
import Supabase

final class AuthViewModel: ObservableObject {
    @Published var email           = ""
    @Published var password        = ""
    @Published var confirmPassword = ""
    @Published var isLoading       = false
    @Published var errorMessage: String?

    private var currentNonce: String?

    func login(authStore: AuthStore) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await SupabaseManager.shared.client.auth.signIn(
                email: email,
                password: password
            )
            // AuthStore observes authStateChanges and handles the rest
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign in with Apple

    /// Called from SignInWithAppleButton's onRequest closure.
    /// Stores the raw nonce and returns the SHA-256 hash to include in the Apple request.
    func prepareAppleSignIn() -> String {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        return Self.sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>, authStore: AuthStore) async {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData  = credential.identityToken,
                let idToken    = String(data: tokenData, encoding: .utf8),
                let nonce      = currentNonce
            else {
                errorMessage = "Sign in with Apple failed. Please try again."
                return
            }
            isLoading    = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                try await SupabaseManager.shared.client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: nonce
                    )
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Email / Password

    func register(authStore: AuthStore) async {
        guard !email.isEmpty else { errorMessage = "Email is required."; return }
        guard password.count >= 8 else { errorMessage = "Password must be at least 8 characters."; return }
        guard password == confirmPassword else { errorMessage = "Passwords do not match."; return }
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await SupabaseManager.shared.client.auth.signUp(
                email: email,
                password: password
            )
            if response.session == nil {
                // Email confirmation is enabled — user must verify before signing in
                errorMessage = "Check your email to confirm your account, then sign in."
            }
            // If a session was returned, authStateChanges handles routing automatically
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
