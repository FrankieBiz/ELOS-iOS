import SwiftUI

// MARK: - Data Models

private struct StretchRoutine: Identifiable {
    let id = UUID()
    let name: String
    let focus: String
    let durationMinutes: Int
    let icon: String
    let stretches: [Stretch]
}

private struct Stretch: Identifiable {
    let id = UUID()
    let name: String
    let holdSeconds: Int
    let sides: String   // "Both sides" | "Each side"
    let cue: String
}

// MARK: - Static Routine Library

private let allRoutines: [StretchRoutine] = [
    StretchRoutine(
        name: "Push Day Stretch",
        focus: "Chest · Shoulders · Triceps",
        durationMinutes: 5,
        icon: "hand.raised.fill",
        stretches: [
            Stretch(name: "Doorway Chest Opener",    holdSeconds: 30, sides: "Each side", cue: "Forearm on door frame, lean forward until you feel a stretch across the chest."),
            Stretch(name: "Cross-Body Shoulder",     holdSeconds: 30, sides: "Each side", cue: "Pull your arm across your chest at shoulder height. Press at the elbow, not the wrist."),
            Stretch(name: "Tricep Overhead Stretch", holdSeconds: 30, sides: "Each side", cue: "Reach hand down your back, elbow points up. Assist gently with your opposite hand."),
            Stretch(name: "Anterior Delt Wall",      holdSeconds: 30, sides: "Each side", cue: "Arm behind you, palm against wall. Slowly rotate your body away until you feel the front delt."),
        ]
    ),
    StretchRoutine(
        name: "Pull Day Stretch",
        focus: "Lats · Rhomboids · Biceps",
        durationMinutes: 5,
        icon: "arrow.down.circle.fill",
        stretches: [
            Stretch(name: "Standing Lat Side Bend",   holdSeconds: 30, sides: "Each side", cue: "Reach one arm overhead and lean away. Feel the stretch along your side from hip to armpit."),
            Stretch(name: "Rhomboid Doorframe",       holdSeconds: 30, sides: "Both sides", cue: "Grip a doorframe at shoulder height, round your upper back, and sit into the stretch."),
            Stretch(name: "Standing Bicep Wall",      holdSeconds: 30, sides: "Each side", cue: "Arm behind you, palm up, fingers pointing back. Rotate your body away until you feel the bicep."),
            Stretch(name: "Neck Lateral Tilt",        holdSeconds: 20, sides: "Each side", cue: "Drop your ear toward your shoulder. Apply very gentle fingertip pressure — never pull hard."),
        ]
    ),
    StretchRoutine(
        name: "Leg Day Stretch",
        focus: "Hip Flexors · Quads · Hamstrings · Calves",
        durationMinutes: 8,
        icon: "figure.walk",
        stretches: [
            Stretch(name: "Hip Flexor Kneeling Lunge", holdSeconds: 45, sides: "Each side", cue: "Back knee down, front knee at 90°. Drive hips forward and tall. Keep your core braced."),
            Stretch(name: "Standing Quad Stretch",     holdSeconds: 30, sides: "Each side", cue: "Hold your ankle behind you. Keep knees together and stand tall — don't let the hip flex open."),
            Stretch(name: "Standing Hamstring",        holdSeconds: 45, sides: "Each side", cue: "Foot elevated, hinge forward from the hips with a flat back. Avoid rounding your lower back."),
            Stretch(name: "Seated Piriformis",         holdSeconds: 45, sides: "Each side", cue: "Cross ankle over opposite knee. Sit tall and lean gently forward until you feel deep in the glute."),
            Stretch(name: "Calf Wall Stretch",         holdSeconds: 30, sides: "Each side", cue: "Heel on ground, toes up on wall. Lean hips forward for a deep calf and Achilles stretch."),
        ]
    ),
    StretchRoutine(
        name: "Upper Body Stretch",
        focus: "Chest · Back · Shoulders · Arms",
        durationMinutes: 7,
        icon: "figure.arms.open",
        stretches: [
            Stretch(name: "Doorway Chest Opener",    holdSeconds: 30, sides: "Each side", cue: "Forearm on door frame, lean forward until you feel a stretch across the chest."),
            Stretch(name: "Eagle Arms Stretch",      holdSeconds: 30, sides: "Each side", cue: "Cross your arms, wrap forearms, lift elbows to shoulder height. Feel stretch across upper back."),
            Stretch(name: "Tricep Overhead Stretch", holdSeconds: 30, sides: "Each side", cue: "Reach hand down your back, elbow points up. Assist gently with your opposite hand."),
            Stretch(name: "Lat Side Bend",           holdSeconds: 30, sides: "Each side", cue: "Reach one arm overhead and lean away. Feel the stretch along your side from hip to armpit."),
            Stretch(name: "Wrist Flexor Stretch",    holdSeconds: 20, sides: "Each side", cue: "Arm extended, palm facing up. Pull fingers back gently with your other hand."),
            Stretch(name: "Neck Rotation",           holdSeconds: 20, sides: "Each side", cue: "Slowly turn your chin toward your shoulder. Hold at the end range without forcing."),
        ]
    ),
    StretchRoutine(
        name: "Lower Body Stretch",
        focus: "Hips · Quads · Hamstrings · Glutes · Calves",
        durationMinutes: 8,
        icon: "figure.cooldown",
        stretches: [
            Stretch(name: "Hip Flexor Kneeling Lunge", holdSeconds: 45, sides: "Each side", cue: "Back knee down, front knee at 90°. Drive hips forward and tall. Keep your core braced."),
            Stretch(name: "Pigeon Pose",               holdSeconds: 60, sides: "Each side", cue: "Front shin horizontal across the mat, back leg extended. Walk hands forward and breathe into the stretch."),
            Stretch(name: "IT Band Standing Cross",    holdSeconds: 30, sides: "Each side", cue: "Stand tall, cross one leg behind the other. Reach the opposite arm overhead and lean away."),
            Stretch(name: "Standing Hamstring",        holdSeconds: 45, sides: "Each side", cue: "Foot elevated, hinge forward from the hips with a flat back. Avoid rounding your lower back."),
            Stretch(name: "Calf Wall Stretch",         holdSeconds: 30, sides: "Each side", cue: "Heel on ground, toes up on wall. Lean hips forward for a deep calf and Achilles stretch."),
        ]
    ),
    StretchRoutine(
        name: "Full Body Stretch",
        focus: "Full Body Mobility",
        durationMinutes: 10,
        icon: "sparkles",
        stretches: [
            Stretch(name: "Hip Flexor Kneeling Lunge", holdSeconds: 45, sides: "Each side", cue: "Back knee down, front knee at 90°. Drive hips forward and tall."),
            Stretch(name: "Standing Quad Stretch",     holdSeconds: 30, sides: "Each side", cue: "Hold ankle behind you. Keep knees together, stand tall."),
            Stretch(name: "Doorway Chest Opener",      holdSeconds: 30, sides: "Each side", cue: "Forearm on door frame, lean forward across the chest."),
            Stretch(name: "Lat Side Bend",             holdSeconds: 30, sides: "Each side", cue: "Reach overhead and lean away — feel the full side body."),
            Stretch(name: "Standing Hamstring",        holdSeconds: 45, sides: "Each side", cue: "Foot elevated, hinge forward with a flat back."),
            Stretch(name: "Tricep Overhead Stretch",   holdSeconds: 30, sides: "Each side", cue: "Elbow up, hand reaches down the back."),
            Stretch(name: "Calf Wall Stretch",         holdSeconds: 30, sides: "Each side", cue: "Heel down, toes on wall, lean into stretch."),
        ]
    ),
    StretchRoutine(
        name: "Recovery Day",
        focus: "Gentle Full Body · Breath Focus",
        durationMinutes: 12,
        icon: "leaf.fill",
        stretches: [
            Stretch(name: "Child's Pose",             holdSeconds: 60, sides: "Both sides", cue: "Kneel, sit back on heels, walk hands forward. Breathe slowly and let your spine lengthen."),
            Stretch(name: "Thread the Needle",        holdSeconds: 45, sides: "Each side",  cue: "On all fours, thread one arm under your body. Rest your shoulder and cheek on the ground."),
            Stretch(name: "Supine Spinal Twist",      holdSeconds: 60, sides: "Each side",  cue: "Lying on back, cross one knee over. Extend opposite arm out. Breathe — don't force the rotation."),
            Stretch(name: "Pigeon Pose",              holdSeconds: 60, sides: "Each side",  cue: "Front shin horizontal, back leg extended. Walk hands forward and breathe into the glute and hip."),
            Stretch(name: "90/90 Hip Stretch",        holdSeconds: 60, sides: "Each side",  cue: "Seated, both knees at 90° angles. Lean gently toward your front shin. Keep your back tall."),
            Stretch(name: "Neck Lateral Tilt",        holdSeconds: 30, sides: "Each side",  cue: "Ear toward shoulder, very gentle fingertip pressure. Never pull — let gravity do the work."),
        ]
    ),
    StretchRoutine(
        name: "Chest & Triceps",
        focus: "Chest · Triceps · Anterior Deltoid",
        durationMinutes: 5,
        icon: "arrow.up.right.circle.fill",
        stretches: [
            Stretch(name: "Doorway Chest Opener",      holdSeconds: 30, sides: "Each side", cue: "Forearm on door frame, lean forward until you feel a stretch across the chest."),
            Stretch(name: "Floor Chest Opener",        holdSeconds: 30, sides: "Both sides", cue: "Face down, hands under shoulders, press up into cobra. Open the chest toward the ceiling."),
            Stretch(name: "Tricep Overhead Stretch",   holdSeconds: 30, sides: "Each side", cue: "Reach hand down your back, elbow points up. Assist gently with your opposite hand."),
            Stretch(name: "Anterior Delt Wall",        holdSeconds: 30, sides: "Each side", cue: "Arm behind, palm against wall. Rotate your body away until you feel the front delt."),
        ]
    ),
    StretchRoutine(
        name: "Back & Biceps",
        focus: "Lats · Rhomboids · Biceps · Traps",
        durationMinutes: 5,
        icon: "arrow.down.left.circle.fill",
        stretches: [
            Stretch(name: "Child's Pose",             holdSeconds: 45, sides: "Both sides", cue: "Kneel, sit back, walk hands forward. Feel the lats and thoracic spine lengthen."),
            Stretch(name: "Rhomboid Doorframe",       holdSeconds: 30, sides: "Both sides", cue: "Grip doorframe at shoulder height, round your upper back, and sit into the stretch."),
            Stretch(name: "Standing Lat Side Bend",   holdSeconds: 30, sides: "Each side",  cue: "Reach one arm overhead and lean away. Feel the stretch along your side from hip to armpit."),
            Stretch(name: "Standing Bicep Wall",      holdSeconds: 30, sides: "Each side",  cue: "Arm behind you, palm up, fingers pointing back. Rotate your body away until you feel the bicep."),
        ]
    ),
    StretchRoutine(
        name: "Shoulders",
        focus: "All Three Delt Heads · Rotator Cuff",
        durationMinutes: 5,
        icon: "figure.arms.open",
        stretches: [
            Stretch(name: "Cross-Body Shoulder",    holdSeconds: 30, sides: "Each side", cue: "Pull your arm across your chest at shoulder height. Press at the elbow, not the wrist."),
            Stretch(name: "Eagle Arms Stretch",     holdSeconds: 30, sides: "Each side", cue: "Cross arms, wrap forearms, lift elbows. Deeply stretches the posterior deltoid and rotator cuff."),
            Stretch(name: "Anterior Delt Wall",     holdSeconds: 30, sides: "Each side", cue: "Arm behind, palm on wall. Rotate body away — feel the front of the shoulder open up."),
            Stretch(name: "Neck Lateral Tilt",      holdSeconds: 20, sides: "Each side", cue: "Ear toward shoulder with gentle fingertip pressure. Releases the upper traps and levator."),
        ]
    ),
]

