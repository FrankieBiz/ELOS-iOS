import SwiftUI

// MARK: - Screens
//
// The personalization system has one hard rule: **the catalog is the only place that knows what a
// screen contains.** A screen's view file says "render section X here"; it never decides the order,
// the visibility, or the width. That's what makes "move this above that" a stored preference rather
// than a code change.
//
// Adding something the user can rearrange is therefore three edits, never five:
//   1. add a `LayoutSection` case (its position here is its default position on screen),
//   2. give it a descriptor below,
//   3. render it in that screen's `SectionStack` closure.

/// A screen whose contents the user can rearrange.
enum CustomizableScreen: String, CaseIterable, Codable, Identifiable, Hashable {
    case today, train, plan, me, stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .train: return "Train"
        case .plan:  return "Plan"
        case .me:    return "Me"
        case .stats: return "Stats"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .train: return "dumbbell"
        case .plan:  return "list.clipboard"
        case .me:    return "person.circle"
        case .stats: return "chart.line.uptrend.xyaxis"
        }
    }

    /// Today reads as a dashboard of widgets; the rest read as screens with sections. Only affects
    /// wording in the editor, but calling a card on Today a "section" made the dashboard feel less
    /// like something you assemble.
    var itemNoun: String { self == .today ? "widget" : "section" }
    var itemNounPlural: String { self == .today ? "widgets" : "sections" }

    var tab: AppTab {
        switch self {
        case .today: return .today
        case .train: return .train
        case .plan:  return .plan
        case .me:    return .me
        case .stats: return .stats
        }
    }
}

// MARK: - Span

/// How wide a section sits in the stack.
///
/// `half` is a *request*, not a guarantee: two consecutive halves pair into one row, and a half with
/// no partner falls back to full width rather than leaving a stranded narrow card beside a hole.
/// See `SectionRowPacker`.
enum SectionSpan: String, Codable, Hashable, CaseIterable {
    case full, half

    var label: String { self == .full ? "Full width" : "Half width" }
    var icon: String { self == .full ? "rectangle" : "rectangle.split.2x1" }
}

// MARK: - Descriptor

struct SectionDescriptor {
    let screen: CustomizableScreen
    /// Name shown in the editor and the on-page edit chrome.
    let title: String
    /// One line explaining what it shows — the editor is a list of names otherwise.
    let blurb: String
    let icon: String
    /// Always visible and unmovable. Reserved for the two places that would otherwise let someone
    /// lock themselves out: the Me screen's settings list (the only route into Settings, which is
    /// where personalization itself lives) and Train's start button (the app's primary action).
    var isPinned: Bool = false
    /// Whether the half/full control is offered. False for anything whose content genuinely needs
    /// the full width — a timeline, an exercise list, a chart with axis labels. Offering a control
    /// that produces a broken layout isn't more customization, it's a trap.
    var canResize: Bool = false
    var defaultSpan: SectionSpan = .full
    /// Ships hidden. Used for the extra dashboard widgets, so the default Today screen stays the
    /// screen people already know and the rest are opt-in from the picker.
    var isOptIn: Bool = false
}

// MARK: - Sections
//
// Declaration order per screen == default on-screen order.

enum LayoutSection: String, CaseIterable, Codable, Identifiable, Hashable {
    // Today
    case todayGreeting
    case todayRecovery
    case todayGymSwitcher
    case todayBrief
    case todayHabits
    case todaySchedule
    case todayUpcoming
    case todaySleep
    case todayGymVolume
    case todayHydration
    // …and the opt-in dashboard widgets, off by default.
    case todayStreak
    case todaySessionsThisWeek
    case todayWeeklyVolume
    case todayNextWorkout
    case todayLatestPR
    case todayReadiness
    case todayBodyWeight
    case todayMuscleFocus

    // Train
    case trainDeload
    case trainRank
    case trainStatus
    case trainWeekStrip
    case trainLeaderboard
    case trainQuickActions
    case trainRecents
    case trainStart
    case trainExercises
    case trainMuscleVolume
    case trainRadar
    case trainPRs

    // Plan (Schedule tab)
    case planDayPicker
    case planTimeline
    case planLoadSummary
    case planThisWeek

