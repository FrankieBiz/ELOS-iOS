import Foundation

// MARK: - APIService (stub)
// The old multi-domain service has been retired. ELOS is now an offline-first
// gym-only app. This stub remains so any external Xcode project reference
// keeps compiling until you remove it from the project.

actor APIService {
    static let shared = APIService()

    private(set) var isConfigured: Bool = false

    func configure(baseURL: String = "", authToken: String = "") {
        isConfigured = !baseURL.isEmpty
    }
}
