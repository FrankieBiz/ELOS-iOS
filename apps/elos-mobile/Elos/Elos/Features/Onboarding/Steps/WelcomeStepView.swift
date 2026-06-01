import SwiftUI

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text("ELOS")
                    .font(.system(size: 60, weight: .black))
                    .foregroundStyle(Color.tint)
                Text("Everyday Life\nOperating System")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }

            Spacer().frame(height: 40)

            VStack(spacing: 12) {
                FeatureRow(icon: "dumbbell.fill",        color: .mGym,    title: "Train",    subtitle: "Workout tracking & progressive overload")
                FeatureRow(icon: "fork.knife",           color: .mNutri,  title: "Fuel",     subtitle: "Nutrition goals & macro targets")
                FeatureRow(icon: "calendar.badge.clock", color: .mSched,  title: "Plan",     subtitle: "Academic schedule, exams & assignments")
                FeatureRow(icon: "flame.fill",           color: .mHabits, title: "Habits",   subtitle: "Daily streaks & accountability")
            }

            Spacer()

            Text("Profile setup takes about 2 minutes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)
        }
        .padding(.horizontal, 24)
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
