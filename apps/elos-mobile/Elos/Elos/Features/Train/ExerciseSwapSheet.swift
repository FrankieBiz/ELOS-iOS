import SwiftUI

/// Thin wrapper around `ExercisePickerView` for the in-session "swap exercise" use case.
/// Single-select mode — writes the picked exercise's name back to the bound string.
struct ExerciseSwapSheet: View {
    @Binding var exerciseName: String

    var body: some View {
        ExercisePickerView(onPickSingle: { picked in
            exerciseName = picked.name
        })
    }
}
