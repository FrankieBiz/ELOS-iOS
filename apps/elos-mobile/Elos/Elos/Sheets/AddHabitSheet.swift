import SwiftUI

struct AddHabitSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    @State private var habitName    = ""
    @State private var selectedCat  = "General"
    @State private var targetDays   = 7

    private let categories = ["Fitness", "Mindset", "Nutrition", "Recovery", "Learning", "General"]
    private let dayOptions = [3, 4, 5, 6, 7]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Drag indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 4)
                        .padding(.top, 4)

                    // Name field
                    TextField("Habit name…", text: $habitName)
                        .focused($nameFocused)
                        .font(.title3)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Category
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CATEGORY")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    selectedCat = cat
                                } label: {
                                    Text(cat)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(selectedCat == cat ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedCat == cat ? Color.tint : Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 9))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Target days
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TARGET DAYS PER WEEK")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(dayOptions, id: \.self) { d in
                                Button {
                                    targetDays = d
                                } label: {
                                    Text("\(d)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(targetDays == d ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(targetDays == d ? Color.tint : Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 9))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Add button
                    Button {
                        addHabit()
                        dismiss()
                    } label: {
                        Text("Add Habit")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(habitName.isEmpty ? Color.secondary : Color.tint)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(habitName.isEmpty)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHabit()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(habitName.isEmpty ? Color.secondary : Color.tint)
                    .disabled(habitName.isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    private func addHabit() {
        guard !habitName.isEmpty else { return }
        let habitId = habitName.lowercased().replacingOccurrences(of: " ", with: "_")
        vm.addHabit(Habit(id: habitId, label: habitName, category: selectedCat, streak: 0, done: false))
    }
}
