import Foundation
import Combine
import Supabase

@MainActor
final class AuthStore: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isOnboardingComplete: Bool = false
    @Published private(set) var currentUserID: String = ""
    @Published var isLoading: Bool = true

    private var userExplicitlySignedOut = false

    init() {
        Task { await observeAuthState() }
    }

    private func observeAuthState() async {
        for await (event, session) in SupabaseManager.shared.client.auth.authStateChanges {
            switch event {
            case .initialSession:
                if let session {
                    userExplicitlySignedOut = false
                    currentUserID   = session.user.id.uuidString
                    isAuthenticated = true
                    // Existing session on app launch — always skip onboarding
                    await fetchOnboardingStatus(isNewAccount: false)
                }
                isLoading = false

            case .signedIn:
                if let session {
                    userExplicitlySignedOut = false
                    currentUserID   = session.user.id.uuidString
                    isAuthenticated = true
                    // Accounts created within the last 60 seconds are new signups
                    let isNewAccount = abs(Date().timeIntervalSince(session.user.createdAt)) < 60
                    await fetchOnboardingStatus(isNewAccount: isNewAccount)
                }

            case .tokenRefreshed:
                if let session {
                    currentUserID   = session.user.id.uuidString
                    isAuthenticated = true
                    await fetchOnboardingStatus(isNewAccount: false)
                }

            case .signedOut:
                // Keep `userExplicitlySignedOut` as-is — it's reset on the next successful
                // sign-in. Resetting it here defeated its purpose (suppressing auto-refresh
                // after an explicit logout).
                currentUserID        = ""
                isAuthenticated      = false
                isOnboardingComplete = false

            default:
                break
            }
        }
    }

    private func fetchOnboardingStatus(isNewAccount: Bool) async {
        let cacheKey = "elos_onboarded_\(currentUserID)"
        // Also check the flag set by register() — handles email-confirmation flows where
        // the user confirms their email and signs in manually after createdAt > 60s.
        let signupPending = UserDefaults.standard.bool(forKey: "elos_signup_pending")

        // Existing account login — skip survey entirely and cache the result
        guard isNewAccount || signupPending else {
            isOnboardingComplete = true
            UserDefaults.standard.set(true, forKey: cacheKey)
            return
        }
        // Consume the flag now that we're proceeding to onboarding
        UserDefaults.standard.removeObject(forKey: "elos_signup_pending")

        // Trust the local cache immediately so we never flash onboarding on a bad connection.
        if UserDefaults.standard.bool(forKey: cacheKey) {
            isOnboardingComplete = true
            return
        }

        do {
            let profile: ProfileOnboarding = try await ApiClient.shared.get("/profile")
            isOnboardingComplete = profile.onboarding_complete
            if profile.onboarding_complete {
                UserDefaults.standard.set(true, forKey: cacheKey)
            }
        } catch {
            isOnboardingComplete = false
        }
    }

    func markOnboardingComplete() {
        isOnboardingComplete = true
        // Persist immediately so future launches don't re-check the network.
        UserDefaults.standard.set(true, forKey: "elos_onboarded_\(currentUserID)")
    }

    /// Called when the app returns to the foreground to ensure the token is fresh.
    func refreshSessionIfNeeded() async {
        guard !userExplicitlySignedOut, isAuthenticated else { return }
        _ = try? await SupabaseManager.shared.client.auth.session
    }

    func logout() async {
        userExplicitlySignedOut = true
        do {
            try await SupabaseManager.shared.client.auth.signOut()
        } catch {
            // The network sign-out failed — force-clear the local session so the persisted
            // tokens don't survive on disk and silently re-authenticate on next launch.
            try? await SupabaseManager.shared.client.auth.signOut(scope: .local)
            currentUserID        = ""
            isAuthenticated      = false
            isOnboardingComplete = false
        }
    }
}

private struct ProfileOnboarding: Decodable {
    let onboarding_complete: Bool
}
