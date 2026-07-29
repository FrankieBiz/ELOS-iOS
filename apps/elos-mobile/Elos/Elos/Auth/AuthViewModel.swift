import Foundation
import Combine
import Supabase
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email           = ""
    @Published var password        = ""
    @Published var confirmPassword = ""
    @Published var isSigningIn     = false
    @Published var isRegistering   = false
    @Published var isSendingReset  = false
    @Published var isAppleLoading  = false
    @Published var isDeleting      = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    /// True while any auth action is in flight. Used to disable sibling buttons so
    /// only the tapped control shows a spinner while concurrent actions can't stack.
    var isBusy: Bool { isSigningIn || isRegistering || isSendingReset || isAppleLoading || isDeleting }

    /// Raw nonce for the in-flight Sign in with Apple request. The hashed form
    /// goes to Apple; the raw form goes to Supabase for verification.
    private(set) var appleNonce: String = ""

    // MARK: - Sign in with Apple

    /// Call from SignInWithAppleButton's request closure.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        appleNonce = Self.randomNonce()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(appleNonce)
    }

    /// Call from SignInWithAppleButton's completion closure.
    func signInWithApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            // User-cancelled taps shouldn't show an error.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            #if DEBUG
            print("[Auth] Sign in with Apple failed: \(error)")
            #endif
            errorMessage = Self.appleFailureMessage(for: error)
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple didn't return a sign-in token. Sign in with your email and password instead."
                return
            }
            isAppleLoading = true
            errorMessage   = nil
            infoMessage    = nil
            defer { isAppleLoading = false }
            do {
                try await SupabaseManager.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: appleNonce)
                )
                // Apple only shares the name on the FIRST authorization — stash it
                // so onboarding/profile can prefill instead of losing it forever.
                if let given = credential.fullName?.givenName, !given.isEmpty {
                    UserDefaults.standard.set(given, forKey: "elos_pending_first_name")
                }
                if let family = credential.fullName?.familyName, !family.isEmpty {
                    UserDefaults.standard.set(family, forKey: "elos_pending_last_name")
                }
                // AuthStore observes authStateChanges and routes (new accounts
                // created <60s ago automatically get onboarding).
            } catch {
                errorMessage = friendlyMessage(for: error)
            }
        }
    }

    /// Apple's failures all arrive as the same opaque `ASAuthorizationError`, and collapsing them
    /// into "please try again" left the two *most likely* causes invisible — both of which retrying
    /// will never fix:
    ///
    /// 1. The build has no `com.apple.developer.applesignin` entitlement. Sign in with Apple needs a
    ///    paid Apple Developer membership; a personal/free team can't provision it, so this build
    ///    reports `.unknown`/`.notHandled` forever.
    /// 2. On the Simulator, Sign in with Apple additionally requires the simulator itself to be
    ///    signed into an Apple ID (Settings → Sign in to your iPhone).
    ///
    /// In both cases the useful instruction is "use email and password", so say that.
    static func appleFailureMessage(for error: Error) -> String {
        guard let authError = error as? ASAuthorizationError else {
            return "Sign in with Apple didn't complete. You can sign in with your email and password instead."
        }
        switch authError.code {
        case .unknown, .notHandled, .failed, .invalidResponse:
            #if targetEnvironment(simulator)
            return "Sign in with Apple isn't available here. The Simulator needs to be signed into an Apple ID (Settings → Sign in to your iPhone), and this build doesn't carry the Apple sign-in capability. Use your email and password instead."
            #else
            return "Sign in with Apple isn't available in this build. Use your email and password instead."
            #endif
        case .notInteractive:
            return "Sign in with Apple couldn't open. Use your email and password instead."
        default:
            return "Sign in with Apple didn't complete. You can sign in with your email and password instead."
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            if SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess,
               random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func login(authStore: AuthStore) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        isSigningIn  = true
        errorMessage = nil
        infoMessage  = nil
        defer { isSigningIn = false }
        do {
            try await SupabaseManager.shared.client.auth.signIn(
                email: email,
                password: password
            )
            // AuthStore observes authStateChanges and handles the rest
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    // MARK: - Password reset

    func sendPasswordReset() async {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your email above, then tap Forgot password."
            return
        }
        errorMessage  = nil
        infoMessage   = nil
        isSendingReset = true
        defer { isSendingReset = false }
        do {
            try await SupabaseManager.shared.client.auth.resetPasswordForEmail(
                trimmed,
                redirectTo: URL(string: "elos://auth-callback")
            )
            infoMessage = "If an account exists for \(trimmed), a reset link is on its way."
        } catch {
            // Don't reveal whether the email exists; show a neutral message.
            infoMessage = "If an account exists for \(trimmed), a reset link is on its way."
        }
    }

    // MARK: - Email / Password

    func deleteAccount(authStore: AuthStore) async -> Bool {
        isDeleting   = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            struct OkResponse: Decodable { let ok: Bool }
            _ = try await ApiClient.shared.delete("/auth/account") as OkResponse
            await authStore.logout()
            return true
        } catch {
            errorMessage = "Could not delete account. Please try again."
            return false
        }
    }

    func register(authStore: AuthStore) async {
        guard !email.isEmpty else { errorMessage = "Email is required."; return }
        guard password.count >= 8 else { errorMessage = "Password must be at least 8 characters."; return }
        guard password == confirmPassword else { errorMessage = "Passwords do not match."; return }
        isRegistering = true
        errorMessage  = nil
        infoMessage   = nil
        defer { isRegistering = false }
        do {
            let response = try await SupabaseManager.shared.client.auth.signUp(
                email: email,
                password: password,
                redirectTo: URL(string: "elos://auth-callback")
            )
            // Mark that this device just created an account so onboarding always runs,
            // even if the user needs to confirm their email and sign in manually later.
            UserDefaults.standard.set(true, forKey: "elos_signup_pending")
            if response.session == nil {
                // Email confirmation is enabled — user must verify before signing in.
                // This is a success state, so surface it as neutral info, not a red error.
                infoMessage = "Check your email and tap the confirmation link — it opens the app already signed in."
            }
            // If a session was returned, authStateChanges handles routing automatically
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    /// Map common auth failures to plain-language copy instead of raw gotrue/URLError text.
    private func friendlyMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "You appear to be offline. Check your connection and try again."
            case .timedOut:
                return "The request timed out. Please try again."
            default:
                return "Something went wrong. Please try again."
            }
        }
        let text = error.localizedDescription.lowercased()
        if text.contains("invalid") && (text.contains("credential") || text.contains("login") || text.contains("password")) {
            return "Incorrect email or password."
        }
        if text.contains("already registered") || text.contains("already been registered") || text.contains("user already") {
            return "An account with this email already exists. Try signing in."
        }
        return "Something went wrong. Please try again."
    }
}
