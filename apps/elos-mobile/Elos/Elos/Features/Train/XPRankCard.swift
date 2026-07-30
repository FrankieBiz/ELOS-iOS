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
                Text(progress.rank.rawValue)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(progress.rank.color)
                Text("\(progress.totalXP.formatted()) XP")
                    .font(.elosNumeric(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Space.s)
            if let next = progress.rank.nextRank {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(progress.xpToNext.formatted())
                        .font(.elosNumeric(.title3, weight: .bold))
                    Text("to \(next.rawValue)")
                        .font(.elosMicro)
                        .foregroundStyle(.secondary)
                }
                .fixedSize()
            } else {
                Label("Max Rank", systemImage: "crown.fill")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(progress.rank.color)
            }
        }
    }

    // MARK: Progress bar

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
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
            // The bar used to be captioned with the current and next rank names at its ends — a
            // verbatim repeat of the two labels sitting directly above it. Dropped; the row that
            // remains is the one piece of information the header doesn't already carry.
            if let next = progress.rank.nextRank {
                HStack {
                    Text("\(progress.totalXP - progress.rank.minXP) / \(next.minXP - progress.rank.minXP) XP")
                        .font(.elosNumeric(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress.progress * 100))%")
                        .font(.elosNumeric(.caption2, weight: .semibold))
                        .foregroundStyle(progress.rank.color)
                }
            }
        }
    }

    // MARK: Rank track (mini dot path)

    private var rankTrack: some View {
        // Every dot used to be labelled with a three-letter abbreviation — ROO, CON, ATH, ELI, CHA,
        // LEG — which reads as invented jargon and, at 6–7pt, as grey smudges. It was also the third
        // place on this one card that named the ranks (header, progress-bar ends, here, and again in
        // the expanded path). Each rank now shows its own symbol and nothing else: the header already
        // says which rank you are, so the rail only has to answer "how far along the road am I".
        HStack(spacing: Space.xs) {
            ForEach(Array(GamificationEngine.Rank.ordered.enumerated()), id: \.element) { i, rank in
                let reached   = rank.minXP <= progress.totalXP
                let isCurrent = rank == progress.rank

                if i > 0 {
                    Capsule()
                        .fill(reached ? rank.color.opacity(0.5) : Color.secondary.opacity(0.14))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }

                ZStack {
                    Circle()
                        .fill(reached ? rank.color.opacity(isCurrent ? 1 : 0.22)
                                      : Color.secondary.opacity(0.12))
                        .frame(width: isCurrent ? 32 : 24, height: isCurrent ? 32 : 24)
                    Image(systemName: rank.icon)
                        .font(.system(size: isCurrent ? 14 : 10, weight: .semibold))
                        .foregroundStyle(
                            isCurrent ? .white
                            : (reached ? rank.color : Color.secondary.opacity(0.45))
                        )
                }
                .frame(width: 32, height: 32)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rank.rawValue)
                .accessibilityValue(isCurrent ? "current rank" : (reached ? "unlocked" : "locked"))
            }
        }
        .animation(.snappy(duration: 0.3), value: progress.rank)
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
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statCell(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.elosMicro)
                    .foregroundStyle(color)
                Text(value)
                    .font(.elosNumeric(.callout, weight: .bold))
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.elosMicro)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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
                            .font(.system(.subheadline, weight: isCurrent ? .bold : .regular))
                            .foregroundStyle(isUnlocked ? .primary : .secondary)
                        Text("\(rank.minXP.formatted()) XP")
                            .font(.elosNumeric(.caption2, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isCurrent {
                        // "YOU" in a 9pt shouting caps badge was the loudest thing in the list for
                        // information the filled row already conveys. A quiet word does the job.
                        Text("Current")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(rank.color)
                            .padding(.horizontal, Space.s).padding(.vertical, 3)
                            .background(rank.color.opacity(0.14), in: Capsule())
                    } else if isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(rank.color)
                    } else {
                        Text("+\((rank.minXP - progress.totalXP).formatted())")
                            .font(.elosNumeric(.caption2, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
