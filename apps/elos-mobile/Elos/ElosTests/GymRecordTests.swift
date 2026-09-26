import Foundation
import Testing
@testable import Elos

/// `GymRecord` itself has no logic to test — it's a plain local-only SwiftData model, same shape
/// as `EquipmentPreference`'s backing storage. Just pinning the constructor's defaults here.
/// The fallback contract this record's deletability depends on — a `DayVariant` never loses its
/// display name just because its gym was deleted — is tested in `DayVariantsTests` (Task 7),
/// since `DayVariant` doesn't exist yet at this point in the build.
struct GymRecordTests {

    @Test func gymRecordConstructsWithDefaults() {
        let gym = GymRecord(ownerID: "user-1", name: "Fairless")
        #expect(gym.name == "Fairless")
        #expect(gym.ownerID == "user-1")
        #expect(gym.lastUsedAt == nil)
        #expect(!gym.id.isEmpty)
    }
}
