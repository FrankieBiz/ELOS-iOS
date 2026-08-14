import Testing
@testable import Elos

struct EvidenceLibraryTests {
    @Test func exerciseSubstitutionEntryIsMediumLowCertainty() {
        let entry = EvidenceLibrary.entry(for: .exerciseSubstitution)
        #expect(entry.certainty == .mediumLow)
        #expect(!entry.claim.isEmpty)
        #expect(!entry.explanation.isEmpty)
    }
}
