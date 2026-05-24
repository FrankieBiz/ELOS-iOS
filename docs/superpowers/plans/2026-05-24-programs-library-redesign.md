# Programs Library Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign ProgramsView into a curated split library with horizontal category rows, favorites, and custom split creation from library templates.

**Architecture:** ProgramsView is rewritten as a single scrollable screen with an active split card at top, horizontal category rows for each SplitCategory, and a My Splits section at the bottom. Favorites are stored in UserDefaults and surfaced as a pinned row. WorkoutSplitDetailView gains a "Customize & Subscribe" sheet. CreateSplitView gains optional template pre-fill.

**Tech Stack:** SwiftUI, SwiftData, UserDefaults, iOS 17+

**iOS git note:** All git commands for iOS files use `git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos`

---

## File Map

| File | Action |
|------|--------|
| `Elos/AppViewModel.swift` | Add `favoriteSplitKeys: Set<String>` + `toggleFavorite(_ id: String)` |
| `Elos/Features/Train/Programs/SplitLibraryCard.swift` | **New** — fixed-width horizontal card component |
| `Elos/Features/Train/Programs/ProgramsView.swift` | **Full rewrite** — sectioned layout, remove toolbar `+` |
| `Elos/Features/Train/Programs/WorkoutSplitDetailView.swift` | Add `showCustomize` state + "Customize & Subscribe" sheet |
| `Elos/Features/Train/Programs/CreateSplitView.swift` | Add optional `template: WorkoutSplit?` param with pre-fill |

> All paths relative to `/Users/frankbisignano/dev/elos/apps/elos-mobile/Elos/Elos/`

> **Note on WorkoutSplitData.swift:** The spec mentioned expanding the split library, but `WorkoutSplitData.swift` (1,274 lines) already contains 40+ well-populated splits across all 6 categories (12+ Creator-Inspired, 10+ Olympia/Bodybuilding, 20+ Sport Performance, 10+ Foundation, 4 Home/Minimal, 5+ Specialization). No expansion needed — the splits were always there, just not surfaced effectively in the old UI.

---

## Task 1: Add Favorites to AppViewModel

**Files:**
- Modify: `Elos/AppViewModel.swift`

- [ ] **Step 1: Add `favoriteSplitKeys` published property**

Open `Elos/AppViewModel.swift`. After line 78 (`@Published var canvasSyncing = false`), add:

```swift
@Published var favoriteSplitKeys: Set<String> = []
```

- [ ] **Step 2: Load favorites in `init`**

In `init(context: ModelContext)` at line 82, after `self.context = context`, add:

```swift
let stored = UserDefaults.standard.stringArray(forKey: "elos.favoriteSplitKeys") ?? []
favoriteSplitKeys = Set(stored)
```

- [ ] **Step 3: Add `toggleFavorite` method**

Add this method anywhere in AppViewModel (e.g., after `clearData()`):

```swift
func toggleFavorite(_ id: String) {
    if favoriteSplitKeys.contains(id) {
        favoriteSplitKeys.remove(id)
    } else {
        favoriteSplitKeys.insert(id)
    }
    UserDefaults.standard.set(Array(favoriteSplitKeys), forKey: "elos.favoriteSplitKeys")
}
```

- [ ] **Step 4: Verify — open AppViewModel.swift and confirm `favoriteSplitKeys` and `toggleFavorite` are present with no syntax errors**

- [ ] **Step 5: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/AppViewModel.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add favoriteSplitKeys and toggleFavorite to AppViewModel"
```

---

## Task 2: Create SplitLibraryCard Component

**Files:**
- Create: `Elos/Features/Train/Programs/SplitLibraryCard.swift`

- [ ] **Step 1: Create the file**

Create `/Users/frankbisignano/dev/elos/apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitLibraryCard.swift` with:

```swift
import SwiftUI

struct SplitLibraryCard: View {
    let split: WorkoutSplit
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(split.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 24)

                HStack(spacing: 6) {
                    Text(split.category.rawValue)
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(categoryColor.opacity(0.12))
                        .clipShape(Capsule())
                    Text("\(split.daysPerWeek)d")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }

