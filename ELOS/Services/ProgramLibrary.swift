import Foundation
import SwiftUI

// MARK: - Program (a multi-day training split)

struct Program: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let description: String
    let daysPerWeek: Int
    let days: [ProgramDay]
    let level: Experience
    let icon: String
    let accent: Color
}

struct ProgramDay: Identifiable, Hashable {
    let id = UUID()
    let title: String         // "Push", "Pull", "Legs"
    let focus: String         // "Chest · Triceps"
    let exerciseIds: [String] // refs to ExerciseDefinition.library
    var isRest: Bool { exerciseIds.isEmpty }
}

extension Program {

    static let library: [Program] = [
        ppl,
        upperLower,
        fullBody3x,
        fiveThreeOne,
        broSplit,
    ]

    static func find(id: String) -> Program {
        library.first { $0.id == id } ?? ppl
    }

    /// Returns today's day index for a given program (0-based, modulo days.count).
    static func todayIndex(for program: Program, startDate: Date) -> Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: startDate),
                                      to: cal.startOfDay(for: .now)).day ?? 0
        guard program.days.count > 0 else { return 0 }
        return ((days % program.days.count) + program.days.count) % program.days.count
    }

    static func todayDay(for program: Program, startDate: Date) -> ProgramDay {
        program.days[todayIndex(for: program, startDate: startDate)]
    }

    static var ppl: Program {
        .init(
            id: "ppl_default",
            name: "Push · Pull · Legs",
            subtitle: "6-day classic split",
            description: "Train each muscle group twice per week with high volume. Best for hypertrophy.",
            daysPerWeek: 6,
            days: [
                .init(title: "Push", focus: "Chest · Shoulders · Triceps",
                      exerciseIds: ["chest_1", "chest_2", "sh_1", "sh_2", "tri_3", "tri_5"]),
                .init(title: "Pull", focus: "Back · Biceps",
                      exerciseIds: ["back_1", "back_2", "back_5", "back_7", "bi_1", "bi_3"]),
                .init(title: "Legs", focus: "Quads · Hams · Glutes",
                      exerciseIds: ["leg_1", "leg_2", "leg_3", "leg_5", "leg_9"]),
                .init(title: "Push", focus: "Hypertrophy",
                      exerciseIds: ["chest_2", "chest_3", "sh_3", "sh_2", "tri_1", "tri_3"]),
                .init(title: "Pull", focus: "Back focus",
                      exerciseIds: ["back_3", "back_4", "back_6", "back_7", "bi_5", "bi_2"]),
                .init(title: "Legs", focus: "Posterior chain",
                      exerciseIds: ["glu_1", "leg_2", "leg_8", "leg_5", "leg_9"]),
                .init(title: "Rest", focus: "Mobility & recovery", exerciseIds: []),
            ],
            level: .intermediate,
            icon: "bolt.fill",
            accent: Color(hex: "#FF6B35")
        )
    }

    static var upperLower: Program {
        .init(
            id: "ul_default",
            name: "Upper / Lower",
            subtitle: "4-day balanced split",
            description: "Solid 4x/week split with strength + hypertrophy. Great for intermediates.",
            daysPerWeek: 4,
            days: [
                .init(title: "Upper", focus: "Strength",
                      exerciseIds: ["chest_1", "back_3", "sh_1", "back_2", "bi_1", "tri_4"]),
                .init(title: "Lower", focus: "Strength",
                      exerciseIds: ["leg_1", "leg_2", "leg_3", "leg_9"]),
                .init(title: "Rest", focus: "Active recovery", exerciseIds: []),
                .init(title: "Upper", focus: "Hypertrophy",
                      exerciseIds: ["chest_2", "back_4", "sh_3", "back_6", "bi_2", "tri_3"]),
                .init(title: "Lower", focus: "Hypertrophy",
                      exerciseIds: ["leg_7", "glu_1", "leg_5", "leg_6", "leg_9"]),
                .init(title: "Rest", focus: "Mobility", exerciseIds: []),
                .init(title: "Rest", focus: "Off", exerciseIds: []),
            ],
            level: .intermediate,
            icon: "rectangle.split.2x1.fill",
            accent: Color(hex: "#5E5CE6")
        )
    }

    static var fullBody3x: Program {
        .init(
            id: "fb_3x",
            name: "Full Body 3×",
            subtitle: "3-day starter program",
            description: "Hit every major muscle group three times per week. Ideal for beginners.",
            daysPerWeek: 3,
            days: [
                .init(title: "Day A", focus: "Squat focus",
                      exerciseIds: ["leg_1", "chest_1", "back_3", "sh_1", "co_3"]),
                .init(title: "Rest", focus: "Recovery", exerciseIds: []),
                .init(title: "Day B", focus: "Deadlift focus",
                      exerciseIds: ["back_1", "chest_2", "back_2", "leg_5", "co_2"]),
                .init(title: "Rest", focus: "Recovery", exerciseIds: []),
                .init(title: "Day C", focus: "Press focus",
                      exerciseIds: ["sh_1", "leg_3", "back_4", "chest_5", "tri_3"]),
                .init(title: "Rest", focus: "Recovery", exerciseIds: []),
                .init(title: "Rest", focus: "Off", exerciseIds: []),
            ],
            level: .beginner,
            icon: "circle.grid.cross.fill",
            accent: Color(hex: "#30D158")
        )
    }

    static var fiveThreeOne: Program {
        .init(
            id: "531_default",
            name: "5/3/1",
            subtitle: "Strength template",
            description: "Wendler's 5/3/1 — slow, methodical strength gains around 4 main lifts.",
            daysPerWeek: 4,
            days: [
                .init(title: "OHP", focus: "Press day",
                      exerciseIds: ["sh_1", "back_2", "tri_1", "co_1"]),
                .init(title: "DL", focus: "Deadlift day",
                      exerciseIds: ["back_1", "back_4", "co_3"]),
                .init(title: "Rest", focus: "Off", exerciseIds: []),
                .init(title: "Bench", focus: "Bench day",
                      exerciseIds: ["chest_1", "back_6", "tri_4", "bi_1"]),
                .init(title: "Squat", focus: "Squat day",
                      exerciseIds: ["leg_1", "leg_2", "leg_9"]),
                .init(title: "Rest", focus: "Off", exerciseIds: []),
                .init(title: "Rest", focus: "Off", exerciseIds: []),
            ],
            level: .advanced,
            icon: "5.circle.fill",
            accent: Color(hex: "#FF453A")
        )
    }

    static var broSplit: Program {
        .init(
            id: "bro_split",
            name: "Bro Split",
            subtitle: "5-day classic",
            description: "Train one body part per day. High volume, classic bodybuilding approach.",
            daysPerWeek: 5,
            days: [
                .init(title: "Chest", focus: "Mon",
                      exerciseIds: ["chest_1", "chest_2", "chest_3", "chest_5", "chest_7"]),
                .init(title: "Back", focus: "Tue",
                      exerciseIds: ["back_2", "back_3", "back_4", "back_6", "back_7"]),
                .init(title: "Shoulders", focus: "Wed",
                      exerciseIds: ["sh_1", "sh_2", "sh_3", "sh_5", "sh_6"]),
                .init(title: "Arms", focus: "Thu",
                      exerciseIds: ["bi_1", "bi_3", "bi_4", "tri_3", "tri_1", "tri_5"]),
                .init(title: "Legs", focus: "Fri",
                      exerciseIds: ["leg_1", "leg_3", "leg_5", "leg_6", "leg_9"]),
                .init(title: "Rest", focus: "Sat", exerciseIds: []),
                .init(title: "Rest", focus: "Sun", exerciseIds: []),
            ],
            level: .intermediate,
            icon: "calendar",
            accent: Color(hex: "#BF5AF2")
        )
    }
}
