import SwiftUI

struct ExperienceStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    private let experienceOptions = [
        ("beginner",     "Beginner",     "< 1 year",    "figure.walk"),
        ("intermediate", "Intermediate", "1–3 years",   "figure.run"),
        ("advanced",     "Advanced",     "3+ years",    "figure.strengthtraining.traditional"),
    ]

    private let goalOptions = [
        ("strength",     "Strength",    "Max lifts",        "arrow.up.circle.fill"),
        ("hypertrophy",  "Hypertrophy", "Muscle size",      "dumbbell.fill"),
        ("endurance",    "Endurance",   "Cardio & stamina", "heart.fill"),
        ("weight_loss",  "Weight Loss", "Lean & cut",       "flame.fill"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Training profile")
                    .font(.system(size: 28, weight: .bold))
                Text("Tell us about your experience level and what you're working towards.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Experience
            VStack(alignment: .leading, spacing: 10) {
                Text("EXPERIENCE LEVEL")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    ForEach(experienceOptions, id: \.0) { (id, label, sub, icon) in
                        ExperienceChip(
                            id: id, label: label, sub: sub, icon: icon,
                            isSelected: vm.experience == id
                        ) { vm.experience = id }
                    }
                }
            }

            // Goal
            VStack(alignment: .leading, spacing: 10) {
                Text("PRIMARY GOAL")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(goalOptions, id: \.0) { (id, label, sub, icon) in
                        GoalChip(
                            id: id, label: label, sub: sub, icon: icon,
                            isSelected: vm.trainingGoal == id
                        ) { vm.trainingGoal = id }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
}

private struct ExperienceChip: View {
    let id: String
    let label: String
    let sub: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.tint : Color.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.tint)
                }
            }
            .padding(14)
            .background(isSelected ? Color.tintSoft : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.tint : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GoalChip: View {
    let id: String
    let label: String
    let sub: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.tint : Color.secondary)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color.tintSoft : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.tint : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
