import SwiftUI

/// Rendered off-screen via ImageRenderer and shared as a PNG.
struct WorkoutShareCard: View {
    let durationMinutes: Int
    let volumeString: String
    let totalSets: Int
    let uniqueExercises: Int
    let topLift: (name: String, weightKg: Double, reps: Int)?
    let capturedPR: String?

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.06, blue: 0.04),
                         Color(red: 0.14, green: 0.06, blue: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle grid pattern
            Canvas { ctx, size in
                let spacing: CGFloat = 28
                var path = Path()
                var x: CGFloat = 0
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                ctx.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("ELOS")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.84, green: 0.35, blue: 0.18))
                    Spacer()
                    Text(dateString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 20)

                // Title
                Text("Session Complete")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 4)

                // Volume hero
                Text(volumeString)
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.bottom, 20)

                // Stats row
                HStack(spacing: 0) {
                    shareStatCol(value: "\(durationMinutes)m", label: "Duration")
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 1, height: 36)
                    shareStatCol(value: "\(totalSets)", label: "Sets")
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 1, height: 36)
                    shareStatCol(value: "\(uniqueExercises)", label: "Exercises")
                }
                .padding(.bottom, 18)

                // Top lift
                if let top = topLift {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.84, green: 0.35, blue: 0.18))
                        Text("Top Lift · \(top.name)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.0f kg × %d", top.weightKg, top.reps))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, capturedPR != nil ? 8 : 0)
                }

                // PR badge
                if let pr = capturedPR {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow)
                        Text("PR · \(pr)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Footer
                HStack {
                    Text("Track your gains at elos.app")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
            }
            .padding(28)
        }
        .frame(width: 390, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func shareStatCol(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
