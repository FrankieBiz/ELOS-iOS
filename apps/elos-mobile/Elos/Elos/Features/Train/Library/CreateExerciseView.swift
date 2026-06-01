import SwiftUI

struct CreateExerciseView: View {
    let onSave: (String, String, String, String) -> Void

    @State private var name           = ""
    @State private var primaryMuscle  = "chest"
    @State private var equipment      = "barbell"
    @State private var movementPattern = "push"

    private let muscles   = ["chest","lats","quads","hamstrings","glutes","front_delts","side_delts","rear_delts","biceps","triceps","core","calves","other"]
    private let equipment_ = ["barbell","dumbbell","machine","cable","bodyweight","other"]
    private let patterns  = ["push","pull","hinge","squat","carry","isolation","other"]

    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Name") {
                    TextField("e.g. Paused Bench Press", text: $name)
                }
                Section("Details") {
                    Picker("Primary Muscle", selection: $primaryMuscle) {
                        ForEach(muscles, id: \.self) { Text($0.capitalized.replacingOccurrences(of: "_", with: " ")).tag($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(equipment_, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    Picker("Movement Pattern", selection: $movementPattern) {
                        ForEach(patterns, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onSave("", "", "", "") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onSave(name.trimmingCharacters(in: .whitespaces), primaryMuscle, equipment, movementPattern)
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
