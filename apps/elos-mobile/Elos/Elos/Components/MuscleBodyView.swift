import SwiftUI

struct MuscleBodyView: View {
    var activeMuscle: String?
    var secondaryMuscles: [String] = []
    var height: CGFloat = 220

    var body: some View {
        HStack(spacing: 16) {
            BodyFigure(side: .front, activeMuscle: activeMuscle, secondaryMuscles: secondaryMuscles)
            BodyFigure(side: .back,  activeMuscle: activeMuscle, secondaryMuscles: secondaryMuscles)
        }
        .frame(height: height)
    }
}

private enum FigureSide { case front, back }

private struct BodyFigure: View {
    let side: FigureSide
    let activeMuscle: String?
    let secondaryMuscles: [String]

    private func colorFor(_ muscle: String) -> Color {
        let key = muscle.lowercased()
        if let active = activeMuscle?.lowercased(), active == key { return .muscleHi }
        if secondaryMuscles.map({ $0.lowercased() }).contains(key) { return .muscleSec }
        return Color(.systemFill)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let scale = min(w / 60, h / 160)

            ZStack {
                if side == .front {
                    FrontFigureShape(scale: scale)
                        .fill(Color(.secondarySystemBackground))
                    FrontMuscleOverlays(scale: scale, colorFor: colorFor)
                } else {
                    BackFigureShape(scale: scale)
                        .fill(Color(.secondarySystemBackground))
                    BackMuscleOverlays(scale: scale, colorFor: colorFor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Front figure outline
private struct FrontFigureShape: Shape {
    let scale: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let s = scale
        // Head
        p.addEllipse(in: CGRect(x: cx - 9*s, y: 2*s, width: 18*s, height: 20*s))
        // Neck
        p.addRect(CGRect(x: cx - 4*s, y: 20*s, width: 8*s, height: 6*s))
        // Torso
        p.addRoundedRect(in: CGRect(x: cx - 16*s, y: 26*s, width: 32*s, height: 44*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        // Left arm
        p.addRoundedRect(in: CGRect(x: cx - 26*s, y: 26*s, width: 10*s, height: 38*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        // Right arm
        p.addRoundedRect(in: CGRect(x: cx + 16*s, y: 26*s, width: 10*s, height: 38*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        // Left leg
        p.addRoundedRect(in: CGRect(x: cx - 16*s, y: 72*s, width: 14*s, height: 52*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        // Right leg
        p.addRoundedRect(in: CGRect(x: cx + 2*s, y: 72*s, width: 14*s, height: 52*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        return p
    }
}

private struct FrontMuscleOverlays: View {
    let scale: CGFloat
    let colorFor: (String) -> Color

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let s  = scale
            // Chest
            ZStack {
                RoundedRectangle(cornerRadius: 3*s)
                    .fill(colorFor("chest").opacity(0.7))
                    .frame(width: 28*s, height: 14*s)
                    .offset(x: cx - geo.size.width/2, y: 28*s)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .offset(y: 28*s)
            // Shoulders
            Group {
                Ellipse().fill(colorFor("shoulders").opacity(0.7))
                    .frame(width: 10*s, height: 10*s)
                    .offset(x: cx - 22*s, y: 26*s)
                Ellipse().fill(colorFor("shoulders").opacity(0.7))
                    .frame(width: 10*s, height: 10*s)
                    .offset(x: cx + 12*s, y: 26*s)
            }
            // Biceps
            Group {
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("biceps").opacity(0.7))
                    .frame(width: 8*s, height: 16*s)
                    .offset(x: cx - 24*s, y: 38*s)
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("biceps").opacity(0.7))
                    .frame(width: 8*s, height: 16*s)
                    .offset(x: cx + 16*s, y: 38*s)
            }
            // Triceps (visible from front slightly)
            Group {
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("triceps").opacity(0.5))
                    .frame(width: 8*s, height: 14*s)
                    .offset(x: cx - 24*s, y: 36*s)
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("triceps").opacity(0.5))
                    .frame(width: 8*s, height: 14*s)
                    .offset(x: cx + 16*s, y: 36*s)
            }
            // Core / abs
            RoundedRectangle(cornerRadius: 3*s).fill(colorFor("core").opacity(0.7))
                .frame(width: 20*s, height: 18*s)
                .offset(x: cx - 10*s, y: 50*s)
            // Quads/Legs
            Group {
                RoundedRectangle(cornerRadius: 4*s).fill(colorFor("legs").opacity(0.7))
                    .frame(width: 12*s, height: 28*s)
                    .offset(x: cx - 14*s, y: 74*s)
                RoundedRectangle(cornerRadius: 4*s).fill(colorFor("legs").opacity(0.7))
                    .frame(width: 12*s, height: 28*s)
                    .offset(x: cx + 2*s, y: 74*s)
            }
            // Calves
            Group {
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("calves").opacity(0.7))
                    .frame(width: 10*s, height: 18*s)
                    .offset(x: cx - 13*s, y: 104*s)
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("calves").opacity(0.7))
                    .frame(width: 10*s, height: 18*s)
                    .offset(x: cx + 3*s, y: 104*s)
            }
        }
    }
}

// MARK: - Back figure outline
private struct BackFigureShape: Shape {
    let scale: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let s = scale
        p.addEllipse(in: CGRect(x: cx - 9*s, y: 2*s, width: 18*s, height: 20*s))
        p.addRect(CGRect(x: cx - 4*s, y: 20*s, width: 8*s, height: 6*s))
        p.addRoundedRect(in: CGRect(x: cx - 16*s, y: 26*s, width: 32*s, height: 44*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        p.addRoundedRect(in: CGRect(x: cx - 26*s, y: 26*s, width: 10*s, height: 38*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        p.addRoundedRect(in: CGRect(x: cx + 16*s, y: 26*s, width: 10*s, height: 38*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        p.addRoundedRect(in: CGRect(x: cx - 16*s, y: 72*s, width: 14*s, height: 52*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        p.addRoundedRect(in: CGRect(x: cx + 2*s, y: 72*s, width: 14*s, height: 52*s), cornerSize: CGSize(width: 4*s, height: 4*s))
        return p
    }
}

private struct BackMuscleOverlays: View {
    let scale: CGFloat
    let colorFor: (String) -> Color

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let s  = scale
            // Lats / Back
            RoundedRectangle(cornerRadius: 3*s).fill(colorFor("back").opacity(0.7))
                .frame(width: 28*s, height: 26*s)
                .offset(x: cx - 14*s, y: 30*s)
            // Rear shoulders
            Group {
                Ellipse().fill(colorFor("shoulders").opacity(0.7))
                    .frame(width: 10*s, height: 10*s)
                    .offset(x: cx - 22*s, y: 26*s)
                Ellipse().fill(colorFor("shoulders").opacity(0.7))
                    .frame(width: 10*s, height: 10*s)
                    .offset(x: cx + 12*s, y: 26*s)
            }
            // Triceps (clearly visible from back)
            Group {
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("triceps").opacity(0.7))
                    .frame(width: 8*s, height: 20*s)
                    .offset(x: cx - 24*s, y: 34*s)
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("triceps").opacity(0.7))
                    .frame(width: 8*s, height: 20*s)
                    .offset(x: cx + 16*s, y: 34*s)
            }
            // Glutes
            Group {
                RoundedRectangle(cornerRadius: 4*s).fill(colorFor("glutes").opacity(0.7))
                    .frame(width: 13*s, height: 16*s)
                    .offset(x: cx - 14*s, y: 68*s)
                RoundedRectangle(cornerRadius: 4*s).fill(colorFor("glutes").opacity(0.7))
                    .frame(width: 13*s, height: 16*s)
                    .offset(x: cx + 1*s, y: 68*s)
            }
            // Hamstrings
            Group {
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("hamstrings").opacity(0.7))
                    .frame(width: 12*s, height: 26*s)
                    .offset(x: cx - 14*s, y: 76*s)
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("hamstrings").opacity(0.7))
                    .frame(width: 12*s, height: 26*s)
                    .offset(x: cx + 2*s, y: 76*s)
            }
            // Calves (back)
            Group {
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("calves").opacity(0.7))
                    .frame(width: 10*s, height: 18*s)
                    .offset(x: cx - 13*s, y: 104*s)
                RoundedRectangle(cornerRadius: 3*s).fill(colorFor("calves").opacity(0.7))
                    .frame(width: 10*s, height: 18*s)
                    .offset(x: cx + 3*s, y: 104*s)
            }
        }
    }
}

#Preview {
    MuscleBodyView(activeMuscle: "chest", secondaryMuscles: ["shoulders", "triceps"])
        .padding()
}
