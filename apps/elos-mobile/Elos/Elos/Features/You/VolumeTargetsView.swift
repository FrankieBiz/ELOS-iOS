import SwiftUI
import SwiftData

/// Where the lifter overrides the science-derived volume targets.
///
/// Two levels, deliberately: one preference multiplier that moves everything, and a per-group weekly
/// total for the muscles they care enough to set by hand. Not sixteen fine-muscle fields — that's a
/// worse product, and `TrainingScience` distributes a group total across its children in the science
/// table's own proportions anyway, so setting "Back: 30" is strictly more informed than setting lats,
/// upper back, lower back and rear delts individually.
struct VolumeTargetsView: View {
    @EnvironmentObject var vm: AppViewModel
    @Query private var profiles: [UserProfileRecord]

    private var profile: TrainingProfile {
        TrainingProfile(record: profiles.first, volumeOverrides: vm.volumeOverrides)
    }

    /// The band that would apply with no per-group override — what "Default" means for this lifter.
    private func derivedTarget(for group: MuscleGroup) -> (low: Int, high: Int) {
        var stripped = vm.volumeOverrides
        stripped.groupWeeklyTarget.removeValue(forKey: group.rawValue)
        let p = TrainingProfile(record: profiles.first, volumeOverrides: stripped)
        let low = group.children.reduce(0.0) { $0 + TrainingScience.weeklyBand(for: $1, profile: p).targetLow }
        let high = group.children.reduce(0.0) { $0 + TrainingScience.weeklyBand(for: $1, profile: p).targetHigh }
        return (Int(low.rounded()), Int(high.rounded()))
    }

    private func effectiveTarget(for group: MuscleGroup) -> Int {
        let low = group.children.reduce(0.0) { $0 + TrainingScience.weeklyBand(for: $1, profile: profile).targetLow }
        return Int(low.rounded())
    }

