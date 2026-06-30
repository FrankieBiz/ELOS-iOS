import SwiftUI
import SwiftData
import Combine

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var firstName     = ""
    @Published var lastName      = ""
    @Published var username      = ""
    @Published var usernameStatus: OnboardingViewModel.UsernameStatus = .empty
    private var originalUsername = ""
    private var usernameCheckTask: Task<Void, Never>?
    @Published var heightFeet    = 5
    @Published var heightInches  = 10
    @Published var weightKg: Double = 72.5
    @Published var ageYears      = 17
    @Published var experience    = "beginner"
    @Published var trainingGoal  = "hypertrophy"
    @Published var schoolName    = ""
    @Published var schoolYear    = "sophomore"
    @Published var calGoal       = 2500
    @Published var proteinGoal   = 180
    @Published var carbGoal      = 300
    @Published var fatGoal       = 80
    @Published var equipmentPosture: EquipmentPosture = .fullGym
    @Published var equipmentCustomTypes: Set<String> = []

    @Published var isLoading     = false
    @Published var errorMessage: String?
    @Published var saveSuccess   = false

    func load(from record: UserProfileRecord) {
        firstName    = record.firstName
        lastName     = record.lastName
        originalUsername = record.username
        if record.username.isEmpty {
            // Legacy user with no handle yet — pre-fill a suggestion and check it.
            let suggestion = Self.suggestedUsername(first: record.firstName, last: record.lastName)
            username = suggestion
            onUsernameChanged(suggestion)
        } else {
            username = record.username
            usernameStatus = .available
        }
        let totalIn  = Int(record.heightCm / 2.54)
        heightFeet   = max(3, totalIn / 12)
        heightInches = totalIn % 12
        weightKg     = record.weightKg > 0 ? record.weightKg : 72.5
        ageYears     = record.ageYears > 0 ? record.ageYears : 17
        experience   = record.trainingExperience.isEmpty ? "beginner" : record.trainingExperience
        trainingGoal = record.trainingGoal.isEmpty ? "hypertrophy" : record.trainingGoal
        schoolName   = record.schoolName
        schoolYear   = record.schoolYear.isEmpty ? "sophomore" : record.schoolYear
        calGoal      = record.calGoal > 0 ? record.calGoal : 2500
        proteinGoal  = record.proteinGoal > 0 ? record.proteinGoal : 180
        carbGoal     = record.carbGoal > 0 ? record.carbGoal : 300
        fatGoal      = record.fatGoal > 0 ? record.fatGoal : 80
        let pref     = record.equipmentPreference
        equipmentPosture     = pref.posture
        equipmentCustomTypes = pref.customTypes
    }

    private var heightCm: Double { Double(heightFeet * 12 + heightInches) * 2.54 }

    static func suggestedUsername(first: String, last: String) -> String {
        let base = (first + last.prefix(1))
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
        let trimmed = String(base.prefix(18))
        if trimmed.count >= 3, trimmed.first?.isLetter == true { return trimmed }
        return "athlete"
    }

    /// Validate + debounce-check the username (mirrors onboarding). The user's own
    /// current handle is always treated as available.
    func onUsernameChanged(_ raw: String) {
        let normalized = raw.lowercased()
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespaces)
        if normalized != username { username = normalized; return }

        usernameCheckTask?.cancel()
        if !originalUsername.isEmpty && normalized == originalUsername {
            usernameStatus = .available
            return
        }
        guard !normalized.isEmpty else { usernameStatus = .empty; return }
        guard OnboardingViewModel.isValidUsername(normalized) else { usernameStatus = .invalid; return }

        usernameStatus = .checking
        usernameCheckTask = Task { [normalized] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let available = await OnboardingViewModel.checkAvailability(normalized)
            guard !Task.isCancelled, self.username == normalized else { return }
            switch available {
            case .some(true):  self.usernameStatus = .available
            case .some(false): self.usernameStatus = .taken
            case .none:        self.usernameStatus = .unknown
            }
        }
    }

    func save(record: UserProfileRecord, context: ModelContext, appVM: AppViewModel, useImperial: Bool) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        let body = ProfileUpdateBody(
            first_name:          firstName,
            last_name:           lastName,
            username:            username.isEmpty ? nil : username,
            height_cm:           heightCm,
            weight_kg:           weightKg,
            age_years:           ageYears,
            training_experience: experience,
            training_goal:       trainingGoal,
            school_name:         schoolName,
            school_year:         schoolYear,
            cal_goal:            calGoal,
            protein_goal:        proteinGoal,
            carb_goal:           carbGoal,
            fat_goal:            fatGoal,
            use_imperial:        useImperial
        )

        var networkSucceeded = false
        do {
            let _: ProfileResponse = try await ApiClient.shared.patch("/profile", body: body)
            networkSucceeded = true
        } catch ApiError.httpError(409, _) {
            // Username taken — surface it and don't persist (let the user pick another).
            errorMessage = "That username is taken — try another."
            usernameStatus = .taken
            return
        } catch {
            // Other failure (offline): save locally; syncPending retries on next launch.
        }

        record.firstName          = firstName
        record.lastName           = lastName
        record.username           = username
        record.heightCm           = heightCm
        record.weightKg           = weightKg
        record.ageYears           = ageYears
        record.trainingExperience = experience
        record.trainingGoal       = trainingGoal
        record.schoolName         = schoolName
        record.schoolYear         = schoolYear
        record.calGoal            = calGoal
        record.proteinGoal        = proteinGoal
        record.carbGoal           = carbGoal
        record.fatGoal            = fatGoal
        record.useImperial        = useImperial
        record.equipmentPreference = EquipmentPreference(posture: equipmentPosture, customTypes: equipmentCustomTypes)
        record.syncPending        = !networkSucceeded
        try? context.save()

        appVM.displayName = firstName.isEmpty ? "there" : firstName
        appVM.userProfile = UserProfileSnapshot(
            firstName:  firstName,
            lastName:   lastName,
            username:   username,
            email:      record.email,
            schoolName: schoolName,
            schoolYear: schoolYear
        )

        saveSuccess = true
    }
}

