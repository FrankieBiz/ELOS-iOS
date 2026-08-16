import SwiftUI
import Combine

// MARK: - AnalyticsViewModel

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var e1rmHistory: [E1RMPoint] = []
    @Published var selectedLift = "Barbell Bench Press"
    @Published var isLoading   = false
    @Published var loadError:   String?

    struct E1RMPoint: Identifiable {
        let id = UUID(); let day: String; let e1rm: Double
    }

    func loadE1RM(liftName: String) {
        Task {
            isLoading = true; defer { isLoading = false }
            let encoded = liftName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? liftName
            do {
                let r: E1RMResponse = try await ApiClient.shared.get("/analytics/e1rm/\(encoded)")
                // Drop non-positive points. A set logged without a weight (the field left blank, or a
                // bodyweight movement) yields an e1RM of 0, and one of those at the end of the series
                // made the card read "0 lb current" and draw a cliff to the axis — while the PR board
                // right below it showed the real 1RM for the same lift. Zero isn't a strength estimate.
                e1rmHistory = r.e1rm
                    .filter { $0.e1rm > 0 }
                    .map { E1RMPoint(day: $0.day, e1rm: $0.e1rm) }
                loadError = nil
            } catch { loadError = "Couldn't load e1RM history." }
        }
    }
}

private struct E1RMResponse: Decodable {
    let e1rm: [P]; struct P: Decodable { let day: String; let e1rm: Double }
}
