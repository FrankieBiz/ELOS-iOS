# Subscribe to Split + Account Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Subscribe button to library split detail, sync user splits to the backend, and show a weekly muscle target panel in the Programs tab.

**Architecture:** SwiftData records get three new fields with defaulted inits (auto-migrated). A new Express router (`/splits`) backed by a service and two new pg tables handles persistence. AppViewModel gains four sync methods called at login. WorkoutSplitDetailView gets a Subscribe CTA that creates local records then pushes to the server in the background.

**Tech Stack:** Swift/SwiftUI/SwiftData (iOS), Node.js/TypeScript/Express/node-postgres (backend), Zod validation, elos-shared types package.

**Spec:** `docs/superpowers/specs/2026-05-16-subscribe-split-persistence-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `apps/elos-mobile/Elos/Elos/SwiftData/ElosSchema.swift` | Modify | Add `libraryKey`, `serverID`, `syncPending` to `UserSplitRecord` |
| `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitHelpers.swift` | Create | Shared `DayExercise` struct used by CreateSplitView, ProgramsView, AppViewModel |
| `apps/elos-mobile/Elos/Elos/Features/Train/Programs/CreateSplitView.swift` | Modify | Remove private `DayExercise` (moved to SplitHelpers) |
| `apps/elos-mobile/Elos/Elos/Networking/SplitModels.swift` | Create | `UserSplitResponse`, `UserSplitDayResponse`, `SplitConflictResponse` Decodable structs |
| `apps/elos-mobile/Elos/Elos/Networking/ApiClient.swift` | Modify | Add `deleteNoContent(path:)` method |
| `apps/elos-mobile/Elos/Elos/ViewModels/AppViewModel.swift` | Modify | Add 4 sync methods; call `syncSplitsFromServer` in `loadForUser`; replace `ExInfo` with `DayExercise` |
| `apps/elos-mobile/Elos/Elos/Features/Train/Programs/WorkoutSplitDetailView.swift` | Modify | Add `@EnvironmentObject var vm: AppViewModel`; Subscribe CTA |
| `apps/elos-mobile/Elos/Elos/Features/Train/Programs/ProgramsView.swift` | Modify | Chain `.environmentObject(vm)` on library split NavigationLink; add Weekly Targets panel |
| `apps/elos-api/migrations/023_user_splits.sql` | Create | `user_splits` + `user_split_days` tables + partial unique index |
| `apps/elos-api/src/schemas.ts` | Modify | Add `createSplitSchema` |
| `apps/elos-api/src/services/splitService.ts` | Create | `createSplit`, `getUserSplits`, `deleteSplit`, `activateSplit` |
| `apps/elos-api/src/routes/splits.ts` | Create | POST / GET / DELETE / PATCH activate routes |
| `apps/elos-api/src/index.ts` | Modify | Register `/splits` router |
| `packages/elos-shared/src/index.ts` | Modify | Add `UserSplit`, `UserSplitDay` interfaces |

---

## Task 1: Data Model — Add Fields to `UserSplitRecord`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/SwiftData/ElosSchema.swift` (around line 440)

- [ ] **Step 1: Open ElosSchema.swift and find `UserSplitRecord`**

  The class starts around line 440. It looks like:
  ```swift
  @Model
  final class UserSplitRecord {
      var id: String
      var ownerID: String
      var name: String
      var createdAt: Date
      var isActive: Bool
      var activatedAt: Date?
      var skippedDatesJSON: String
      init(id: String = UUID().uuidString, ownerID: String,
           name: String, createdAt: Date = Date(),
           isActive: Bool = false, activatedAt: Date? = nil,
           skippedDatesJSON: String = "[]") { ... }
  }
  ```

- [ ] **Step 2: Add three new stored properties after `skippedDatesJSON`**

  Add these three lines after `var skippedDatesJSON: String`:
  ```swift
  var libraryKey: String = ""
  var serverID: String = ""
  var syncPending: Bool = false
  ```

