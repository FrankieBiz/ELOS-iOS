import SwiftUI

struct ExerciseHowToSheet: View {
    let howTo: ExerciseHowTo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ExerciseHowToImage(imageKey: howTo.imageKey)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(howTo.steps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
                                Text(step)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(howTo.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Placeholder until a later group adds the bundled asset catalog. Renders nothing when
/// the key is absent or the asset isn't bundled yet.
struct ExerciseHowToImage: View {
    let imageKey: String?
    var body: some View {
        if let key = imageKey, UIImage(named: key) != nil {
            Image(key)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
