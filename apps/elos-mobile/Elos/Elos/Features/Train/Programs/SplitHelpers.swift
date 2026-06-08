import Foundation

struct DayExercise: Codable, Identifiable {
    let id: String
    let name: String
    var sets: Int
    var reps: String
    // Machine/equipment identity (nil = generic). Round-trips to the backend as
    // opaque JSON inside UserSplitDayRecord.exercisesJSON — no backend change needed.
    var equipmentId: String?
    var equipmentDedupeKey: String?
    var equipmentBrandName: String?

    init(id: String, name: String, sets: Int = 3, reps: String = "10",
         equipmentId: String? = nil, equipmentDedupeKey: String? = nil,
         equipmentBrandName: String? = nil) {
        self.id   = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.equipmentId        = equipmentId
        self.equipmentDedupeKey = equipmentDedupeKey
        self.equipmentBrandName = equipmentBrandName
    }

    // Backward-compat: older stored JSON won't have sets/reps/equipment; fall back to defaults.
    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        id   = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        sets = (try? c.decode(Int.self,    forKey: .sets)) ?? 3
        reps = (try? c.decode(String.self, forKey: .reps)) ?? "10"
        equipmentId        = try? c.decodeIfPresent(String.self, forKey: .equipmentId)
        equipmentDedupeKey = try? c.decodeIfPresent(String.self, forKey: .equipmentDedupeKey)
        equipmentBrandName = try? c.decodeIfPresent(String.self, forKey: .equipmentBrandName)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, sets, reps, equipmentId, equipmentDedupeKey, equipmentBrandName
    }

    /// Parse a library prescription like "3x6–10" or "2–3x8–12/side" into a DayExercise.
    /// For set ranges (e.g. "2–3") the higher value is used.
    static func from(name: String, prescription: String) -> DayExercise {
        let parts = prescription.components(separatedBy: "x")
        guard parts.count >= 2 else { return DayExercise(id: UUID().uuidString, name: name) }
        let setsPart = parts[0].trimmingCharacters(in: .whitespaces)
        let repsPart = parts[1...].joined(separator: "x").trimmingCharacters(in: .whitespaces)
        // "2–3" → take higher bound; plain "3" → parse directly
        let setsNum = setsPart.components(separatedBy: "–")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .max() ?? 3
        return DayExercise(
            id: UUID().uuidString,
            name: name,
            sets: setsNum,
            reps: repsPart.isEmpty ? "10" : repsPart
        )
    }
}
