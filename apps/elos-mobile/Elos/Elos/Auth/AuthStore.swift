import Foundation
import Combine
import Supabase

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
                    currentUserID   = session.user.id.uuidString
                    isAuthenticated = true
                    await fetchOnboardingStatus()
                }
                isLoading = false

            case .signedIn, .tokenRefreshed:
                if let session {
                    currentUserID   = session.user.id.uuidString
                    isAuthenticated = true
                    await fetchOnboardingStatus()
                }

            case .signedOut:
                userExplicitlySignedOut = false
                currentUserID        = ""
                isAuthenticated      = false
                isOnboardingComplete = false

            default:
                break
            }
        }
    }

    private func fetchOnboardingStatus() async {
        let cacheKey = "elos_onboarded_\(currentUserID)"

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
            currentUserID        = ""
            isAuthenticated      = false
            isOnboardingComplete = false
        }
    }
}

private struct ProfileOnboarding: Decodable {
    let onboarding_complete: Bool
}
