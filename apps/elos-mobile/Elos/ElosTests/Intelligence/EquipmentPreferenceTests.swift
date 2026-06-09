import Testing
@testable import Elos

struct EquipmentPreferenceTests {
    @Test func fullGymAllowsEverything() {
        let p = EquipmentPreference.fullGym
        #expect(p.isAvailable(equipment: "machine"))
        #expect(p.isAvailable(equipment: "barbell"))
    }
    @Test func homeExcludesMachines() {
        let p = EquipmentPreference(posture: .home, customTypes: [])
        #expect(p.isAvailable(equipment: "dumbbell"))
        #expect(p.isAvailable(equipment: "barbell"))
        #expect(!p.isAvailable(equipment: "machine"))
    }
    @Test func customUsesExplicitSet() {
        let p = EquipmentPreference(posture: .custom, customTypes: ["dumbbell"])
        #expect(p.isAvailable(equipment: "dumbbell"))
        #expect(!p.isAvailable(equipment: "barbell"))
    }
    @Test func roundTripsThroughJSON() {
        let p = EquipmentPreference(posture: .custom, customTypes: ["cable", "dumbbell"])
        #expect(EquipmentPreference(json: p.json) == p)
        #expect(EquipmentPreference(json: "") == .fullGym)
    }
}
