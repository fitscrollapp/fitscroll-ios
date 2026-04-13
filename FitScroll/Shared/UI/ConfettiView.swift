import SwiftUI

/// Lightweight confetti effect rendered via Canvas + TimelineView.
/// No external dependencies, no heavy per-particle SwiftUI views.
struct ConfettiView: View {
    let particleCount: Int
    let duration: Double

    init(particleCount: Int = 90, duration: Double = 3.0) {
        self.particleCount = particleCount
        self.duration = duration
    }

    private struct Particle {
        let startX: CGFloat
        let drift: CGFloat
        let startDelay: Double
        let fallSpeed: Double
        let rotationSpeed: Double
        let size: CGFloat
        let color: Color
        let shape: Shape

        enum Shape {
            case rect
            case circle
        }
    }

    @State private var startTime = Date()
    @State private var particles: [Particle] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startTime)
                for p in particles {
                    let localT = (elapsed - p.startDelay) * p.fallSpeed / duration
                    guard localT > 0 && localT < 1.2 else { continue }

                    // Clamp the motion so the particle settles at the bottom
                    // after its run completes.
                    let t = min(1.0, localT)

                    let x = size.width * p.startX + p.drift * CGFloat(t)
                    let y = (size.height + 80) * CGFloat(t) - 40
                    let rotation = Angle.degrees(p.rotationSpeed * elapsed)

                    // Fade the last 20% of the flight.
                    let fade: Double = t > 0.8 ? max(0, 1 - (t - 0.8) * 5) : 1.0

                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: rotation)
                    ctx.opacity = fade

                    switch p.shape {
                    case .rect:
                        let rect = CGRect(
                            x: -p.size / 2,
                            y: -p.size * 0.7,
                            width: p.size,
                            height: p.size * 1.4
                        )
                        ctx.fill(Path(rect), with: .color(p.color))
                    case .circle:
                        let rect = CGRect(
                            x: -p.size / 2,
                            y: -p.size / 2,
                            width: p.size,
                            height: p.size
                        )
                        ctx.fill(Path(ellipseIn: rect), with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            if particles.isEmpty {
                particles = Self.makeParticles(count: particleCount)
                startTime = Date()
            }
        }
    }

    private static func makeParticles(count: Int) -> [Particle] {
        let palette: [Color] = [
            Color(red: 1.00, green: 0.30, blue: 0.25),
            Color(red: 1.00, green: 0.75, blue: 0.15),
            Color(red: 0.25, green: 0.90, blue: 0.45),
            Color(red: 0.20, green: 0.60, blue: 1.00),
            Color(red: 0.80, green: 0.30, blue: 0.95),
            Color(red: 1.00, green: 0.50, blue: 0.80),
            Color(red: 0.00, green: 0.90, blue: 0.85),
        ]

        return (0..<count).map { _ in
            Particle(
                startX: CGFloat.random(in: 0.05...0.95),
                drift: CGFloat.random(in: -120...120),
                startDelay: Double.random(in: 0...0.6),
                fallSpeed: Double.random(in: 0.8...1.4),
                rotationSpeed: Double.random(in: 90...540) * (Bool.random() ? 1 : -1),
                size: CGFloat.random(in: 8...16),
                color: palette.randomElement()!,
                shape: Bool.random() ? .rect : .circle
            )
        }
    }
}
