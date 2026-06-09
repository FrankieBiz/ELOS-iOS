import Foundation

enum EquipmentPosture: String, Codable, CaseIterable { case fullGym, home, custom }

struct EquipmentPreference: Codable, Equatable {
    var posture: EquipmentPosture
    var customTypes: Set<String>   // normalized equipment type tokens, used when posture == .custom

    static let fullGym = EquipmentPreference(posture: .fullGym, customTypes: [])
    static let homeAllowed: Set<String> = ["barbell", "dumbbell", "kettlebell", "bodyweight"]

    func isAvailable(equipment: String) -> Bool {
        let e = equipment.lowercased().trimmingCharacters(in: .whitespaces)
        let key = e.isEmpty ? "bodyweight" : e
        switch posture {
        case .fullGym: return true
        case .home:    return Self.homeAllowed.contains { key.contains($0) }
        case .custom:  return customTypes.contains { key.contains($0) }
        }
    }

    var json: String {
        (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? ""
    }
    init(posture: EquipmentPosture, customTypes: Set<String>) {
        self.posture = posture; self.customTypes = customTypes
    }
    init(json: String) {
        guard !json.isEmpty, let data = json.data(using: .utf8),
              let p = try? JSONDecoder().decode(EquipmentPreference.self, from: data) else {
            self = .fullGym; return
        }
        self = p
    }
}
