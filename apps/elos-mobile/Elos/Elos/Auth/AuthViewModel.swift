import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email           = ""
    @Published var password        = ""
    @Published var confirmPassword = ""
    @Published var isLoading       = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    func login(authStore: AuthStore) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        isLoading    = true
        errorMessage = nil
        infoMessage  = nil
        defer { isLoading = false }
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
        errorMessage = nil
        infoMessage  = nil
        do {
            try await SupabaseManager.shared.client.auth.resetPasswordForEmail(trimmed)
            infoMessage = "If an account exists for \(trimmed), a reset link is on its way."
        } catch {
            // Don't reveal whether the email exists; show a neutral message.
            infoMessage = "If an account exists for \(trimmed), a reset link is on its way."
        }
    }

    // MARK: - Email / Password

    func deleteAccount(authStore: AuthStore) async -> Bool {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
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
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await SupabaseManager.shared.client.auth.signUp(
                email: email,
                password: password
            )
            // Mark that this device just created an account so onboarding always runs,
            // even if the user needs to confirm their email and sign in manually later.
            UserDefaults.standard.set(true, forKey: "elos_signup_pending")
            if response.session == nil {
                // Email confirmation is enabled — user must verify before signing in
                errorMessage = "Check your email to confirm your account, then sign in."
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