// MARK: - Main View

struct StretchRoutinesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(allRoutines) { routine in
                        NavigationLink(destination: StretchRoutineDetailView(routine: routine)) {
                            StretchRoutineCard(routine: routine)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stretch Routines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.tint)
                }
            }
        }
    }
}

// MARK: - Routine Card

private struct StretchRoutineCard: View {
    let routine: StretchRoutine

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.tint.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: routine.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(routine.focus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(routine.stretches.count) stretches")
                    .font(.caption2)
                    .foregroundStyle(Color.tint)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(routine.durationMinutes) min")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Detail View

private struct StretchRoutineDetailView: View {
    let routine: StretchRoutine

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                VStack(spacing: 8) {
                    Image(systemName: routine.icon)
                        .font(.system(size: 32))
                        .foregroundStyle(Color.tint)
                    Text(routine.name)
                        .font(.title3).fontWeight(.bold)
                    Text(routine.focus)
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Label("\(routine.durationMinutes) min", systemImage: "clock")
                        Label("\(routine.stretches.count) stretches", systemImage: "list.bullet")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Stretches list
                VStack(spacing: 0) {
                    ForEach(Array(routine.stretches.enumerated()), id: \.element.id) { idx, stretch in
                        StretchRow(number: idx + 1, stretch: stretch)
                        if idx < routine.stretches.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stretch Row

private struct StretchRow: View {
    let number: Int
    let stretch: Stretch

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(stretch.name)
                    .font(.subheadline).fontWeight(.semibold)
                Text(stretch.cue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    holdBadge(stretch.holdSeconds)
                    sidesBadge(stretch.sides)
                }
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 14)
    }

    private func holdBadge(_ seconds: Int) -> some View {
        Text("\(seconds)s")
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(Color.tint)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func sidesBadge(_ sides: String) -> some View {
        Text(sides)
            .font(.caption2).fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }
}
