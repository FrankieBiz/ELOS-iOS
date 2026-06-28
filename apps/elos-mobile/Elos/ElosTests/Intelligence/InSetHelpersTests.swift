import Testing
@testable import Elos

struct InSetHelpersTests {
    @Test func restAdjustClampsAtZero() {
        #expect(RestMath.adjust(60, by: 15) == 75)
        #expect(RestMath.adjust(60, by: -15) == 45)
        #expect(RestMath.adjust(10, by: -15) == 0)   // never negative
        #expect(RestMath.adjust(0, by: -15) == 0)
    }

    @Test func rpeLadderCoversWorkingRange() {
        #expect(RPEScale.values.first == 6)
        #expect(RPEScale.values.last == 10)
        #expect(RPEScale.values.contains(7.5))
        #expect(RPEScale.values.contains(8.5))
    }

    @Test func rpeLabelsDropTrailingZero() {
        #expect(RPEScale.label(8) == "8")
        #expect(RPEScale.label(7.5) == "7.5")
        #expect(RPEScale.label(10) == "10")
    }

    @Test func rpeHintsMapToRepsInReserve() {
        #expect(RPEScale.hint(for: 10) == "max effort")
        #expect(RPEScale.hint(for: 8) == "~2 reps left")
        #expect(RPEScale.hint(for: 6) == "~4 reps left")
    }

    @Test func rpeParseRejectsJunk() {
        #expect(RPEScale.parse("8") == 8)
        #expect(RPEScale.parse("7.5") == 7.5)
        #expect(RPEScale.parse("") == nil)
        #expect(RPEScale.parse("0") == nil)
        #expect(RPEScale.parse("abc") == nil)
    }
}