    // Me
    case meProfile
    case meFriends
    case meWellness
    case meHabits
    case meSettings

    // Stats
    case statsSummary
    case statsLiftPicker
    case statsE1RM
    case statsVolume
    case statsPRs

    var id: String { rawValue }

    var descriptor: SectionDescriptor {
        switch self {

        // MARK: Today
        case .todayGreeting:
            return .init(screen: .today, title: "Greeting",
                         blurb: "The date and your name at the top of the screen.",
                         icon: "hand.wave")
        case .todayRecovery:
            return .init(screen: .today, title: "Recovery hint",
                         blurb: "Appears when Apple Health sees your resting heart rate above baseline.",
                         icon: "heart.text.square")
        case .todayGymSwitcher:
            return .init(screen: .today, title: "Gym switcher",
                         blurb: "Change which gym today's workout is built for.",
                         icon: "building.2")
        case .todayBrief:
            return .init(screen: .today, title: "Daily brief",
                         blurb: "Today's headline: what's on, and what to do first.",
                         icon: "text.alignleft")
        case .todayHabits:
            return .init(screen: .today, title: "Habits",
                         blurb: "Your habit pills and streaks.",
                         icon: "checkmark.circle")
        case .todaySchedule:
            return .init(screen: .today, title: "Schedule",
                         blurb: "Everything on today's timeline, workouts included.",
                         icon: "calendar.day.timeline.left")
        case .todayUpcoming:
            return .init(screen: .today, title: "Upcoming due",
                         blurb: "The next three assignments that aren't done.",
                         icon: "tray.full")
        case .todaySleep:
            return .init(screen: .today, title: "Sleep",
                         blurb: "Last night's hours and quality. Tap to log.",
                         icon: "bed.double", canResize: true, defaultSpan: .half)
        case .todayGymVolume:
            return .init(screen: .today, title: "Gym volume",
                         blurb: "Volume lifted today, or in the live session.",
                         icon: "scalemass", canResize: true, defaultSpan: .half)
        case .todayHydration:
            return .init(screen: .today, title: "Hydration",
                         blurb: "Water logged against your goal, with quick adjust buttons.",
                         icon: "drop", canResize: true)
        case .todayStreak:
            return .init(screen: .today, title: "Streak",
                         blurb: "Consecutive weeks you've trained.",
                         icon: "flame", canResize: true, defaultSpan: .half, isOptIn: true)
        case .todaySessionsThisWeek:
            return .init(screen: .today, title: "Sessions this week",
                         blurb: "Workouts finished against what your split plans.",
                         icon: "figure.strengthtraining.traditional",
                         canResize: true, defaultSpan: .half, isOptIn: true)
        case .todayWeeklyVolume:
            return .init(screen: .today, title: "Weekly volume",
                         blurb: "Everything lifted over the last seven days.",
                         icon: "chart.bar", canResize: true, defaultSpan: .half, isOptIn: true)
        case .todayNextWorkout:
            return .init(screen: .today, title: "Next workout",
                         blurb: "What your split has queued, with a start button.",
                         icon: "play.circle", canResize: true, isOptIn: true)
        case .todayLatestPR:
            return .init(screen: .today, title: "Latest PR",
                         blurb: "Your most recent personal record.",
                         icon: "trophy", canResize: true, defaultSpan: .half, isOptIn: true)
        case .todayReadiness:
            return .init(screen: .today, title: "Readiness",
                         blurb: "Today's check-in score, or a prompt to take it.",
                         icon: "gauge.medium", canResize: true, defaultSpan: .half, isOptIn: true)
        case .todayBodyWeight:
            return .init(screen: .today, title: "Body weight",
                         blurb: "Your latest logged weight and the change since before it.",
                         icon: "figure.stand", canResize: true, defaultSpan: .half, isOptIn: true)
        case .todayMuscleFocus:
            return .init(screen: .today, title: "Muscle focus",
                         blurb: "Which muscles this week's volume actually went to.",
                         icon: "figure.arms.open", canResize: true, isOptIn: true)

        // MARK: Train
        case .trainDeload:
            return .init(screen: .train, title: "Deload banner",
                         blurb: "Appears when your recent load suggests backing off.",
                         icon: "arrow.down.circle")
        case .trainRank:
            return .init(screen: .train, title: "Rank & XP",
                         blurb: "Level, XP bar, streak and session count.",
                         icon: "rosette")
        case .trainStatus:
            return .init(screen: .train, title: "Today's program",
                         blurb: "The day's header — or the rest-day, no-split or readiness prompt.",
                         icon: "calendar.badge.clock")
        case .trainWeekStrip:
            return .init(screen: .train, title: "Week strip",
                         blurb: "The seven-day row across the top of your split.",
                         icon: "calendar")
        case .trainLeaderboard:
            return .init(screen: .train, title: "Leaderboard",
                         blurb: "Where you sit against your crew this week.",
                         icon: "list.number")
        case .trainQuickActions:
            return .init(screen: .train, title: "Quick actions",
                         blurb: "The tile grid: library, history, templates, discover…",
                         icon: "square.grid.2x2")
        case .trainRecents:
            return .init(screen: .train, title: "Recent lifts",
                         blurb: "Chips for the exercises you've trained most recently.",
                         icon: "clock.arrow.circlepath")
        case .trainStart:
            return .init(screen: .train, title: "Start workout",
                         blurb: "The primary button. Always shown.",
                         icon: "play.fill", isPinned: true)
        case .trainExercises:
            return .init(screen: .train, title: "Today's exercises",
                         blurb: "The list of lifts queued for this session.",
                         icon: "list.bullet")
        case .trainMuscleVolume:
            return .init(screen: .train, title: "Muscle volume",
                         blurb: "Set counts per muscle against your weekly targets.",
                         icon: "chart.bar.xaxis")
        case .trainRadar:
            return .init(screen: .train, title: "Weekly radar",
                         blurb: "Balance across muscle groups, as a radar chart.",
                         icon: "circle.hexagongrid")
        case .trainPRs:
            return .init(screen: .train, title: "Personal records",
                         blurb: "Your current best on each lift.",
                         icon: "trophy")

        // MARK: Plan
        case .planDayPicker:
            return .init(screen: .plan, title: "Day picker",
                         blurb: "The scrolling row of upcoming days.",
                         icon: "calendar.day.timeline.left")
        case .planTimeline:
            return .init(screen: .plan, title: "Timeline",
                         blurb: "Everything scheduled on the selected day.",
                         icon: "list.bullet.indent")
        case .planLoadSummary:
            return .init(screen: .plan, title: "Load summary",
                         blurb: "How heavy the selected day is, training and schoolwork.",
                         icon: "gauge.with.dots.needle.33percent")
        case .planThisWeek:
            return .init(screen: .plan, title: "This week",
                         blurb: "Training days and assignments landing over the next seven days.",
                         icon: "calendar.badge.clock")

        // MARK: Me
        case .meProfile:
            return .init(screen: .me, title: "Profile",
                         blurb: "Your avatar, name and headline numbers.",
                         icon: "person.crop.circle")
        case .meFriends:
            return .init(screen: .me, title: "Friends",
                         blurb: "A strip of your crew, with a route into the full list.",
                         icon: "person.2")
        case .meWellness:
            return .init(screen: .me, title: "Wellness",
                         blurb: "Sleep and hydration together in one card.",
                         icon: "heart")
        case .meHabits:
            return .init(screen: .me, title: "Habits",
                         blurb: "The full habit list with streaks.",
                         icon: "checkmark.circle")
        case .meSettings:
            return .init(screen: .me, title: "Settings",
                         blurb: "Preferences, Canvas sync and About. Always shown — it's the way back here.",
                         icon: "gearshape", isPinned: true)

        // MARK: Stats
        case .statsSummary:
            return .init(screen: .stats, title: "Summary",
                         blurb: "The four headline figures at the top.",
                         icon: "square.grid.2x2")
        case .statsLiftPicker:
            return .init(screen: .stats, title: "Lift picker",
                         blurb: "Chooses which lift the charts below are about.",
                         icon: "line.3.horizontal.decrease.circle")
        case .statsE1RM:
            return .init(screen: .stats, title: "Estimated 1RM",
                         blurb: "Your strength trend on the selected lift.",
                         icon: "chart.line.uptrend.xyaxis")
        case .statsVolume:
            return .init(screen: .stats, title: "Volume",
                         blurb: "Weekly volume by muscle group against target.",
                         icon: "chart.bar")
        case .statsPRs:
            return .init(screen: .stats, title: "PR board",
                         blurb: "Every personal record, newest first.",
                         icon: "trophy")
        }
    }

