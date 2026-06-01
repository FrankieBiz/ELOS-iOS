import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.url)!,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    autoRefreshToken: true,
                    // Emit the stored session immediately instead of waiting for a
                    // network refresh — prevents logout on bad connections at launch.
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
