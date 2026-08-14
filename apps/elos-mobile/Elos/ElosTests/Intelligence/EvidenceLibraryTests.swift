import Testing
@testable import Elos

struct EvidenceLibraryTests {
    @Test func exerciseSubstitutionEntryIsMediumLowCertainty() {
        let entry = EvidenceLibrary.entry(for: .exerciseSubstitution)
        #expect(entry.certainty == .mediumLow)
        #expect(!entry.claim.isEmpty)
        #expect(!entry.explanation.isEmpty)
    }

    @Test func exerciseSubstitutionExplanationPreservesHonestyCaveat() {
        // The whole point of this entry is that it does NOT overclaim — guard against someone
        // quietly editing away the "heuristic, not proven-equivalent" caveat.
        let entry = EvidenceLibrary.entry(for: .exerciseSubstitution)
        #expect(entry.explanation.contains("heuristic"))
        #expect(entry.explanation.contains("not a proven-equivalent"))
    }

    @Test func everyCertaintyHasANonEmptyDistinctDisplayLabel() {
        let labels = EvidenceCertainty.allCases.map(\.displayLabel)
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == EvidenceCertainty.allCases.count)
    }
}
