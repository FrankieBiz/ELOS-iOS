import SwiftUI

struct MacroBarView: View {
    var label: String
    var value: Int
    var goal: Int
    var color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return Double(value) / Double(goal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(value)g")
                    .font(.caption2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            ProgressBar(value: progress, color: color, height: 5)
        }
    }
}

#Preview {
    VStack {
        MacroBarView(label: "Protein", value: 145, goal: 220, color: .mNutri)
        MacroBarView(label: "Carbs",   value: 200, goal: 360, color: .mSched)
        MacroBarView(label: "Fat",     value: 60,  goal: 95,  color: .mExams)
    }
    .padding()
}