    // Convenience passthroughs — `section.title` reads better than `section.descriptor.title` at the
    // dozens of call sites in the editor.
    var screen: CustomizableScreen { descriptor.screen }
    var title: String { descriptor.title }
    var blurb: String { descriptor.blurb }
    var icon: String { descriptor.icon }
    var isPinned: Bool { descriptor.isPinned }
    var canResize: Bool { descriptor.canResize }
    var defaultSpan: SectionSpan { descriptor.defaultSpan }
    var isOptIn: Bool { descriptor.isOptIn }

    /// The shipped order for a screen — which is simply the order the cases are written above.
    static func defaultOrder(for screen: CustomizableScreen) -> [LayoutSection] {
        allCases.filter { $0.descriptor.screen == screen }
    }
}

// MARK: - Placement

struct PlacedSection: Identifiable, Hashable {
    let section: LayoutSection
    let span: SectionSpan
    /// True when the screen says this section has nothing to show right now (no PRs yet, no active
    /// split…). Kept rather than filtered so edit mode can still draw a placeholder you can move.
    var isAvailable: Bool = true

    var id: LayoutSection { section }
}

/// One rendered row: either a single full-width section, or two halves side by side.
enum SectionRow: Identifiable, Hashable {
    case single(PlacedSection)
    case pair(PlacedSection, PlacedSection)

