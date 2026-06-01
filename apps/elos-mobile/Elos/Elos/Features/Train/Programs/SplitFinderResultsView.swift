import SwiftUI

struct SplitFinderResultsView: View {
    @State private var recommendations: [SplitRecommendation]
    let input: SplitFinderInput
    let dismissAll: () -> Void

    @State private var selectedRec: SplitRecommendation?
    @State private var showSubscribe = false

    init(recommendations: [SplitRecommendation], input: SplitFinderInput, dismissAll: @escaping () -> Void) {
        _recommendations = State(initialValue: recommendations)
        self.input = input
        self.dismissAll = dismissAll
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Splits")
                        .font(.system(size: 28, weight: .bold))
                    Text("Personalised to your answers. Tap a split to subscribe.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ForEach(recommendations.indices, id: \.self) { i in
                    SFRecommendationCard(rec: $recommendations[i]) {
                        selectedRec = recommendations[i]
                        showSubscribe = true
                    }
                    .padding(.horizontal, 20)
                }
                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showSubscribe) {
            if let rec = selectedRec {
                SplitSubscribeSheet(
                    recommendation: rec,
                    daysPerWeek: input.daysPerWeek,
                    dismissAll: dismissAll
                )
            }
        }
    }
}

// MARK: - Recommendation Card

struct SFRecommendationCard: View {
    @Binding var rec: SplitRecommendation
    let onSubscribe: () -> Void

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.name)
                        .font(.system(size: 20, weight: .bold))
                    Text(rec.style.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.tint)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.tintSoft)
                        .clipShape(Capsule())
                }
                Spacer()
            }

            HStack(spacing: 16) {
                Label("\(rec.days.filter { !$0.isRest }.count) days/wk", systemImage: "calendar")
                Label("~\(rec.estimatedMinutes) min", systemImage: "clock")
                if !rec.days.flatMap({ $0.warmupBlock }).isEmpty {
                    Label("Warmup", systemImage: "flame.fill").foregroundStyle(.orange)
                }
            }
            .font(.caption).foregroundStyle(.secondary)

            if !rec.matchTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(rec.matchTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.good)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.good.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(expanded ? "Hide Schedule" : "See Schedule")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.tint)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                scheduleExpanded
            }

            Button(action: onSubscribe) {
                Text("Use This Split")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(Color.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var scheduleExpanded: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rec.days.indices, id: \.self) { di in
                let day = rec.days[di]
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: day.isRest ? "moon.fill" : "dumbbell.fill")
                            .font(.caption)
                            .foregroundStyle(day.isRest ? Color.secondary : Color.tint)
                            .frame(width: 16)
                        Text(day.label)
                            .font(.caption).fontWeight(.semibold)
                        Spacer()
                        if day.isRest {
                            Text("Rest")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if !day.isRest {
                        ForEach(day.exercises.indices, id: \.self) { ei in
                            let ex = day.exercises[ei]
                            let hasAlts = ExerciseAlternatives.pool(for: ex.primaryMuscle).count > 1
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 4, height: 4)
                                Text(ex.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if hasAlts {
                                    Button {
                                        HapticManager.impact(.light)
                                        cycleExercise(dayIndex: di, exIndex: ei)
                                    } label: {
                                        Image(systemName: "arrow.2.circlepath")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.tint)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func cycleExercise(dayIndex: Int, exIndex: Int) {
        let current = rec.days[dayIndex].exercises[exIndex]
        let pool = ExerciseAlternatives.pool(for: current.primaryMuscle)
        guard pool.count > 1 else { return }
        let currentIdx = pool.firstIndex(where: { $0.name == current.name }) ?? -1
        let nextIdx = (currentIdx + 1) % pool.count
        var replacement = pool[nextIdx]
        replacement.sets = current.sets
        replacement.reps = current.reps
        rec.days[dayIndex].exercises[exIndex] = replacement
    }
}