- [ ] **Step 3: Update the `init` to accept the three new parameters (all defaulted)**

  Replace the existing `init` signature with:
  ```swift
  init(id: String = UUID().uuidString,
       ownerID: String,
       name: String,
       isActive: Bool = false,
       createdAt: Date = Date(),
       activatedAt: Date? = nil,
       skippedDatesJSON: String = "[]",
       libraryKey: String = "",
       serverID: String = "",
       syncPending: Bool = false)
  ```

  In the init body, add:
  ```swift
  self.libraryKey = libraryKey
  self.serverID = serverID
  self.syncPending = syncPending
  ```

  All existing callers use keyword arguments with only `ownerID` and `name` — all other params are defaulted, so no existing call site breaks.

- [ ] **Step 4: Verify the build compiles**

  ```bash
  cd /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos
  xcodebuild -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

---

## Task 2: Shared `DayExercise` Struct

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitHelpers.swift`
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/CreateSplitView.swift` (line 4)

- [ ] **Step 1: Create `SplitHelpers.swift`**

  ```swift
  import Foundation

  struct DayExercise: Codable, Identifiable {
      let id: String
      let name: String
  }
  ```

- [ ] **Step 2: Remove the private copy from `CreateSplitView.swift`**

  Lines 4–7 in CreateSplitView.swift contain:
  ```swift
  private struct DayExercise: Codable, Identifiable {
      let id: String
      let name: String
  }
  ```
  Delete those 4 lines. The type is now provided by `SplitHelpers.swift`.

- [ ] **Step 3: Replace `ExInfo` in `AppViewModel.swift` with `DayExercise`**

  Line 408 in AppViewModel.swift has:
  ```swift
  struct ExInfo: Codable { let id: String; let name: String }
  ```
  Delete that line. Then find every usage of `ExInfo` in `prepareExercises(for:)` and replace with `DayExercise`.
  The decode call likely looks like:
  ```swift
  let exercises = (try? JSONDecoder().decode([ExInfo].self, ...))
  ```
  Change to:
  ```swift
  let exercises = (try? JSONDecoder().decode([DayExercise].self, ...))
  ```

- [ ] **Step 4: Verify build**

  ```bash
  xcodebuild -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

---

