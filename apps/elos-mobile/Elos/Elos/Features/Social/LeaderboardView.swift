import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var socialVM: SocialViewModel
    @State private var showCrew = false
    @State private var reportingEntry: LeaderboardEntryResponse?
    @State private var reportCategory = "other"
    @State private var reportNote = ""
    @State private var showingReportConfirmation = false

    private let metrics = ["volume", "sessions", "streak", "prs"]
    private let metricLabels = ["Volume", "Sessions", "Streak", "PRs"]

    var body: some View {
        VStack(spacing: 0) {
            metricPicker
            if socialVM.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if socialVM.weeklyBoard.isEmpty {
                if socialVM.boardLoadFailed { failedState } else { emptyState }
            } else {
                leaderboardList
            }
        }
        .task { await socialVM.loadBoard() }
        .onChange(of: socialVM.selectedMetric) { _, _ in
            Task { await socialVM.loadBoard() }
        }
        .sheet(item: $reportingEntry) { entry in
            reportSheet(for: entry)
        }
        .alert("Report Submitted", isPresented: $showingReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thank you. Our team will review this report.")
        }
    }

    private func reportSheet(for entry: LeaderboardEntryResponse) -> some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Category", selection: $reportCategory) {
                        Text("Spam").tag("spam")
                        Text("Harassment").tag("harassment")
                        Text("Inappropriate").tag("inappropriate")
                        Text("Other").tag("other")
                    }
                }
                Section("Additional Info (optional)") {
                    TextField("Tell us more…", text: $reportNote, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Report \(entry.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { reportingEntry = nil }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        let cat = reportCategory
                        let note = reportNote.isEmpty ? nil : reportNote
                        let uid = entry.user_id
                        reportingEntry = nil
                        Task {
                            let ok = await socialVM.reportUser(reportedId: uid, category: cat, note: note)
                            if ok { showingReportConfirmation = true }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.tint)
                }
            }
        }
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(zip(metrics, metricLabels)), id: \.0) { metric, label in
                    Button {
                        socialVM.selectedMetric = metric
                    } label: {
                        Text(label)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(socialVM.selectedMetric == metric ? .white : Color.tint)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(socialVM.selectedMetric == metric ? Color.tint : Color.tint.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var leaderboardList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !socialVM.boardWeekStart.isEmpty {
                    Text(weekRangeLabel(from: socialVM.boardWeekStart))
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)
                }
                ForEach(socialVM.weeklyBoard) { entry in
                    LeaderboardRow(entry: entry, metric: socialVM.selectedMetric)
                        .background(entry.is_self ? Color.tint.opacity(0.07) : Color.clear)
                        .contextMenu {
                            if !entry.is_self {
                                Button(role: .destructive) {
                                    reportCategory = "other"
                                    reportNote = ""
                                    reportingEntry = entry
                                } label: {
                                    Label("Report User", systemImage: "flag")
                                }
                            }
                        }
                    Divider().padding(.leading, 56)
                }
            }
            .elosCard()
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No data yet")
                .font(.headline)
            Text("Add friends to see the weekly leaderboard")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var failedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Couldn't load the leaderboard")
                .font(.headline)
            Text("Check your connection and try again.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await socialVM.loadBoard() } }
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.tint)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func weekRangeLabel(from isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: isoDate) else { return "" }
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return "\(display.string(from: start))–\(display.string(from: end))"
    }
}

private struct LeaderboardRow: View {
    @EnvironmentObject private var appVM: AppViewModel
    let entry: LeaderboardEntryResponse
    let metric: String

    var body: some View {
        HStack(spacing: Space.m) {
            PodiumBadge(rank: entry.rank, size: 30)
            AvatarCircle(initials: entry.initials, hex: entry.avatarHex, size: 36)
            Text(entry.displayName)
                .font(.system(.subheadline, weight: entry.is_self ? .semibold : .regular))
                .lineLimit(1)
            // "You" was a caption stacked under the name, giving self rows a taller layout than
            // everyone else's and making the list bounce. Inline chip keeps every row one height.
            if entry.is_self {
                Text("You")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(Color.tint)
                    .padding(.horizontal, Space.xs + 2).padding(.vertical, 2)
                    .background(Color.tintSoft, in: Capsule())
            }
            Spacer(minLength: Space.s)
            Text(formattedValue(entry.value, metric: metric))
                .font(.elosNumeric(.subheadline, weight: .semibold))
                .foregroundStyle(entry.rank == 1 ? Color.tint : .primary)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .background(entry.is_self ? Color.tintSoft.opacity(0.5) : .clear)
        .accessibilityElement(children: .combine)
    }

    private func formattedValue(_ value: Double, metric: String) -> String {
        switch metric {
        case "volume":   return appVM.weightUnit.formatVolume(kg: value)
        case "sessions": return "\(Int(value))"
        case "streak":   return "\(Int(value))d"
        case "prs":      return "\(Int(value)) PRs"
        default:         return "\(Int(value))"
        }
    }
}
