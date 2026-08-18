import SwiftUI

// MARK: - Focus color

func dayFocusColor(_ focus: DayFocus) -> Color {
    switch focus {
    case .push, .chest:  return Color.bad
    case .pull, .back:   return Color.mBack
    case .legs:          return Color.mQuads
    case .upper, .arms:  return Color.mBiceps
    case .lower:         return Color.mHamstrings
    case .fullBody:      return Color.good
    case .shoulders:     return Color.warn
    case .core:          return Color.mCore
    case .rest:          return Color.secondary
    case .other:         return Color.tint
    }
}

// MARK: - SplitPatternStrip
// The at-a-glance week: one chip per day, colored + labeled by focus
// (PSH PLL LEG — UPR …). Reads left to right as the training week.

struct SplitPatternStrip: View {
    let descriptor: SplitDescriptor
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            ForEach(descriptor.days) { day in
                let color = dayFocusColor(day.focus)
                Text(day.focus.shortLabel)
                    .font(.system(size: compact ? 8 : 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(day.focus == .rest ? Color.secondary : color)
                    .frame(minWidth: compact ? 24 : 30)
                    .padding(.vertical, compact ? 3 : 4)
                    .background((day.focus == .rest ? Color.secondary : color).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}

/// Summary line + pattern strip, the standard "what kind of split is this" block.
struct SplitDescriptorSummary: View {
    let descriptor: SplitDescriptor
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(descriptor.summaryLine)
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                .foregroundStyle(Color.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            SplitPatternStrip(descriptor: descriptor, compact: compact)
            if !compact && !descriptor.topMuscles.isEmpty {
                Text("Focus: \(descriptor.topMuscles.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Community Card (library row)

struct CommunitySplitCard: View {
    let split: CommunitySplitResponse

    private var descriptor: SplitDescriptor {
        SplitDescriptor.describe(communityDays: split.days)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(split.name)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            SplitDescriptorSummary(descriptor: descriptor, compact: true)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: split.author.avatar_color))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Text(split.author.avatarInitial)
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(.white)
                    )
                Text(split.author.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if split.imports_count > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(.caption2, weight: .semibold))
                        Text("\(split.imports_count)")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 190, height: 132, alignment: .topLeading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Community Browse (See All)

struct CommunityBrowseView: View {
    @ObservedObject var communityVM: CommunitySplitsViewModel
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if communityVM.splits.isEmpty && communityVM.loadFailed {
                    errorState
                } else if communityVM.splits.isEmpty && communityVM.hasLoadedOnce {
                    emptyState
                }
                ForEach(communityVM.splits) { split in
                    NavigationLink {
                        CommunitySplitDetailView(split: split, communityVM: communityVM)
                            .environmentObject(vm)
                    } label: {
                        browseRow(split)
                    }
                    .buttonStyle(.plain)
                }
                if communityVM.hasMore {
                    ProgressView()
                        .padding(.vertical, 16)
                        .task { await communityVM.loadMore() }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Community Splits")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await communityVM.load() }
    }

    private var errorState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.secondary)
            Text("Couldn't load community splits").font(.subheadline).fontWeight(.semibold)
            Text("Check your connection and try again.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await communityVM.load() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.tint)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.3")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No community splits yet")
                .font(.subheadline).fontWeight(.semibold)
            Text("Publish one of your splits and it will show up here for everyone.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func browseRow(_ split: CommunitySplitResponse) -> some View {
        let descriptor = SplitDescriptor.describe(communityDays: split.days)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(split.name)
                    .font(.subheadline).fontWeight(.bold)
                    .lineLimit(1)
                Spacer()
                if split.is_mine {
                    Text("Yours")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.tint)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.tint.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            SplitDescriptorSummary(descriptor: descriptor)
            if !split.description.isEmpty {
                Text(split.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 4) {
                Text("by \(split.author.displayName)")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if split.imports_count > 0 {
                    Label("\(split.imports_count) imported", systemImage: "square.and.arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Community Split Detail

struct CommunitySplitDetailView: View {
    let split: CommunitySplitResponse
    @ObservedObject var communityVM: CommunitySplitsViewModel
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var imported = false
    @State private var confirmUnpublish = false

    private var descriptor: SplitDescriptor {
        SplitDescriptor.describe(communityDays: split.days)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    SplitDescriptorSummary(descriptor: descriptor)
                    if !split.description.isEmpty {
                        Text(split.description)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    HStack(spacing: 4) {
                        Text("by \(split.author.displayName)")
                        if split.imports_count > 0 {
                            Text("· imported \(split.imports_count)×")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if !split.is_mine {
                Section {
                    Button {
                        Task {
                            if await communityVM.importSplit(split) {
                                imported = true
                                await vm.syncSplitsFromServer()
                            } else {
                                vm.showError("Couldn't import this split. Please try again.")
                            }
                        }
                    } label: {
                        Label(imported ? "Added to My Splits" : "Add to My Splits",
                              systemImage: imported ? "checkmark.circle.fill" : "square.and.arrow.down")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(imported ? Color.secondary : Color.tint)
                    }
                    .disabled(imported)
                }
            }

            Section("Week") {
                ForEach(split.days.sorted { $0.order_index < $1.order_index }, id: \.order_index) { day in
                    dayRow(day)
                }
            }

            if split.is_mine {
                Section {
                    Button(role: .destructive) { confirmUnpublish = true } label: {
                        Label("Remove from Community", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(split.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove this split from the community?",
                            isPresented: $confirmUnpublish) {
            Button("Remove", role: .destructive) {
                Task {
                    if await communityVM.unpublish(split) { dismiss() }
                    else { vm.showError("Couldn't remove the split. Please try again.") }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("People who already imported it keep their copy.")
        }
    }

    private func dayRow(_ day: CommunitySplitDayResponse) -> some View {
        let exercises = (try? JSONDecoder().decode([DayExercise].self,
                         from: Data(day.exercises_json.utf8))) ?? []
        let focus = SplitDescriptor.classify(DescriptorDayInput(
            isRest: day.is_rest, dayName: day.day_name,
            exercises: exercises.map { ($0.name, $0.sets) }
        ))
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(day.day_label)
                    .font(.caption).foregroundStyle(.secondary)
                Text(focus.displayName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(dayFocusColor(focus))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(dayFocusColor(focus).opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
            }
            if day.is_rest {
                Text("Rest").font(.subheadline).foregroundStyle(.secondary)
            } else {
                if !day.day_name.isEmpty {
                    Text(day.day_name).font(.subheadline).fontWeight(.semibold)
                }
                ForEach(exercises) { ex in
                    HStack {
                        Text(ex.name).font(.caption)
                        Spacer()
                        Text("\(ex.sets) × \(ex.reps)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Publish Sheet

struct PublishSplitSheet: View {
    let split: UserSplitRecord
    let days: [UserSplitDayRecord]
    @ObservedObject var communityVM: CommunitySplitsViewModel
    let onPublished: () -> Void

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var descriptionText = ""
    @State private var isPublishing = false

    private var descriptor: SplitDescriptor {
        SplitDescriptor.describe(dayRecords: days)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(split.name)
                            .font(.headline)
                        SplitDescriptorSummary(descriptor: descriptor)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("This is what people will see")
                }

                Section("Description (optional)") {
                    TextField("Who is this split for? What's the idea behind it?",
                              text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        publish()
                    } label: {
                        HStack {
                            Spacer()
                            if isPublishing { ProgressView() }
                            else {
                                Label("Publish to Community", systemImage: "person.3.fill")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isPublishing || split.serverID.isEmpty)
                } footer: {
                    Text(split.serverID.isEmpty
                         ? "This split is still saving — try again in a moment."
                         : "Anyone on Elos can see and import a published split. Publishing again later updates your listing.")
                }
            }
            .navigationTitle("Publish Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func publish() {
        isPublishing = true
        Task {
            let ok = await communityVM.publish(
                serverID: split.serverID,
                description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            isPublishing = false
            if ok {
                dismiss()
                onPublished()
            } else {
                vm.showError("Couldn't publish this split. Please try again.")
            }
        }
    }
}