    var id: String {
        switch self {
        case .single(let p):      return p.section.rawValue
        case .pair(let a, let b): return "\(a.section.rawValue)+\(b.section.rawValue)"
        }
    }

    var sections: [PlacedSection] {
        switch self {
        case .single(let p):      return [p]
        case .pair(let a, let b): return [a, b]
        }
    }
}

/// Turns a flat ordered list of placements into rows.
///
/// Pure on purpose: the pairing rule is the one piece of the layout system with real edge cases
/// (odd counts, a half between two fulls, a half at the very end), and it's far cheaper to pin those
/// down in unit tests than to chase them through a running app.
enum SectionRowPacker {
    static func pack(_ placed: [PlacedSection]) -> [SectionRow] {
        var rows: [SectionRow] = []
        var i = 0
        while i < placed.count {
            let current = placed[i]
            if current.span == .half, i + 1 < placed.count, placed[i + 1].span == .half {
                rows.append(.pair(current, placed[i + 1]))
                i += 2
            } else {
                // A half with no partner behind it renders full width. The alternative — a narrow
                // card with dead space beside it — looks like a bug rather than a choice.
                rows.append(.single(current))
                i += 1
            }
        }
        return rows
    }
}

// MARK: - Order resolution

/// Merges a stored order with the current catalog.
///
/// The stored order is authoritative for everything it names. Anything the catalog has gained since
/// (a section added in an app update) is slotted in **after the section it shipped behind**, so a new
/// widget lands where its author put it rather than being dumped at the bottom of someone's
/// carefully arranged screen. Anything the catalog has *lost* is dropped.
enum LayoutResolver {
    static func resolveOrder(stored: [LayoutSection], catalog: [LayoutSection]) -> [LayoutSection] {
        let valid = Set(catalog)
        var result: [LayoutSection] = []
        var seen: Set<LayoutSection> = []
        for section in stored where valid.contains(section) && !seen.contains(section) {
            result.append(section)
            seen.insert(section)
        }
        guard result.count != catalog.count else { return result }

        for (index, section) in catalog.enumerated() where !seen.contains(section) {
            // Walk back through the catalog for the nearest earlier neighbour the user already has,
            // and land immediately after it. No earlier neighbour survives → it belongs at the top.
            var insertAt = 0
            for previous in catalog[..<index].reversed() {
                if let position = result.firstIndex(of: previous) {
                    insertAt = position + 1
                    break
                }
            }
            result.insert(section, at: insertAt)
            seen.insert(section)
        }
        return result
    }
}