    var body: some View {
        List {
            Section {
                Picker("Volume preference", selection: preferenceBinding) {
                    ForEach(VolumePreference.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                Text(vm.volumeOverrides.preference.blurb)
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Overall")
            } footer: {
                Text("Targets start from the hypertrophy literature for your experience level, then this scales them. Per-session targets are derived from your weekly ones, spread over \(TrainingScience.targetWeeklyFrequency) sessions a week.")
            }

            Section {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    groupRow(group)
                }
            } header: {
                Text("Weekly sets per muscle group")
            } footer: {
                // Without this these numbers look wrong: a lifter thinks "20 back sets a week", not 34.
                // The gap is fractional counting — a row credits lats fully and upper back, rear delts
                // and lower back at half each — so a group total legitimately runs well above the
                // direct-set figures usually quoted. Same convention the coverage bars use.
                Text("Tap a group to set your own weekly total. Your number is split across the muscles in that group in the same proportions the science table uses.\n\nThese count fractional volume: a set credits its main muscle fully and each assisting muscle at half. That's why a multi-muscle group like Back totals higher than the number of rows you actually perform.")
            }

            if vm.volumeOverrides.isCustomized {
                Section {
                    Button(role: .destructive) {
                        HapticManager.impact(.light)
                        vm.volumeOverrides = .none
                    } label: {
                        Text("Reset to science defaults")
                    }
                }
            }
        }
        .navigationTitle("Volume Targets")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Live binding into the override dictionary. Nil = "use the derived target".
    private func overrideBinding(for group: MuscleGroup) -> Binding<Int?> {
        Binding(
            get: { vm.volumeOverrides.groupWeeklyTarget[group.rawValue] },
            set: { newValue in
                if let newValue {
                    vm.volumeOverrides.groupWeeklyTarget[group.rawValue] = newValue
                } else {
                    vm.volumeOverrides.groupWeeklyTarget.removeValue(forKey: group.rawValue)
                }
            }
        )
    }

    private var preferenceBinding: Binding<VolumePreference> {
        Binding(get: { vm.volumeOverrides.preference },
                set: { vm.volumeOverrides.preference = $0 })
    }

    /// Whether *every* child of this group is currently in the global exclusion set. Group-level by
    /// necessity here — this is the picker's "Not training this" sentinel, one control per group, not
    /// a per-fine-muscle checklist (that's what the per-day `SkipMusclesSheet` is for).
    private func excludedBinding(for group: MuscleGroup) -> Binding<Bool> {
        Binding(
            get: { group.children.allSatisfy { vm.volumeOverrides.excludedMuscles.contains($0) } },
            set: { newValue in
                if newValue {
                    vm.volumeOverrides.excludedMuscles.formUnion(group.children)
                } else {
                    vm.volumeOverrides.excludedMuscles.subtract(group.children)
                }
            }
        )
    }

    private func groupRow(_ group: MuscleGroup) -> some View {
        let isExcluded = group.children.allSatisfy { vm.volumeOverrides.excludedMuscles.contains($0) }
        let isCustom = vm.volumeOverrides.groupWeeklyTarget[group.rawValue] != nil
        let derived = derivedTarget(for: group)
        return NavigationLink {
            GroupTargetEditor(group: group,
                              derived: derived,
                              override: overrideBinding(for: group),
                              excluded: excludedBinding(for: group))
        } label: {
            HStack {
                Text(group.displayName)
                Spacer()
                if isExcluded {
                    Text("Not training")
                        .font(.elosNumeric(.subheadline))
                        .foregroundStyle(.secondary)
                } else {
                    Text(isCustom ? "\(effectiveTarget(for: group)) sets" : "\(derived.low)–\(derived.high) sets")
                        .font(.elosNumeric(.subheadline))
                        .foregroundStyle(isCustom ? Color.tint : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}

// MARK: - Per-group editor

/// Pushed, not presented, and bound straight through to the stored override.
///
/// This was a `.sheet` with local `@State` copied in `init` plus Cancel/Save. In that form the Toggle
/// would not respond to taps at all — the toolbar buttons worked, so the sheet was live, but the
/// control inside a `List` inside a `NavigationStack` inside a `.medium`-detent sheet presented from a
/// view that is itself inside the Settings sheet never registered. Pushing onto the navigation stack
/// that's already there removes the nested presentation entirely, and binding directly to the stored
/// value removes the copy-in-init/write-back-on-save dance: edits apply and persist immediately, which
/// is also how the rest of iOS Settings behaves.
private struct GroupTargetEditor: View {
    let group: MuscleGroup
    let derived: (low: Int, high: Int)
    @Binding var override: Int?
    @Binding var excluded: Bool

    private var useCustom: Bool { override != nil }

    /// `0` = "use the derived default", `-1` = "not training this" — two sentinels so one `Picker`
    /// covers all three states. This is the one place that keeps `override`/`excluded` mutually
    /// exclusive: every selection change writes both, so a group is never simultaneously "excluded"
    /// and "has a stale numeric target" (which would otherwise leave `weeklyBand` to decide which one
    /// wins based on function-call order rather than the lifter's actual last choice).
    private var selection: Binding<Int> {
        Binding(
            get: { excluded ? -1 : (override ?? 0) },
            set: { newValue in
                if newValue == -1 {
                    excluded = true
                    override = nil
                } else {
                    excluded = false
                    override = newValue == 0 ? nil : newValue
                }
            }
        )
    }

    /// 4…40 in steps of 2 spans a maintenance dose through a specialisation block for a single
    /// fine-muscle band — but this editor is shown per *group*, and a multi-child group's target is
    /// the sum across its children (e.g. Back = lats + upperBack + lowerBack + rearDelts), which
    /// regularly exceeds 40 outright (Back's own science default already runs 44–68). Anchor the
    /// ceiling to this group's derived high so every group can reach at least its own default, with
    /// headroom above it for an intentional specialisation block.
    private var options: [Int] {
        let ceiling = max(40, derived.high + 20)
        let evenCeiling = ceiling + (ceiling % 2)
        return Array(stride(from: 4, through: evenCeiling, by: 2))
    }

    var body: some View {
        List {
            // An inline Picker rather than a Toggle plus a Slider.
            //
            // The Toggle would not fire at all here: taps on it never invoked its setter (verified —
            // the stored overrides stayed empty while the preference Picker on the parent screen wrote
            // through fine), as both a sheet with local @State and a pushed view with a live binding.
            // A Picker is the control that demonstrably works in this exact context, and folding
            // "default, my own number, or not training this" into a single list is less machinery.
            Section {
                Picker("Weekly sets", selection: selection) {
                    Text("Default (\(derived.low)–\(derived.high))").tag(0)
                    ForEach(options, id: \.self) { n in
                        Text("\(n) sets").tag(n)
                    }
                    Text("Not training this").tag(-1)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Weekly sets for \(group.displayName)")
            } footer: {
                Text(footerText)
            }

            Section {
                Text(group.volumeRationale)
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
                DisclosureGroup("Sources") {
                    ForEach(TrainingScience.citations, id: \.title) { citation in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(citation.authors) (\(citation.year))")
                                .font(.caption).fontWeight(.semibold)
                            Text(citation.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .italic()
                            Text(citation.finding)
                                .font(.caption2)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .font(.elosCaption)
            } header: {
                Text("Why this number")
            }
        }
        .navigationTitle(group.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var footerText: String {
        if excluded {
            return "\(group.displayName) is excluded from your coverage checks and quality score everywhere — every template and every split. To skip it on just one day instead, use that day's own \"Skip muscles\" option."
        }
        return useCustom
            ? "Split across \(group.children.count == 1 ? "this muscle" : "the \(group.children.count) muscles in \(group.displayName)") in science-table proportion. Applies to the coverage bars and the quality score straight away."
            : "Using the science default for your experience level and preference: \(derived.low)–\(derived.high) sets a week."
    }
}