struct ProfileEditView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editVM = ProfileEditViewModel()

    private let experienceOptions: [(String, String)] = [
        ("beginner",     "Beginner"),
        ("intermediate", "Intermediate"),
        ("advanced",     "Advanced"),
    ]
    private let goalOptions: [(String, String)] = [
        ("strength",    "Strength"),
        ("hypertrophy", "Hypertrophy"),
        ("endurance",   "Endurance"),
        ("weight_loss", "Weight Loss"),
    ]
    private let yearOptions: [(String, String)] = [
        ("freshman",  "Freshman"),
        ("sophomore", "Sophomore"),
        ("junior",    "Junior"),
        ("senior",    "Senior"),
    ]
    private let customEquipmentOptions: [EquipmentFilter] =
        EquipmentFilter.allCases.filter { $0 != .all }

    private func postureLabel(_ posture: EquipmentPosture) -> String {
        switch posture {
        case .fullGym: return "Full gym"
        case .home:    return "Home"
        case .custom:  return "Custom"
        }
    }

    @ViewBuilder
    private var usernameStatusIcon: some View {
        switch editVM.usernameStatus {
        case .checking:        ProgressView().controlSize(.small)
        case .available:       Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.good)
        case .taken, .invalid: Image(systemName: "xmark.circle.fill").foregroundStyle(Color.bad)
        case .unknown:         Image(systemName: "wifi.slash").foregroundStyle(.secondary)
        case .empty:           EmptyView()
        }
    }

    private var usernameFooter: String {
        switch editVM.usernameStatus {
        case .empty:     return "This is how friends find you. Letters, numbers, underscore."
        case .checking:  return "Checking availability…"
        case .available: return "✓ Available"
        case .taken:     return "That username is taken — try another."
        case .invalid:   return "3–20 characters, must start with a letter."
        case .unknown:   return "Couldn't check right now — you can still save."
        }
    }

    private var usernameFooterColor: Color {
        switch editVM.usernameStatus {
        case .available: return Color.good
        case .taken, .invalid: return Color.bad
        default: return .secondary
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("First Name", text: $editVM.firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $editVM.lastName)
                        .textContentType(.familyName)
                } header: {
                    Text("Name")
                } footer: {
                    if editVM.firstName.isEmpty {
                        Text("First name is required to save.").foregroundStyle(Color.bad)
                    }
                }

                Section {
                    HStack(spacing: 4) {
                        Text("@").foregroundStyle(.secondary)
                        TextField("username", text: $editVM.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .onChange(of: editVM.username) { _, newValue in
                                editVM.onUsernameChanged(newValue)
                            }
                        usernameStatusIcon
                    }
                } header: {
                    Text("Username")
                } footer: {
                    Text(usernameFooter).foregroundStyle(usernameFooterColor)
                }

                Section("Training") {
                    Picker("Experience", selection: $editVM.experience) {
                        ForEach(experienceOptions, id: \.0) { id, label in
                            Text(label).tag(id)
                        }
                    }
                    Picker("Primary Goal", selection: $editVM.trainingGoal) {
                        ForEach(goalOptions, id: \.0) { id, label in
                            Text(label).tag(id)
                        }
                    }
                }

                Section("Equipment") {
                    Picker("Available", selection: $editVM.equipmentPosture) {
                        ForEach(EquipmentPosture.allCases, id: \.self) { posture in
                            Text(postureLabel(posture)).tag(posture)
                        }
                    }
                    if editVM.equipmentPosture == .custom {
                        ForEach(customEquipmentOptions, id: \.self) { filter in
                            let token = filter.rawValue.lowercased()
                            Toggle(filter.rawValue, isOn: Binding(
                                get: { editVM.equipmentCustomTypes.contains(token) },
                                set: { isOn in
                                    if isOn { editVM.equipmentCustomTypes.insert(token) }
                                    else    { editVM.equipmentCustomTypes.remove(token) }
                                }
                            ))
                        }
                    }
                }

                Section("Body Metrics") {
                    Stepper("Age: \(editVM.ageYears) yrs", value: $editVM.ageYears, in: 13...80)
                    HStack {
                        Text("Height")
                        Spacer()
                        Stepper("", value: $editVM.heightFeet, in: 3...8)
                            .labelsHidden()
                        Text("\(editVM.heightFeet)'")
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 28, alignment: .trailing)
                        Stepper("", value: $editVM.heightInches, in: 0...11)
                            .labelsHidden()
                        Text("\(editVM.heightInches)\"")
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 28, alignment: .trailing)
                    }
                    HStack {
                        Text("Weight")
                        Spacer()
                        Text(vm.weightUnit.formatWeight(kg: editVM.weightKg))
                            .foregroundStyle(.secondary)
                        Stepper("", value: Binding(
                            get: { vm.weightUnit.fromKg(editVM.weightKg) },
                            set: { editVM.weightKg = vm.weightUnit.toKg($0) }
                        ), in: vm.weightUnit == .kg ? 20...300 : 50...660, step: 1)
                            .labelsHidden()
                    }
                    HStack {
                        Text("Unit")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { vm.weightUnit },
                            set: { vm.setWeightUnit($0) }
                        )) {
                            Text("kg").tag(WeightUnit.kg)
                            Text("lb").tag(WeightUnit.lb)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }

                Section("School") {
                    TextField("School Name", text: $editVM.schoolName)
                    Picker("Year", selection: $editVM.schoolYear) {
                        ForEach(yearOptions, id: \.0) { id, label in
                            Text(label).tag(id)
                        }
                    }
                }

                Section("Nutrition Goals") {
                    Stepper("Calories: \(editVM.calGoal) kcal",
                            value: $editVM.calGoal, in: 1200...5000, step: 50)
                    Stepper("Protein: \(editVM.proteinGoal)g",
                            value: $editVM.proteinGoal, in: 0...400, step: 5)
                    Stepper("Carbs: \(editVM.carbGoal)g",
                            value: $editVM.carbGoal, in: 0...800, step: 5)
                    Stepper("Fat: \(editVM.fatGoal)g",
                            value: $editVM.fatGoal, in: 0...300, step: 5)
                }

                if let err = editVM.errorMessage {
                    Section {
                        Text(err).foregroundStyle(Color.bad)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticManager.impact(.medium)
                        Task { await saveProfile() }
                    } label: {
                        if editVM.isLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(editVM.isLoading || editVM.firstName.isEmpty
                              || !(editVM.usernameStatus == .available || editVM.usernameStatus == .unknown))
                }
            }
            .onAppear { loadProfile() }
            .onChange(of: editVM.saveSuccess) { _, success in
                if success { dismiss() }
            }
        }
    }

    private func loadProfile() {
        let uid = authStore.currentUserID
        guard !uid.isEmpty else { return }
        let desc = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.ownerID == uid })
        if let record = try? modelContext.fetch(desc).first {
            editVM.load(from: record)
        }
        // If no local record the form shows default values — that's fine,
        // saveProfile() will create the record on first save.
    }

    private func saveProfile() async {
        let uid = authStore.currentUserID
        guard !uid.isEmpty else { return }
        let desc = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.ownerID == uid })
        let record: UserProfileRecord
        if let existing = try? modelContext.fetch(desc).first {
            record = existing
        } else {
            // No local record — create one (covers new device / reinstall / login without onboarding)
            let newRecord = UserProfileRecord(id: uid, ownerID: uid, email: "")
            modelContext.insert(newRecord)
            record = newRecord
        }
        await editVM.save(record: record, context: modelContext, appVM: vm, useImperial: vm.weightUnit.useImperial)
    }
}
