import SwiftUI

struct SplitFinderView: View {
    let dismissAll: () -> Void

    @StateObject private var vm = SplitFinderViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if vm.showResults {
                    SplitFinderResultsView(
                        recommendations: vm.recommendations,
                        input: vm.input,
                        dismissAll: dismissAll
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    surveyContent
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: vm.showResults)
            .navigationTitle("Split Finder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismissAll() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Survey wrapper

    private var surveyContent: some View {
        VStack(spacing: 0) {
            progressBar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stepContent
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                }
                .padding(.bottom, 120)
            }
            navButtons
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 3)
                Rectangle().fill(Color.tint)
                    .frame(width: geo.size.width * CGFloat(vm.currentStep) / CGFloat(vm.totalSteps), height: 3)
                    .animation(.easeInOut(duration: 0.25), value: vm.currentStep)
            }
        }
        .frame(height: 3)
    }

    private var navButtons: some View {
        HStack(spacing: 12) {
            if vm.currentStep > 1 {
                Button(action: { withAnimation { vm.back() } }) {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            Button(action: { withAnimation { vm.next() } }) {
                Text(vm.currentStep == vm.totalSteps ? "Find My Split" : "Next")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(vm.canGoNext ? Color.tint : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!vm.canGoNext)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    // MARK: Step routing

    @ViewBuilder
    private var stepContent: some View {
        switch vm.currentStep {
        case 1: step1_goal
        case 2: step2_days
        case 3: step3_session
        case 4: step4_equipment
        case 5: step5_structure
        case 6: step6_gym
        case 7: step7_sport
        case 8: step8_injuries
        case 9: step9_warmups
        default: EmptyView()
        }
    }

    // MARK: Step 1 — Goal

    private var step1_goal: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("What's your primary goal?", subtitle: "This shapes every part of your split.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TrainingGoal.allCases, id: \.self) { goal in
                    SFGoalCard(goal: goal, isSelected: vm.input.goal == goal) {
                        vm.input.goal = goal
                    }
                }
            }
        }
    }

    // MARK: Step 2 — Days/week

    private var step2_days: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader("How many days a week can you train?",
                       subtitle: "Be realistic — consistency beats ambition.")
            Picker("Days", selection: $vm.input.daysPerWeek) {
                ForEach([2, 3, 4, 5, 6], id: \.self) { d in
                    Text("\(d)").tag(d)
                }
            }
            .pickerStyle(.segmented)
            Text("\(vm.input.daysPerWeek) days/week")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Step 3 — Session length

    private var step3_session: some View {
        let steps = [30, 45, 60, 75, 90]
        let idx = steps.firstIndex(of: vm.input.sessionMinutes) ?? 2
        return VStack(alignment: .leading, spacing: 20) {
            stepHeader("How long is your ideal session?",
                       subtitle: "Including warmup time if enabled.")
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(idx) },
                        set: { vm.input.sessionMinutes = steps[min(Int($0.rounded()), steps.count - 1)] }
                    ),
                    in: 0...Double(steps.count - 1), step: 1
                )
                .tint(Color.tint)
                HStack {
                    ForEach(steps, id: \.self) { m in
                        Text("\(m)m")
                            .font(.caption2)
                            .foregroundStyle(vm.input.sessionMinutes == m ? Color.tint : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Text("~\(vm.input.sessionMinutes) minutes per session")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.tint)
        }
    }

    // MARK: Step 4 — Equipment

    private var step4_equipment: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("What equipment do you prefer?",
                       subtitle: "Rate each 1–5, or let the app decide based on your goal.")
            Toggle("Let the app decide", isOn: $vm.autoSelectEquipment)
                .toggleStyle(SwitchToggleStyle(tint: Color.tint))
            equipmentRatingRow(
                label: "Machine", icon: "gearshape.fill",
                rating: $vm.machineRating, color: .blue
            )
            equipmentRatingRow(
                label: "Dumbbell", icon: "dumbbell.fill",
                rating: $vm.dumbbellRating, color: .purple
            )
            equipmentRatingRow(
                label: "Barbell", icon: "figure.strengthtraining.traditional",
                rating: $vm.barbellRating, color: Color.tint
            )
        }
    }

    private func equipmentRatingRow(
        label: String, icon: String,
        rating: Binding<Int>, color: Color
    ) -> some View {
        let disabled = vm.autoSelectEquipment
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(disabled ? .secondary : color)
                .frame(width: 20)
            Text(label)
                .font(.subheadline).fontWeight(.semibold)
            Spacer()
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { dot in
                    Circle()
                        .fill(dot <= rating.wrappedValue
                              ? (disabled ? Color.secondary.opacity(0.35) : color)
                              : Color.secondary.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .onTapGesture {
                            guard !disabled else { return }
                            HapticManager.impact(.light)
                            rating.wrappedValue = dot
                        }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(disabled ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: disabled)
    }

    // MARK: Step 5 — Program Structure

    private var step5_structure: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("What program structure do you prefer?",
                       subtitle: "Pick a split style, or let the app choose based on your answers.")
            Button {
                vm.preferredStructure = nil
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(vm.preferredStructure == nil ? .white : Color.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Let the app decide")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(vm.preferredStructure == nil ? .white : .primary)
                        Text("Best match based on your goal & schedule")
                            .font(.caption)
                            .foregroundStyle(vm.preferredStructure == nil ? .white.opacity(0.8) : .secondary)
                    }
                    Spacer()
                    if vm.preferredStructure == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }
                .padding(14)
                .background(vm.preferredStructure == nil ? Color.tint : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(SplitStyle.allCases, id: \.self) { style in
                    SFStructureCard(style: style, isSelected: vm.preferredStructure == style) {
                        vm.preferredStructure = style
                    }
                }
            }
        }
    }

    // MARK: Step 6 — Gym size

    private var step6_gym: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("What type of gym do you use?",
                       subtitle: "This helps match equipment availability.")
            HStack(spacing: 12) {
                ForEach(GymSize.allCases, id: \.self) { size in
                    SFSelectionCard(
                        icon: size.icon, label: size.displayName,
                        isSelected: vm.input.gymSize == size
                    ) { vm.input.gymSize = size }
                }
            }
        }
    }

    // MARK: Step 7 — Sport

    private var step7_sport: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("Are you training for a sport?",
                       subtitle: "Helps bias toward functional movements.")
            Toggle("Yes, I train for a sport", isOn: $vm.hasSport)
                .toggleStyle(SwitchToggleStyle(tint: Color.tint))
            if vm.hasSport {
                sportGrid
                Divider()
                focusPicker
            }
        }
    }

    private var sportGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
            ForEach(Sport.allCases, id: \.self) { sport in
                Button {
                    vm.input.sport = sport
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: sport.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(vm.input.sport == sport ? .white : Color.tint)
                        Text(sport.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(vm.input.sport == sport ? .white : .primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(vm.input.sport == sport ? Color.tint : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var focusPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Training focus").font(.subheadline).fontWeight(.semibold)
            Picker("Focus", selection: $vm.sportFocusStep) {
                ForEach(0..<5, id: \.self) { i in
                    Text(["Hobby", "Enthusiast", "Competitive", "Semi-Pro", "Elite"][i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            Text(vm.sportFocusLabel).font(.caption).foregroundStyle(Color.tint)
        }
    }

    // MARK: Step 8 — Injuries

    private var step8_injuries: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("Any injuries we should work around?",
                       subtitle: "We'll substitute or remove exercises that stress injured areas.")
            Toggle("Yes, I have injuries", isOn: $vm.hasInjuries)
                .toggleStyle(SwitchToggleStyle(tint: Color.tint))
            if vm.hasInjuries {
                ForEach(InjuredPart.allCases, id: \.self) { part in
                    injuryRow(part: part)
                }
            }
        }
    }

    private func injuryRow(part: InjuredPart) -> some View {
        let isSelected = vm.selectedInjuries[part] != nil
        return VStack(spacing: 8) {
            Button {
                if isSelected {
                    vm.selectedInjuries.removeValue(forKey: part)
                } else {
                    vm.selectedInjuries[part] = .mild
                }
            } label: {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.tint : .secondary)
                    Text(part.displayName).font(.subheadline)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            if isSelected {
                Picker("Severity", selection: Binding(
                    get: { vm.selectedInjuries[part] ?? .mild },
                    set: { vm.selectedInjuries[part] = $0 }
                )) {
                    ForEach(InjurySeverity.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, 28)
            }
        }
        .padding(12)
        .background(isSelected ? Color.tintSoft : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Step 9 — Warmups

    private var step9_warmups: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("Do you want warmups included?",
                       subtitle: "Time is reserved from your session budget for warm-up exercises.")
            Toggle("Include warmups", isOn: $vm.hasWarmups)
                .toggleStyle(SwitchToggleStyle(tint: Color.tint))
            if vm.hasWarmups {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(WarmupStyle.allCases, id: \.self) { style in
                        SFSelectionCard(
                            icon: style == .dynamic ? "figure.run" : (style == .staticStretch ? "figure.flexibility" : "arrow.triangle.2.circlepath"),
                            label: style.displayName,
                            isSelected: vm.input.warmupStyle == style
                        ) { vm.input.warmupStyle = style }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func stepHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step \(vm.currentStep) of \(vm.totalSteps)")
                .font(.caption).foregroundStyle(.secondary).fontWeight(.semibold)
            Text(title).font(.system(size: 22, weight: .bold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Subviews (prefixed SF to avoid naming conflicts)

struct SFGoalCard: View {
    let goal: TrainingGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: goal.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? .white : Color.tint)
                Text(goal.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(isSelected ? Color.tint : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct SFSelectionCard: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : Color.tint)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(isSelected ? Color.tint : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct SFStructureCard: View {
    let style: SplitStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: style.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? .white : Color.tint)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                }
                Text(style.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.leading)
                Text(style.structureDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.tint : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
