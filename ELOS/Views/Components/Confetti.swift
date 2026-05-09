import SwiftUI

// MARK: - Confetti overlay used on PR celebration

struct ConfettiOverlay: View {
    var trigger: Int            // increment to fire a fresh burst
    var pieceCount: Int = 80
    var palette: [Color] = [.brand, .brandTrophy, .brandSuccess, .brandInfo, .pink]

    @State private var bursts: [Burst] = []

    var body: some View {
        ZStack {
            ForEach(bursts) { burst in
                ConfettiBurst(burst: burst, palette: palette, count: pieceCount)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            let newBurst = Burst(id: UUID())
            bursts.append(newBurst)
            // Cleanup after animation duration
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                bursts.removeAll { $0.id == newBurst.id }
            }
        }
    }

    struct Burst: Identifiable, Equatable {
        let id: UUID
    }
}

private struct ConfettiBurst: View {
    let burst: ConfettiOverlay.Burst
    let palette: [Color]
    let count: Int

    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.45)
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    ConfettiPiece(
                        color: palette[i % palette.count],
                        index: i,
                        animate: animate,
                        bounds: geo.size,
                        center: center
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)) { animate = true }
        }
    }
}

private struct ConfettiPiece: View {
    let color: Color
    let index: Int
    let animate: Bool
    let bounds: CGSize
    let center: CGPoint

    private var seed: CGFloat { CGFloat(index) }
    private var angle: Double { Double((seed * 137).truncatingRemainder(dividingBy: 360)) }
    private var distance: CGFloat { 220 + CGFloat((Int(seed) * 23) % 180) }
    private var dx: CGFloat { distance * CGFloat(cos(angle * .pi / 180.0)) }
    private var dy: CGFloat { distance * CGFloat(sin(angle * .pi / 180.0)) - 80 }
    private var rotation: Double { Double((seed * 47).truncatingRemainder(dividingBy: 720)) }
    private var size: CGFloat { 6 + CGFloat((Int(seed) * 7) % 6) }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size * 0.5)
            .rotationEffect(.degrees(animate ? rotation + 540 : rotation))
            .position(
                x: center.x + (animate ? dx : 0),
                y: center.y + (animate ? bounds.height + 60 : 0) + (animate ? dy * 0.2 : 0)
            )
            .opacity(animate ? 0 : 1)
    }
}
