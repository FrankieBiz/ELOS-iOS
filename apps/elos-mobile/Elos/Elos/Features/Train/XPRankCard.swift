import SwiftUI

struct XPRankCard: View {
    let progress: GamificationEngine.UserProgress
    let workoutStreak: Int
    let sessionCount: Int
    let prCount: Int

    @State private var rankPathExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            topRow
            progressSection
            rankTrack
            Divider().padding(.vertical, 2)
            statsRow
            rankPathToggle
            if rankPathExpanded {
                rankPathSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .elosCard()
    }

    // MARK: Top row

    private var topRow: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(progress.rank.color.opacity(0.15))
                    .frame(width: 54, height: 54)
                Image(systemName: progress.rank.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(progress.rank.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(progress.rank.rawValue.uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(progress.rank.color)
                Text("\(progress.totalXP) XP total")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let next = progress.rank.nextRank {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(progress.xpToNext)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                    Text("to \(next.rawValue)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Max Rank", systemImage: "crown.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(progress.rank.color)
            }
        }
    }

    // MARK: Progress bar

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [progress.rank.color.opacity(0.7), progress.rank.color],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * CGFloat(progress.progress)), height: 10)
                        .animation(.easeOut(duration: 0.9), value: progress.progress)
                }
            }
            .frame(height: 10)
            HStack {
                Text(progress.rank.rawValue)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(progress.rank.color)
                Spacer()
                if let next = progress.rank.nextRank {
                    Text(next.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Rank track (mini dot path)

    private var rankTrack: some View {
        HStack(spacing: 0) {
            ForEach(GamificationEngine.Rank.ordered, id: \.self) { rank in
                let reached  = rank.minXP <= progress.totalXP
                let isCurrent = rank == progress.rank
                VStack(spacing: 4) {
                    ZStack {
                        if isCurrent {
                            Circle()
                                .stroke(rank.color.opacity(0.35), lineWidth: 3)
                                .frame(width: 22, height: 22)
                        }
                        Circle()
                            .fill(reached ? rank.color : Color.secondary.opacity(0.12))
                            .frame(width: isCurrent ? 16 : 11, height: isCurrent ? 16 : 11)
                        if reached && !isCurrent {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .black))
                                .foregroundStyle(.white)
                        }
                        if isCurrent {
                            Image(systemName: rank.icon)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 24, height: 24)
                    Text(String(rank.rawValue.prefix(3)).uppercased())
                        .font(.system(size: 7, weight: isCurrent ? .bold : .regular))
                        .foregroundStyle(
                            isCurrent ? rank.color
                            : (reached ? Color.secondary : Color.secondary.opacity(0.3))
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(icon: "flame.fill",    color: .orange,    value: "\(workoutStreak)d", label: "Streak")
            Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1, height: 36)
            statCell(icon: "dumbbell.fill", color: Color.tint, value: "\(sessionCount)",   label: "Sessions")
            Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1, height: 36)
            statCell(icon: "trophy.fill",   color: .yellow,    value: "\(prCount)",        label: "PRs")
        }
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statCell(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: Rank path toggle

    private var rankPathToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { rankPathExpanded.toggle() }
        } label: {
            HStack {
                Text("Rank Path")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: rankPathExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Rank path (expanded)

    private var rankPathSection: some View {
        VStack(spacing: 8) {
            ForEach(GamificationEngine.Rank.ordered, id: \.self) { rank in
                let isUnlocked = rank.minXP <= progress.totalXP
                let isCurrent  = rank == progress.rank
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isUnlocked ? rank.color.opacity(0.15) : Color.secondary.opacity(0.07))
                            .frame(width: 36, height: 36)
                        Image(systemName: rank.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isUnlocked ? rank.color : Color.secondary.opacity(0.3))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rank.rawValue)
                            .font(.system(size: 14, weight: isCurrent ? .bold : .regular))
                            .foregroundStyle(isUnlocked ? .primary : .secondary)
                        Text("\(rank.minXP) XP")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isCurrent {
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(rank.color)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(rank.color.opacity(0.12))
                            .clipShape(Capsule())
                    } else if isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(rank.color)
                    } else {
                        Text("+\(rank.minXP - progress.totalXP) XP")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
