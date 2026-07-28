import Testing
@testable import Elos

struct MuscleVolumeAnalyzerTests {
    private let intermediate = TrainingProfile(goal: .hypertrophy, experience: .intermediate)

    private func analyze(_ days: [[ScoredExercise]],
                         scope: QualityScope = .weeklySplit,
                         intent: TrainingIntent? = nil,
                         dayNames: [String]? = nil) -> MuscleVolumeReport {
        QualityFixtures.volume(QualityFixtures.resolve(days), scope: scope,
                               profile: intermediate, intent: intent, dayNames: dayNames)
    }

    private func bar(_ r: MuscleVolumeReport, _ g: MuscleGroup) -> MuscleVolumeBar {
        r.bars.first { $0.group == g && $0.isGroupRow }!
    }

    // MARK: Shape

    @Test func producesOneRowPerGroupInOrder() {
        let r = analyze([[QualityFixtures.sx("bench", sets: 6)]])
        #expect(r.bars.count == MuscleGroup.allCases.count)
        #expect(r.bars.map(\.group) == MuscleGroup.allCases)
    }

    /// Single-child groups *are* their child, so they keep a real band and offer no pointless chevron.
    @Test func singleChildGroupsMirrorTheirChildAndDontExpand() {
        let r = analyze([[QualityFixtures.sx("bench", sets: 15)]])
        for g in [MuscleGroup.chest, .glutes, .core] {
            let b = bar(r, g)
            #expect(b.children.isEmpty, "\(g) should not expand")
            #expect(!b.isExpandable)
            #expect(b.band != nil, "\(g) has one child, so its band is meaningful")
        }
        #expect(bar(r, .chest).sets == 15)
    }

    /// Multi-child groups sum their children and deliberately carry no band — summing per-muscle
    /// targets would invent a meaningless number.
    @Test func multiChildGroupSumsChildrenAndHasNoBand() {
        let r = analyze([[
            QualityFixtures.sx("curl", sets: 6),      // biceps 6 direct
            QualityFixtures.sx("pushdown", sets: 4),  // triceps 4 direct
        ]])
        let arms = bar(r, .arms)
        #expect(arms.band == nil)
        #expect(arms.sets == 10)
        #expect(arms.isExpandable)
        #expect(arms.children.count == MuscleGroup.arms.children.count)
    }

    /// A group row takes its *worst* expected child's status, so one neglected muscle can't hide
    /// behind well-trained siblings.
    @Test func groupStatusTakesWorstExpectedChild() {
        // Quads well dosed, hamstrings and calves untrained.
        let r = analyze([[QualityFixtures.sx("squat", sets: 15)]])
        let legs = bar(r, .legs)
        #expect(legs.status == .untrained)
        #expect(legs.inRangeCount < legs.expectedCount)
    }

    // MARK: The zero-expected-children case (must not divide by zero)

    @Test func groupWithNoExpectedChildrenIsNeutralNotNaN() {
        let r = analyze([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("incline", sets: 4),
        ]], scope: .singleSession,
            intent: TrainingIntent(goal: .hypertrophy, focus: .push))

        let legs = bar(r, .legs)
        #expect(legs.expectedCount == 0)
        #expect(!legs.isExpected)
        #expect(legs.fill.isFinite)
        #expect(legs.fill == 0)
        for b in r.bars { #expect(b.fill.isFinite); #expect(b.directFill.isFinite) }
    }

    @Test func pushFocusDoesNotExpectHamstrings() {
        let r = analyze([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("ohp", sets: 4),
        ]], scope: .singleSession,
            intent: TrainingIntent(goal: .hypertrophy, focus: .push))
        #expect(!r.expected.contains(.hamstrings))
        #expect(r.expected.contains(.chest))
    }

    @Test func weeklyScopeExpectsEveryNonOptionalMuscle() {
        let r = analyze([[QualityFixtures.sx("bench", sets: 6)]])
        #expect(r.expected.contains(.hamstrings))
        #expect(r.expected.contains(.calves))
        // Prehab/indirect muscles are never demanded.
        #expect(!r.expected.contains(.rotatorCuff))
        #expect(!r.expected.contains(.forearms))
    }

    // MARK: Fill curve

    @Test func fillPutsTheProductiveBandInTheTopQuarter() {
        let band = TrainingScience.VolumeBand(mev: 8, targetLow: 14, targetHigh: 20, mrv: 26)
        #expect(MuscleVolumeAnalyzer.fill(sets: 0, band: band) == 0)
        #expect(MuscleVolumeAnalyzer.fill(sets: 7, band: band) == 0.375)
        #expect(MuscleVolumeAnalyzer.fill(sets: 14, band: band) == 0.75)
        #expect(MuscleVolumeAnalyzer.fill(sets: 17, band: band) == 0.875)
        #expect(MuscleVolumeAnalyzer.fill(sets: 20, band: band) == 1.0)
        // Overflow clamps — excess shows through `status`, not a bar past 100%.
        #expect(MuscleVolumeAnalyzer.fill(sets: 40, band: band) == 1.0)
    }

    @Test func statusLaddersThroughTheBand() {
        let band = TrainingScience.VolumeBand(mev: 8, targetLow: 14, targetHigh: 20, mrv: 26)
        #expect(MuscleVolumeAnalyzer.status(sets: 0, band: band) == .untrained)
        #expect(MuscleVolumeAnalyzer.status(sets: 5, band: band) == .under)
        #expect(MuscleVolumeAnalyzer.status(sets: 10, band: band) == .light)
        #expect(MuscleVolumeAnalyzer.status(sets: 16, band: band) == .productive)
        #expect(MuscleVolumeAnalyzer.status(sets: 24, band: band) == .high)
        #expect(MuscleVolumeAnalyzer.status(sets: 30, band: band) == .excessive)
    }

    @Test func untrainedOutranksExcessiveForAttention() {
        #expect(VolumeStatus.untrained.severity > VolumeStatus.excessive.severity)
        #expect(VolumeStatus.productive.severity == 0)
        #expect(VolumeStatus.productive.isOnTarget)
        #expect(VolumeStatus.high.isOnTarget)
        #expect(!VolumeStatus.light.isOnTarget)
    }

    // MARK: Direct vs indirect

    @Test func directAndIndirectAreTrackedSeparately() {
        let r = analyze([[QualityFixtures.sx("bench", sets: 10)]])
        let chest = r.creditByFine[.chest]!
        #expect(chest.direct == 10)
        #expect(chest.indirect == 0)
        #expect(chest.isTargeted)

        let triceps = r.creditByFine[.triceps]!
        #expect(triceps.direct == 0)
        #expect(triceps.indirect == 5)
        #expect(!triceps.isTargeted)
    }

    /// Frequency counts *direct* days only — two days of pressing don't train the triceps twice.
    @Test func directDaysCountsOnlyDirectWork() {
        let r = analyze([
            [QualityFixtures.sx("bench", sets: 5)],
            [QualityFixtures.sx("incline", sets: 5)],
            [QualityFixtures.sx("pushdown", sets: 4)],
        ], dayNames: ["A", "B", "C"])
        #expect(r.directDaysByFine[.chest] == 2)
        #expect(r.directDaysByFine[.triceps] == 1)   // bench's indirect days don't count
    }
}
