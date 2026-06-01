import SwiftUI
import SwiftData
import Combine

final class ProfileEditViewModel: ObservableObject {
    @Published var firstName     = ""
    @Published var lastName      = ""
    @Published var heightFeet    = 5
    @Published var heightInches  = 10
    @Published var weightLbs: Double = 160
    @Published var ageYears      = 17
    @Published var experience    = "beginner"
    @Published var trainingGoal  = "hypertrophy"
    @Published var schoolName    = ""
    @Published var schoolYear    = "sophomore"
    @Published var calGoal       = 2500
    @Published var proteinGoal   = 180
    @Published var carbGoal      = 300
    @Published var fatGoal       = 80

    @Published var isLoading     = false
    @Published var errorMessage: String?
    @Published var saveSuccess   = false

    func load(from record: UserProfileRecord) {
        firstName    = record.firstName
        lastName     = record.lastName
        let totalIn  = Int(record.heightCm / 2.54)
        heightFeet   = max(3, totalIn / 12)
        heightInches = totalIn % 12
        weightLbs    = record.weightKg > 0 ? record.weightKg / 0.453592 : 160
        ageYears     = record.ageYears > 0 ? record.ageYears : 17
        experience   = record.trainingExperience.isEmpty ? "beginner" : record.trainingExperience
        trainingGoal = record.trainingGoal.isEmpty ? "hypertrophy" : record.trainingGoal
        schoolName   = record.schoolName
        schoolYear   = record.schoolYear.isEmpty ? "sophomore" : record.schoolYear
        calGoal      = record.calGoal > 0 ? record.calGoal : 2500
        proteinGoal  = record.proteinGoal > 0 ? record.proteinGoal : 180
        carbGoal     = record.carbGoal > 0 ? record.carbGoal : 300
        fatGoal      = record.fatGoal > 0 ? record.fatGoal : 80
    }

    private var heightCm: Double { Double(heightFeet * 12 + heightInches) * 2.54 }
    private var weightKg: Double { weightLbs * 0.453592 }

    func save(record: UserProfileRecord, context: ModelContext, appVM: AppViewModel) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        let body = ProfileUpdateBody(
            first_name:          firstName,
            last_name:           lastName,
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
            fat_goal:            fatGoal
        )

        do {
            let _: ProfileUpdateBody = try await ApiClient.shared.patch("/profile", body: body)
        } catch {
            // Save locally even if network is unavailable
        }

        record.firstName          = firstName
        record.lastName           = lastName
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
        try? context.save()

        appVM.displayName = firstName.isEmpty ? "there" : firstName
        appVM.userProfile = UserProfileSnapshot(
            firstName:  firstName,
            lastName:   lastName,
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

    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("First Name", text: $editVM.firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $editVM.lastName)
                        .textContentType(.familyName)
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
                        Text(String(format: "%.0f lbs", editVM.weightLbs))
                            .foregroundStyle(.secondary)
                        Stepper("", value: $editVM.weightLbs, in: 50...500, step: 1)
                            .labelsHidden()
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
                        Task { await saveProfile() }
                    } label: {
                        if editVM.isLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(editVM.isLoading || editVM.firstName.isEmpty)
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
        let desc = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.ownerID == uid })
        if let record = try? modelContext.fetch(desc).first {
            editVM.load(from: record)
        }
    }

    private func saveProfile() async {
        let uid = authStore.currentUserID
        let desc = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.ownerID == uid })
        guard let record = try? modelContext.fetch(desc).first else {
            editVM.errorMessage = "Profile not found. Try signing out and back in."
            return
        }
        await editVM.save(record: record, context: modelContext, appVM: vm)
    }
}