## Task 3: iOS Networking Models

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Networking/SplitModels.swift`
- Modify: `apps/elos-mobile/Elos/Elos/Networking/ApiClient.swift`

- [ ] **Step 1: Create `SplitModels.swift`**

  ```swift
  import Foundation

  struct UserSplitResponse: Decodable {
      let id: String
      let name: String
      let library_key: String
      let is_active: Bool
      let created_at: String
      let days: [UserSplitDayResponse]
  }

  struct UserSplitDayResponse: Decodable {
      let id: String
      let split_id: String
      let order_index: Int
      let day_label: String
      let day_name: String
      let template_id: String
      let is_rest: Bool
      let exercises_json: String
  }

  struct SplitConflictResponse: Decodable {
      let conflict: Bool
      let existing_id: String
  }
  ```

- [ ] **Step 2: Add `deleteNoContent` to `ApiClient.swift`**

  Open `ApiClient.swift`. After the `delete<R: Decodable>` method (around line 60), add:
  ```swift
  func deleteNoContent(path: String) async throws {
      let request = try await makeRequest(method: "DELETE", path: path)
      let (_, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 204 else {
          throw ApiError.httpError(
              (response as? HTTPURLResponse)?.statusCode ?? 0,
              "Expected 204 No Content"
          )
      }
  }
  ```
  `makeRequest` already injects the Supabase auth token — never construct a raw `URLRequest` with a `token` variable here.

- [ ] **Step 3: Verify build**

  ```bash
  xcodebuild -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

---

## Task 4: AppViewModel — Sync Methods

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/ViewModels/AppViewModel.swift`

- [ ] **Step 1: Add a `CreateSplitRequest` encodable for the POST body**

  Near where other request structs are defined in AppViewModel (or at the top of the file), add:
  ```swift
  private struct CreateSplitDayRequest: Encodable {
      let order_index: Int
      let day_label: String
      let day_name: String
      let template_id: String
      let is_rest: Bool
      let exercises_json: String
  }

  private struct CreateSplitRequest: Encodable {
      let name: String
      let library_key: String
      let days: [CreateSplitDayRequest]
  }

  private struct ActivateSplitRequest: Encodable {}
  ```

- [ ] **Step 2: Add `pushSplitToServer`**

  `AppViewModel` uses `ApiClient.shared` (singleton), not a stored `apiClient` property. `modelContext` is non-optional — use it directly without `guard let`.

  Add inside `AppViewModel`:
  ```swift
  func pushSplitToServer(_ record: UserSplitRecord) async {
      let context = modelContext   // non-optional; no guard let needed
      let days = (try? context.fetch(
          FetchDescriptor<UserSplitDayRecord>(
              predicate: #Predicate { $0.splitID == record.id },
              sortBy: [SortDescriptor(\.orderIndex)]
          )
      )) ?? []

      let body = CreateSplitRequest(
          name: record.name,
          library_key: record.libraryKey,
          days: days.map {
              CreateSplitDayRequest(
                  order_index: $0.orderIndex,
                  day_label: $0.dayLabel,
                  day_name: $0.dayName,
                  template_id: $0.templateID,
                  is_rest: $0.isRest,
                  exercises_json: $0.exercisesJSON
              )
          }
      )

      do {
          // ApiClient uses positional unlabeled args + return type annotation (no `as:` label)
          let response: UserSplitResponse = try await ApiClient.shared.post("/splits", body: body)
          await MainActor.run {
              record.serverID = response.id
              record.syncPending = false
              try? context.save()
          }
      } catch ApiError.httpError(409, _) {
          // Server already has this split (duplicate library_key). Fetch the existing record
          // to get its server ID so activate calls work correctly.
          if let existing: [UserSplitResponse] = try? await ApiClient.shared.get("/splits") {
              if let match = existing.first(where: { $0.library_key == record.libraryKey }) {
                  await MainActor.run {
                      record.serverID = match.id
                      record.syncPending = false
                      try? context.save()
                  }
              }
          }
      } catch {
          // Network failure — leave syncPending = true for retry on next launch
      }
  }
  ```

- [ ] **Step 3: Add `deleteSplitOnServer`**

  ```swift
  func deleteSplitOnServer(serverID: String) async {
      guard !serverID.isEmpty else { return }
      try? await ApiClient.shared.deleteNoContent(path: "/splits/\(serverID)")
  }
  ```

- [ ] **Step 4: Add `activateSplitOnServer`**

  ```swift
  func activateSplitOnServer(serverID: String) async {
      guard !serverID.isEmpty else { return }
      let _: UserSplitResponse? = try? await ApiClient.shared.patch("/splits/\(serverID)/activate", body: ActivateSplitRequest())
  }
  ```

- [ ] **Step 5: Add `syncSplitsFromServer`**

  ```swift
  func syncSplitsFromServer() async {
      guard !currentUserID.isEmpty else { return }
      let context = modelContext   // non-optional

      do {
          let remoteSplits: [UserSplitResponse] = try await ApiClient.shared.get("/splits")
          let localSplits = (try? context.fetch(FetchDescriptor<UserSplitRecord>())) ?? []
          let localDays = (try? context.fetch(FetchDescriptor<UserSplitDayRecord>())) ?? []

          for remote in remoteSplits {
              // Match by serverID first, then by libraryKey
              let match = localSplits.first { $0.serverID == remote.id }
                       ?? localSplits.first { !$0.libraryKey.isEmpty && $0.libraryKey == remote.library_key }

              if let existing = match {
                  await MainActor.run {
                      existing.name = remote.name
                      existing.isActive = remote.is_active
                      existing.serverID = remote.id
                      existing.syncPending = false
                  }
                  // Only replace days where content changed
                  let existingDays = localDays.filter { $0.splitID == existing.id }
                  for remotDay in remote.days {
                      if let localDay = existingDays.first(where: { $0.orderIndex == remotDay.order_index }) {
                          if localDay.exercisesJSON != remotDay.exercises_json {
                              await MainActor.run {
                                  localDay.dayName = remotDay.day_name
                                  localDay.dayLabel = remotDay.day_label
                                  localDay.isRest = remotDay.is_rest
                                  localDay.templateID = remotDay.template_id
                                  localDay.exercisesJSON = remotDay.exercises_json
                              }
                          }
                      } else {
                          let newDay = UserSplitDayRecord(
                              splitID: existing.id,
                              orderIndex: remotDay.order_index,
                              dayLabel: remotDay.day_label,
                              dayName: remotDay.day_name,
                              templateID: remotDay.template_id,
                              isRest: remotDay.is_rest,
                              exercisesJSON: remotDay.exercises_json
                          )
                          await MainActor.run { context.insert(newDay) }
                      }
                  }
              } else {
                  // New split from server — create locally
                  let newSplit = UserSplitRecord(
                      ownerID: currentUserID,
                      name: remote.name,
                      isActive: remote.is_active,
                      libraryKey: remote.library_key,
                      serverID: remote.id,
                      syncPending: false
                  )
                  await MainActor.run { context.insert(newSplit) }
                  for remotDay in remote.days {
                      let newDay = UserSplitDayRecord(
                          splitID: newSplit.id,
                          orderIndex: remotDay.order_index,
                          dayLabel: remotDay.day_label,
                          dayName: remotDay.day_name,
                          templateID: remotDay.template_id,
                          isRest: remotDay.is_rest,
                          exercisesJSON: remotDay.exercises_json
                      )
                      await MainActor.run { context.insert(newDay) }
                  }
              }
          }

          await MainActor.run {
              try? context.save()
              loadActiveSplit()
          }

          // Push any locally-created splits not yet on the server
          let pending = (try? context.fetch(FetchDescriptor<UserSplitRecord>())) ?? []
          for record in pending where record.syncPending && record.serverID.isEmpty {
              await pushSplitToServer(record)
          }

      } catch {
          // Sync failed (offline) — silently no-op; local state is authoritative
      }
  }
  ```

- [ ] **Step 6: Call `syncSplitsFromServer` in `loadForUser`**

  Find `loadForUser(id:)` at line 117. It currently ends with something like:
  ```swift
  loadActiveSplit()
  Task { await syncCanvasIfConfigured() }
  ```
  Add after those lines:
  ```swift
  Task { await syncSplitsFromServer() }
  ```

- [ ] **Step 7: Verify build**

  ```bash
  xcodebuild -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

---

## Task 5: Subscribe Flow — `WorkoutSplitDetailView`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/WorkoutSplitDetailView.swift`
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/ProgramsView.swift` (line 265)

- [ ] **Step 1: Inject AppViewModel into WorkoutSplitDetailView**

  At the top of `WorkoutSplitDetailView` struct body (right after `struct WorkoutSplitDetailView: View {`), add:
  ```swift
  @EnvironmentObject var vm: AppViewModel
  @Environment(\.modelContext) private var modelContext
  @Query private var userSplits: [UserSplitRecord]
  ```

- [ ] **Step 2: Add a computed `isSubscribed` property**

  ```swift
  private var isSubscribed: Bool {
      userSplits.contains { $0.libraryKey == split.id }
  }
  ```

- [ ] **Step 3: Replace the "Copy Full Split" button with Subscribe / Already Added**

  Find the "Copy Full Split" button in the view. Replace it with:
  ```swift
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
  }
  ```

- [ ] **Step 4: Add the `subscribeSplit()` method**

  Add inside `WorkoutSplitDetailView`:
  ```swift
  private func subscribeSplit() {
      // Check for existing (different library key match shouldn't happen, but guard anyway)
      if let existing = userSplits.first(where: { $0.libraryKey == split.id }) {
          // Already exists — set active
          vm.setActiveSplit(existing)
          Task { await vm.activateSplitOnServer(serverID: existing.serverID) }
          return
      }

      // Deactivate all current splits
      for s in userSplits { s.isActive = false }

      // Create the new split record
      let record = UserSplitRecord(
          ownerID: vm.currentUserID,
          name: split.title,
          isActive: true,
          libraryKey: split.id,
          syncPending: true
      )
      modelContext.insert(record)

      // Create day records from library workouts
      let encoder = JSONEncoder()
      for (i, day) in split.workouts.enumerated() {
          let exercises = day.exercises.map { DayExercise(id: UUID().uuidString, name: $0.name) }
          let jsonData = (try? encoder.encode(exercises)) ?? Data()
          let jsonStr = String(data: jsonData, encoding: .utf8) ?? "[]"
          let dayRecord = UserSplitDayRecord(
              splitID: record.id,
              orderIndex: i,
              dayLabel: "Day \(i + 1)",
              dayName: day.focus,
              isRest: false,
              exercisesJSON: jsonStr
          )
          modelContext.insert(dayRecord)
      }

      try? modelContext.save()

      // Background sync
      Task {
          await vm.pushSplitToServer(record)
          await vm.activateSplitOnServer(serverID: record.serverID)
      }
  }
  ```

  > Note: `split.title`, `split.workouts`, `split.id`, `day.focus`, `day.exercises`, and `exercise.name` are the actual field names from the library data model (`WorkoutSplit`, `SplitWorkoutDay`, `SplitExercise`). Verify these against `WorkoutSplitData.swift` before implementation — adjust if any name differs.

- [ ] **Step 5: Fix the NavigationLink in ProgramsView**

  Open `ProgramsView.swift` and find line 265:
  ```swift
  NavigationLink(destination: WorkoutSplitDetailView(split: split))
  ```
  Change to:
  ```swift
  NavigationLink(destination: WorkoutSplitDetailView(split: split).environmentObject(vm))
  ```
  (`vm` is the `AppViewModel` `@EnvironmentObject` already available in `ProgramsView`)

- [ ] **Step 6: Verify build**

  ```bash
  xcodebuild -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

---

## Task 6: Programs Tab — Weekly Targets Panel

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/ProgramsView.swift`

- [ ] **Step 1: Locate where the active split section is displayed**

  `ProgramsView.swift` renders `UserSplitDetailView` around line 374. Find the section that shows the active split — it's likely guarded by `activeSplit != nil`.

- [ ] **Step 2: Add a weekly targets helper computed property**

  Inside `ProgramsView` (or `UserSplitDetailView` if the active split display lives there), add:
  ```swift
  private func weeklyTargetArrays(from days: [UserSplitDayRecord]) -> (
      templateIDs: [String], isRest: [Bool], exerciseNames: [[String]]
  ) {
      var templateIDs = Array(repeating: "", count: 7)
      var isRest = Array(repeating: false, count: 7)
      var exerciseNames = Array(repeating: [String](), count: 7)
      for day in days.sorted(by: { $0.orderIndex < $1.orderIndex }) where day.orderIndex < 7 {
          templateIDs[day.orderIndex] = day.templateID
          isRest[day.orderIndex] = day.isRest
          let exs = (try? JSONDecoder().decode([DayExercise].self,
                     from: Data(day.exercisesJSON.utf8))) ?? []
          exerciseNames[day.orderIndex] = exs.map { $0.name }
      }
      return (templateIDs, isRest, exerciseNames)
  }
  ```

- [ ] **Step 3: Add the `MuscleGroupPanelWeekly` block**

  Find where the active split's day list or overview is rendered. Just above (or below) that block, add:
  ```swift
  if let activeSplit = vm.activeSplit {
      let days = allSplitDays.filter { $0.splitID == activeSplit.id }
      if !days.isEmpty {
          let arrays = weeklyTargetArrays(from: days)
          Section {
              MuscleGroupPanelWeekly(
                  dayTemplateIDs: arrays.templateIDs,
                  dayIsRest: arrays.isRest,
                  dayExerciseNames: arrays.exerciseNames
              )
              .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
              .listRowBackground(Color.clear)
          } header: {
              Text("WEEKLY TARGETS")
          }
      }
  }
  ```

  Adjust the surrounding `Section`/`VStack` to fit the existing layout — the goal is a labeled weekly panel that appears whenever a split is active.

- [ ] **Step 4: Verify build**

  ```bash
  xcodebuild -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

---

## Task 7: Backend — DB Migration

**Files:**
- Create: `apps/elos-api/migrations/023_user_splits.sql`

- [ ] **Step 1: Create the migration file**

  ```sql
  CREATE TABLE user_splits (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    library_key TEXT NOT NULL DEFAULT '',
    is_active   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );

  CREATE TABLE user_split_days (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    split_id       UUID NOT NULL REFERENCES user_splits(id) ON DELETE CASCADE,
    order_index    INTEGER NOT NULL,
    day_label      TEXT NOT NULL,
    day_name       TEXT NOT NULL,
    template_id    TEXT NOT NULL DEFAULT '',
    is_rest        BOOLEAN NOT NULL DEFAULT FALSE,
    exercises_json TEXT NOT NULL DEFAULT '[]'
  );

  CREATE INDEX ON user_splits(user_id);
  CREATE INDEX ON user_split_days(split_id);

  -- Prevent duplicate library splits per user (only applies when library_key is non-empty)
  CREATE UNIQUE INDEX ON user_splits(user_id, library_key) WHERE library_key <> '';
  ```

- [ ] **Step 2: Apply the migration**

  Check how migrations are run in this project (look for a `migrate.ts`, `migrate.js`, or npm script):
  ```bash
  ls /Users/frankbisignano/dev/elos/apps/elos-api/
  cat /Users/frankbisignano/dev/elos/apps/elos-api/package.json | grep -i migrat
  ```
  Run whichever migration command is configured (e.g., `pnpm --filter apps/elos-api migrate`).

---

## Task 8: Backend — Zod Schema + Shared Types

**Files:**
- Modify: `apps/elos-api/src/schemas.ts`
- Modify: `packages/elos-shared/src/index.ts`

- [ ] **Step 1: Add `createSplitSchema` to `schemas.ts`**

  Open `schemas.ts` and append:
  ```typescript
  export const createSplitSchema = z.object({
    name: z.string().min(1).max(200),
    library_key: z.string().max(100).optional(),
    days: z.array(z.object({
      order_index: z.number().int().min(0).max(6),
      day_label: z.string().max(30),
      day_name: z.string().max(200),
      template_id: z.string().max(100).optional(),
      is_rest: z.boolean(),
      exercises_json: z.string().max(2000),
    })).max(7),
  });
  ```

- [ ] **Step 2: Add `UserSplit` and `UserSplitDay` to `packages/elos-shared/src/index.ts`**

  Append at the end of the file:
  ```typescript
  export interface UserSplitDay {
    id: string;
    split_id: string;
    order_index: number;
    day_label: string;
    day_name: string;
    template_id: string;
    is_rest: boolean;
    exercises_json: string;
  }

  export interface UserSplit {
    id: string;
    user_id: string;
    name: string;
    library_key: string;
    is_active: boolean;
    created_at: string;
    days: UserSplitDay[];
  }
  ```

- [ ] **Step 3: Verify TypeScript compiles**

  ```bash
  cd /Users/frankbisignano/dev/elos
  pnpm --filter packages/elos-shared build 2>&1 | tail -10
  ```

---

## Task 9: Backend — Split Service

**Files:**
- Create: `apps/elos-api/src/services/splitService.ts`

- [ ] **Step 1: Create the service file**

  ```typescript
  import { Pool } from "pg";
  import { UserSplit, UserSplitDay } from "elos-shared";

  type CreateSplitDayBody = {
    order_index: number;
    day_label: string;
    day_name: string;
    template_id?: string;
    is_rest: boolean;
    exercises_json: string;
  };

  type CreateSplitBody = {
    name: string;
    library_key?: string;
    days: CreateSplitDayBody[];
  };

  type CreateResult =
    | { conflict: false; split: UserSplit }
    | { conflict: true; existingId: string };

  export class SplitService {
    constructor(private pool: Pool) {}

    async createSplit(userId: string, body: CreateSplitBody): Promise<CreateResult> {
      const client = await this.pool.connect();
      try {
        await client.query("BEGIN");

        const splitResult = await client.query<Omit<UserSplit, "days">>(
          `INSERT INTO user_splits (user_id, name, library_key, is_active)
           VALUES ($1, $2, $3, TRUE)
           RETURNING id, user_id, name, library_key, is_active, created_at::text`,
          [userId, body.name, body.library_key ?? ""]
        );
        const split = splitResult.rows[0];

        // Deactivate all other splits for this user
        await client.query(
          `UPDATE user_splits SET is_active = FALSE
           WHERE user_id = $1 AND id <> $2`,
          [userId, split.id]
        );

        const days: UserSplitDay[] = [];
        for (const day of body.days ?? []) {
          const dayResult = await client.query<UserSplitDay>(
            `INSERT INTO user_split_days
               (split_id, order_index, day_label, day_name, template_id, is_rest, exercises_json)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING *`,
            [
              split.id,
              day.order_index,
              day.day_label,
              day.day_name,
              day.template_id ?? "",
              day.is_rest,
              day.exercises_json,
            ]
          );
          days.push(dayResult.rows[0]);
        }

        await client.query("COMMIT");
        return { conflict: false, split: { ...split, days } };
      } catch (err: any) {
        await client.query("ROLLBACK");
        if (err.code === "23505") {
          // Unique violation — split with this library_key already exists
          const existing = await this.db.query<{ id: string }>(
            `SELECT id FROM user_splits WHERE user_id = $1 AND library_key = $2`,
            [userId, body.library_key ?? ""]
          );
          return { conflict: true, existingId: existing.rows[0]?.id ?? "" };
        }
        throw err;
      } finally {
        client.release();
      }
    }

    async getUserSplits(userId: string): Promise<UserSplit[]> {
      const splits = await this.db.query<Omit<UserSplit, "days">>(
        `SELECT id, user_id, name, library_key, is_active, created_at::text
         FROM user_splits WHERE user_id = $1 ORDER BY created_at DESC`,
        [userId]
      );
      if (splits.rows.length === 0) return [];

      const days = await this.db.query<UserSplitDay>(
        `SELECT * FROM user_split_days
         WHERE split_id = ANY($1) ORDER BY split_id, order_index`,
        [splits.rows.map((s) => s.id)]
      );

      return splits.rows.map((s) => ({
        ...s,
        days: days.rows.filter((d) => d.split_id === s.id),
      }));
    }

    async deleteSplit(userId: string, splitId: string): Promise<boolean> {
      const result = await this.pool.query(
        `DELETE FROM user_splits WHERE id = $1 AND user_id = $2`,
        [splitId, userId]
      );
      return (result.rowCount ?? 0) > 0;
    }

    async activateSplit(userId: string, splitId: string): Promise<UserSplit | null> {
      const client = await this.pool.connect();
      try {
        await client.query("BEGIN");
        await client.query(
          `UPDATE user_splits SET is_active = FALSE WHERE user_id = $1`,
          [userId]
        );
        const result = await client.query<Omit<UserSplit, "days">>(
          `UPDATE user_splits SET is_active = TRUE
           WHERE id = $1 AND user_id = $2
           RETURNING id, user_id, name, library_key, is_active, created_at::text`,
          [splitId, userId]
        );
        await client.query("COMMIT");

        if (!result.rows[0]) return null;
        const split = result.rows[0];

        const days = await this.db.query<UserSplitDay>(
          `SELECT * FROM user_split_days WHERE split_id = $1 ORDER BY order_index`,
          [split.id]
        );
        return { ...split, days: days.rows };
      } catch (err) {
        await client.query("ROLLBACK");
        throw err;
      } finally {
        client.release();
      }
    }
  }
  ```

- [ ] **Step 2: Verify TypeScript compiles**

  ```bash
  cd /Users/frankbisignano/dev/elos
  pnpm --filter apps/elos-api build 2>&1 | tail -10
  ```
  (Or `tsc --noEmit` if that's the check pattern used in this project)

---

## Task 10: Backend — Routes + Register

**Files:**
- Create: `apps/elos-api/src/routes/splits.ts`
- Modify: `apps/elos-api/src/index.ts`

- [ ] **Step 1: Create `routes/splits.ts`**

  ```typescript
  import { Router, Request, Response } from "express";
  import { requireAuth } from "../middleware/auth";
  import { validateBody } from "../middleware/validate";
  import { createSplitSchema } from "../schemas";
  import { SplitService } from "../services/splitService";
  import { pool } from "../db";   // same pattern as all other route files

  const router = Router();
  const service = new SplitService(pool);

  // POST /splits — create a new split
  router.post("/", requireAuth, validateBody(createSplitSchema), async (req: Request, res: Response) => {
    const result = await service.createSplit(req.user!.id, req.body);
    if (result.conflict) {
      res.status(409).json({ conflict: true, existing_id: result.existingId });
      return;
    }
    res.status(201).json(result.split);
  });

  // GET /splits — list user's splits
  router.get("/", requireAuth, async (req: Request, res: Response) => {
    const splits = await service.getUserSplits(req.user!.id);
    res.json(splits);
  });

  // DELETE /splits/:id — delete a split
  router.delete("/:id", requireAuth, async (req: Request, res: Response) => {
    const deleted = await service.deleteSplit(req.user!.id, req.params.id);
    if (!deleted) { res.status(404).json({ error: "Split not found" }); return; }
    res.status(204).send();
  });

  // PATCH /splits/:id/activate — set split active
  router.patch("/:id/activate", requireAuth, async (req: Request, res: Response) => {
    const split = await service.activateSplit(req.user!.id, req.params.id);
    if (!split) { res.status(404).json({ error: "Split not found" }); return; }
    res.json(split);
  });

  export default router;
  ```

  > Check `apps/elos-api/src/routes/templates.ts` to confirm the exact import paths for `requireAuth`, `validateBody`, and `db` — use the same pattern.

- [ ] **Step 2: Register the router in `apps/elos-api/src/index.ts`**

  Open `src/index.ts`. Find where other routers are imported and mounted (around lines 12–22 and 67–77). Add:
  ```typescript
  import splitsRouter from "./routes/splits";
  ```
  And in the mount block:
  ```typescript
  app.use("/splits", splitsRouter);
  ```

- [ ] **Step 3: Verify TypeScript compiles**

  ```bash
  cd /Users/frankbisignano/dev/elos
  pnpm --filter apps/elos-api build 2>&1 | tail -10
  ```
  Expected: no TypeScript errors.

- [ ] **Step 4: Smoke-test the routes manually (optional but recommended)**

  Start the API (`pnpm --filter apps/elos-api dev`) and use curl or Postman to:
  - `POST /splits` with a name + days → expect 201 with split object
  - `GET /splits` → expect array with the created split
  - `PATCH /splits/:id/activate` → expect 200 with `is_active: true`
  - `DELETE /splits/:id` → expect 204

---

## Task 11: Final iOS Build Verification

- [ ] **Step 1: Full clean build**

  ```bash
  cd /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos
  xcodebuild -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16' \
    clean build 2>&1 | grep -E "(BUILD|error:|warning:)" | head -30
  ```
  Expected: `** BUILD SUCCEEDED **` with no errors.

- [ ] **Step 2: Smoke-test subscribe flow in simulator**

  1. Launch the app in the simulator (Cmd+R in Xcode)
  2. Navigate to Train → Programs → tap a library split
  3. Tap **Subscribe** — the button should change to **Already Added**
  4. Go back — the Programs tab should show your active split with a Weekly Targets panel
  5. Kill and relaunch the app — the active split should still be there (from SwiftData)
  6. If the backend is running, check the database: `SELECT * FROM user_splits;` should show a row

- [ ] **Step 3: Verify XP still computes correctly**

  Navigate to the Profile or wherever XP/rank is displayed. Confirm it shows the correct value (no regression from the `ExInfo` → `DayExercise` refactor). If it's blank or zero, check that `prepareExercises(for:)` still decodes `exercisesJSON` correctly after the rename.