                if !split.goals.isEmpty {
                    Text(split.goals.prefix(3).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(width: 160, minHeight: 100, alignment: .topLeading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                HapticManager.impact(.light)
                onFavoriteTap()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 13))
                    .foregroundStyle(isFavorite ? Color.red : Color.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var categoryColor: Color {
        switch split.category {
        case .foundation:          return .tint
        case .creatorInspired:     return .orange
        case .olympiaBodybuilding: return .purple
        case .sportPerformance:    return .green
        case .homeMinimal:         return .brown
        case .specialization:      return .pink
        }
    }
}
```

- [ ] **Step 2: Verify — read the file back, confirm it compiles (no references to missing types; `HapticManager` and `Color.tint` are defined elsewhere in the project)**

- [ ] **Step 3: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Features/Train/Programs/SplitLibraryCard.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add SplitLibraryCard component"
```

---

## Task 3: Rewrite ProgramsView

**Files:**
- Modify: `Elos/Features/Train/Programs/ProgramsView.swift`

The current file is a flat filtered list. Replace the entire `ProgramsView` struct (lines 1–430) with the new implementation below. Keep `UserSplitDetailView` at the bottom of the file unchanged (lines 432–529).

- [ ] **Step 1: Replace ProgramsView**

The new `ProgramsView` struct replaces everything from line 1 to the closing `}` before `// MARK: - User Split Detail`. The `UserSplitDetailView` struct at the bottom stays untouched.

Replace the file content from the top through line ~430 (end of `ProgramsView`) with:

```swift
import SwiftUI
import SwiftData

struct ProgramsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSplitRecord.createdAt, order: .reverse) private var userSplits: [UserSplitRecord]
    @Query private var allSplitDays: [UserSplitDayRecord]
    @EnvironmentObject var vm: AppViewModel

    @State private var showCreateSplit = false
    @State private var showSplitFinder = false
    @State private var selectedSplit: UserSplitRecord?

    private let categoryOrder: [SplitCategory] = [
        .creatorInspired, .olympiaBodybuilding, .sportPerformance,
        .foundation, .homeMinimal, .specialization
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    activeSplitCard
                    if !vm.favoriteSplitKeys.isEmpty {
                        libraryCategoryRow(
                            title: "Favorites",
                            icon: "heart.fill",
                            color: .red,
                            splits: WorkoutSplitLibrary.all.filter { vm.favoriteSplitKeys.contains($0.id) }
                        )
                        Divider().padding(.horizontal, 16)
                    }
                    ForEach(categoryOrder, id: \.self) { category in
                        let splits = WorkoutSplitLibrary.all.filter { $0.category == category }
                        if !splits.isEmpty {
                            libraryCategoryRow(
                                title: category.rawValue,
                                icon: categoryIcon(category),
                                color: categoryColor(category),
                                splits: splits
                            )
                            Divider().padding(.horizontal, 16)
                        }
                    }
                    mySplitsSection
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSplitFinder = true } label: {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(Color.tint)
                    }
                }
            }
            .sheet(isPresented: $showCreateSplit) {
                CreateSplitView { showCreateSplit = false }
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showSplitFinder) {
                SplitFinderView(dismissAll: { showSplitFinder = false })
                    .environmentObject(vm)
            }
            .navigationDestination(item: $selectedSplit) { split in
                UserSplitDetailView(split: split, splitDays: daysFor(split: split))
                    .environmentObject(vm)
            }
        }
    }

    // MARK: Active Split Card

    @ViewBuilder
    private var activeSplitCard: some View {
        if let split = vm.activeSplit {
            let cal = Calendar.current
            let weeksIn = max(1, (cal.dateComponents([.weekOfYear],
                from: split.activatedAt ?? Date(), to: Date()).weekOfYear ?? 0) + 1)
            let dayIdx = vm.currentSplitDayIndex + 1
            let dayCount = vm.activeSplitDays.count
            let progress = dayCount > 0 ? Double(dayIdx) / Double(dayCount) : 0.0

            Button { selectedSplit = split } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(split.name)
                                .font(.subheadline).fontWeight(.bold)
                            Text("Week \(weeksIn) · Day \(dayIdx) of \(dayCount)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.15)).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.tint)
                                .frame(width: geo.size.width * CGFloat(progress), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(14)
                .background(Color.tintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.tint.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
    }

    // MARK: Library Category Row

    private func libraryCategoryRow(title: String, icon: String, color: Color, splits: [WorkoutSplit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                Text("\(splits.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(splits) { split in
                        NavigationLink(
                            destination: WorkoutSplitDetailView(split: split).environmentObject(vm)
                        ) {
                            SplitLibraryCard(
                                split: split,
                                isFavorite: vm.favoriteSplitKeys.contains(split.id),
                                onFavoriteTap: { vm.toggleFavorite(split.id) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: My Splits

    private var mySplitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("My Splits")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Button { showCreateSplit = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.caption2.weight(.bold))
                        Text("Create").font(.caption).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.tint)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            if userSplits.isEmpty {
                Text("No custom splits yet. Tap Create or subscribe to a library split above.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(userSplits) { split in
                        Button {
                            if split.isActive { selectedSplit = split }
                            else { vm.setActiveSplit(split) }
                        } label: {
                            mySplitRow(split)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { selectedSplit = split } label: {
                                Label("View Details", systemImage: "list.bullet")
                            }
                            if !split.isActive {
                                Button { vm.setActiveSplit(split) } label: {
                                    Label("Set as Active", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
    }

    private func mySplitRow(_ split: UserSplitRecord) -> some View {
        let days = daysFor(split: split)
        let isActive = split.isActive
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(split.name)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                HStack(spacing: 4) {
                    ForEach(days.prefix(7), id: \.id) { day in
                        Text(day.isRest ? "—" : String(day.dayLabel.prefix(1)))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(day.isRest ? Color.secondary : Color.tint)
                            .frame(width: 16, height: 16)
                            .background((day.isRest ? Color.secondary : Color.tint).opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.tint)
            } else {
                Text("Set Active")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(Color.tint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.tint.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(isActive ? Color.tint.opacity(0.08) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 12).stroke(Color.tint.opacity(0.4), lineWidth: 1)
            }
        }
    }

    // MARK: Helpers

    private func daysFor(split: UserSplitRecord) -> [UserSplitDayRecord] {
        allSplitDays.filter { $0.splitID == split.id }.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func categoryIcon(_ cat: SplitCategory) -> String {
        switch cat {
        case .foundation:          return "building.columns"
        case .creatorInspired:     return "play.rectangle.fill"
        case .olympiaBodybuilding: return "trophy.fill"
        case .sportPerformance:    return "figure.run"
        case .homeMinimal:         return "house.fill"
        case .specialization:      return "star.fill"
        }
    }

    private func categoryColor(_ cat: SplitCategory) -> Color {
        switch cat {
        case .foundation:          return .tint
        case .creatorInspired:     return .orange
        case .olympiaBodybuilding: return .purple
        case .sportPerformance:    return .green
        case .homeMinimal:         return .brown
        case .specialization:      return .pink
        }
    }
}
```

- [ ] **Step 2: Verify the edit — open ProgramsView.swift and confirm `UserSplitDetailView` is still present after the new `ProgramsView` struct**

- [ ] **Step 3: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Features/Train/Programs/ProgramsView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: rewrite ProgramsView as curated library with category rows"
```

---

## Task 4: Add "Customize & Subscribe" to WorkoutSplitDetailView

**Files:**
- Modify: `Elos/Features/Train/Programs/WorkoutSplitDetailView.swift`

- [ ] **Step 1: Add `showCustomize` state**

In `WorkoutSplitDetailView`, after the existing `@State private var copiedMessage: String? = nil` (line ~14), add:

```swift
@State private var showCustomize = false
```

- [ ] **Step 2: Attach the `.sheet` for customize**

In the `body` computed property, after `.animation(.spring(duration: 0.3), value: copiedMessage)` (the last modifier on the body's ScrollView), add:

```swift
.sheet(isPresented: $showCustomize) {
    CreateSplitView(template: split) { showCustomize = false }
        .environmentObject(vm)
}
```

- [ ] **Step 3: Add "Customize & Subscribe" button in `copyButtonsSection`**

In `copyButtonsSection`, after the Subscribe/Already Added block (after line ~326), before `copyButton(title: "Copy Full Split"...)`, add:

```swift
Button { showCustomize = true } label: {
    Label("Customize & Subscribe", systemImage: "slider.horizontal.3")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.tint(Color.tint)
```

The section should now read:
```swift
private var copyButtonsSection: some View {
    VStack(spacing: 10) {
        // Subscribe CTA
        if isSubscribed {
            Button {} label: {
                Label("Already Added", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)
        } else {
            Button { subscribeSplit() } label: {
                Label("Subscribe", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.tint)
        }

        // Always visible
        Button { showCustomize = true } label: {
            Label("Customize & Subscribe", systemImage: "slider.horizontal.3")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color.tint)

        copyButton(title: "Copy Full Split", icon: "doc.on.doc") {
            copyToClipboard(split.copyText, label: "Split copied")
        }
        // ... rest unchanged
    }
```

- [ ] **Step 4: Verify — read WorkoutSplitDetailView.swift and confirm `showCustomize`, the `.sheet`, and the new button are all present**

- [ ] **Step 5: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Features/Train/Programs/WorkoutSplitDetailView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add Customize & Subscribe button to WorkoutSplitDetailView"
```

---

## Task 5: Add Template Support to CreateSplitView

**Files:**
- Modify: `Elos/Features/Train/Programs/CreateSplitView.swift`

- [ ] **Step 1: Add `template` property and update init**

In `CreateSplitView`, replace the current `let onSave: () -> Void` property declaration with:

```swift
let onSave: () -> Void
let template: WorkoutSplit?

init(template: WorkoutSplit? = nil, onSave: @escaping () -> Void) {
    self.template = template
    self.onSave = onSave
}
```

- [ ] **Step 2: Update navigation title to reflect template mode**

In the body's `.navigationTitle("New Split")`, replace with:

```swift
.navigationTitle(template != nil ? "Customize Split" : "New Split")
```

- [ ] **Step 3: Add `.onAppear` pre-fill**

`CreateSplitView` has two `.sheet` modifiers chained directly after the `Form` (for template picker and exercise picker). The `.onAppear` must go **on the `Form` itself**, before those `.sheet` modifiers. Insert it between `.navigationBarTitleDisplayMode(.inline)` and the first `.sheet(item: ...)`:

```swift
.onAppear {
    guard let t = template else { return }
    splitName = t.title
    for (i, day) in t.workouts.prefix(7).enumerated() {
        dayNames[i] = day.focus
        dayIsRest[i] = false
        dayExercises[i] = day.exercises.map { DayExercise(id: UUID().uuidString, name: $0.name) }
    }
}
```

The modifier order on `Form` must be: `.navigationTitle(...)` → `.navigationBarTitleDisplayMode(.inline)` → `.onAppear { ... }` → `.sheet(item: Binding(...))` (template picker) → `.sheet(item: Binding(...))` (exercise picker).

- [ ] **Step 4: Verify — read CreateSplitView.swift and confirm `template`, `init`, updated nav title, and `.onAppear` are all present with no syntax errors**

Note: The `onAppear` pre-fill only runs once when the view appears. If `template` is nil (start from scratch), it's a no-op.

- [ ] **Step 5: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Features/Train/Programs/CreateSplitView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add optional template pre-fill to CreateSplitView"
```

---

## Verification Checklist

After all tasks complete, confirm these behaviors work in the iOS Simulator:

- [ ] ProgramsView shows horizontal category rows (Creator-Inspired, Olympia/Bodybuilding, Sport Performance, Foundation, Home/Minimal, Specialization)
- [ ] Tapping a card navigates to WorkoutSplitDetailView
- [ ] Tapping the heart on a card adds it to the Favorites row; tapping again removes it
- [ ] Favorites row is hidden when empty, appears at top when at least one split is favorited
- [ ] Favorites persist after app restart (UserDefaults)
- [ ] Active split card shows at top when a split is subscribed
- [ ] My Splits section at bottom shows user splits; "Create" button opens CreateSplitView
- [ ] "Customize & Subscribe" button appears on WorkoutSplitDetailView and opens CreateSplitView with days/exercises pre-filled
- [ ] Customized split name defaults to the library split title
- [ ] No toolbar `+` button (only wand.and.stars remains)
