import SwiftUI

/// Electric + ember burst that fires every time the rep counter ticks
/// up. The effect escalates at milestones — every 5 reps gets a
/// bigger burst, every 10 gets lightning bolts and a floating label.
struct RepBurstEffect: View {
    let repCount: Int
    /// Approximate diameter of the element we're bursting from.
    var baseSize: CGFloat = 96

    @State private var shockScale: CGFloat = 1
    @State private var shockOpacity: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var particleProgress: Double = 0
    @State private var particleSeed: Int = 0
    @State private var currentTier: Tier = .standard
    @State private var labelOffset: CGFloat = 0
    @State private var labelOpacity: Double = 0
    @State private var labelText: String = ""
    @State private var boltOpacity: Double = 0
    @State private var boltScale: CGFloat = 1

    /// Escalation levels. Each rep computes its tier from the count.
    enum Tier {
        case standard  // every rep
        case mid       // every 5th rep
        case mega      // every 10th rep
    }

    private let standardColors: [Color] = [
        Color(red: 1.0, green: 0.85, blue: 0.15),  // yellow
        Color(red: 1.0, green: 0.55, blue: 0.05),  // orange
        Color(red: 1.0, green: 0.30, blue: 0.15),  // red-orange
        Color(red: 0.25, green: 0.95, blue: 1.0),  // electric cyan
    ]

    private let megaColors: [Color] = [
        Color(red: 1.0, green: 0.95, blue: 0.30),
        Color(red: 1.0, green: 0.70, blue: 0.00),
        Color(red: 1.0, green: 0.35, blue: 0.05),
        Color(red: 0.90, green: 0.10, blue: 0.90),  // electric magenta
        Color(red: 0.25, green: 0.95, blue: 1.0),
    ]

    var body: some View {
        ZStack {
            // White flash backdrop.
            Circle()
                .fill(Color.white)
                .frame(
                    width: baseSize * flashSizeMultiplier,
                    height: baseSize * flashSizeMultiplier
                )
                .blur(radius: 30)
                .opacity(flashOpacity)

            // Primary shockwave ring.
            Circle()
                .strokeBorder(ringGradient, lineWidth: ringWidth)
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(shockScale)
                .opacity(shockOpacity)

            // Mega tier only: a second, thinner outer ring that trails
            // behind the primary one for a doubled shockwave effect.
            if currentTier == .mega {
                Circle()
                    .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                    .frame(width: baseSize, height: baseSize)
                    .scaleEffect(shockScale * 0.85)
                    .opacity(shockOpacity * 0.6)
            }

            // Embers.
            ForEach(0..<particleCount, id: \.self) { i in
                emberParticle(index: i)
            }

            // Lightning bolts — lightning starts at mid tier. Mid gets
            // 3 bolts, mega gets 6 longer bolts with cyan glow.
            if currentTier != .standard {
                ForEach(0..<boltCount, id: \.self) { i in
                    lightningBolt(index: i)
                }
            }

            // Milestone label ("x5!" or "x10!") floats up and fades.
            if !labelText.isEmpty {
                Text(labelText)
                    .font(.system(size: labelFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.95, blue: 0.30),
                                Color(red: 1.0, green: 0.55, blue: 0.00),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .orange.opacity(0.9), radius: 10)
                    .offset(y: labelOffset)
                    .opacity(labelOpacity)
                    .scaleEffect(labelOpacity > 0 ? 1 : 0.6)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: repCount) { oldValue, newValue in
            guard newValue > oldValue else { return }
            trigger(for: newValue)
        }
    }

    // MARK: - Per-tier parameters

    private var particleCount: Int {
        switch currentTier {
        case .standard: return 12
        case .mid:      return 16
        case .mega:     return 24
        }
    }

    private var boltCount: Int {
        switch currentTier {
        case .standard: return 0
        case .mid:      return 3
        case .mega:     return 6
        }
    }

    private var ringWidth: CGFloat {
        switch currentTier {
        case .standard: return 4
        case .mid:      return 5
        case .mega:     return 7
        }
    }

    private var flashSizeMultiplier: CGFloat {
        switch currentTier {
        case .standard: return 1.8
        case .mid:      return 2.3
        case .mega:     return 3.2
        }
    }

    private var peakShockScale: CGFloat {
        // Don't let the ring dwarf the counter — mid tier keeps the
        // same scale as standard and leans on lightning for impact.
        switch currentTier {
        case .standard: return 2.4
        case .mid:      return 2.5
        case .mega:     return 3.2
        }
    }

    private var peakFlashOpacity: Double {
        switch currentTier {
        case .standard: return 0.55
        case .mid:      return 0.70
        case .mega:     return 0.90
        }
    }

    private var particleDistance: CGFloat {
        switch currentTier {
        case .standard: return baseSize * 1.15
        case .mid:      return baseSize * 1.25
        case .mega:     return baseSize * 1.7
        }
    }

    private var shockwaveDuration: Double {
        switch currentTier {
        case .standard: return 0.65
        case .mid:      return 0.8
        case .mega:     return 1.0
        }
    }

    private var particleDuration: Double {
        switch currentTier {
        case .standard: return 0.75
        case .mid:      return 0.9
        case .mega:     return 1.1
        }
    }

    private var labelFontSize: CGFloat {
        switch currentTier {
        case .standard: return 0
        case .mid:      return 36
        case .mega:     return 54
        }
    }

    private var activeColors: [Color] {
        currentTier == .mega ? megaColors : standardColors
    }

    private var ringGradient: LinearGradient {
        switch currentTier {
        case .standard:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.85, blue: 0.20),
                    Color(red: 1.0, green: 0.50, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mid:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.95, blue: 0.35),
                    Color(red: 1.0, green: 0.45, blue: 0.00),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mega:
            return LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 1.0, green: 0.85, blue: 0.20),
                    Color(red: 1.0, green: 0.30, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Sub-views

    private func emberParticle(index i: Int) -> some View {
        let baseAngle = Double(i) / Double(particleCount) * 2 * .pi
        let seedJitter = Double(particleSeed % 7) * 0.15
        let angle = baseAngle + seedJitter
        let t = particleProgress
        let distance = particleDistance * CGFloat(easeOut(t))
        let dx = cos(angle) * Double(distance)
        let dy = sin(angle) * Double(distance)
        let baseParticleSize: CGFloat = currentTier == .mega ? 10 : 7
        return Circle()
            .fill(activeColors[(i + particleSeed) % activeColors.count])
            .frame(
                width: baseParticleSize - CGFloat(t) * (baseParticleSize - 2),
                height: baseParticleSize - CGFloat(t) * (baseParticleSize - 2)
            )
            .offset(x: dx, y: dy)
            .opacity(1 - t)
            .blur(radius: CGFloat(t) * 1.5)
    }

    private func lightningBolt(index i: Int) -> some View {
        // Evenly space bolts around the circle + small per-burst jitter
        // so consecutive milestones don't line up identically.
        let total = Double(max(boltCount, 1))
        let jitter = Double(particleSeed % 11) * 0.12
        let angle = Double(i) / total * 2 * .pi + jitter
        let boltLength: CGFloat = currentTier == .mega
            ? baseSize * 2.0
            : baseSize * 1.5
        let boltWidth: CGFloat = currentTier == .mega ? 8 : 5

        return LightningBoltShape()
            .stroke(
                LinearGradient(
                    colors: [
                        .white,
                        Color(red: 0.85, green: 0.95, blue: 1.0),
                        Color(red: 0.25, green: 0.85, blue: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: boltWidth, lineCap: .round, lineJoin: .round)
            )
            .frame(width: boltWidth * 3, height: boltLength)
            .shadow(color: Color.cyan.opacity(0.95), radius: 12)
            .shadow(color: Color.white.opacity(0.8), radius: 4)
            .rotationEffect(.radians(angle + .pi / 2))
            .offset(
                x: cos(angle) * Double(baseSize) * 0.9,
                y: sin(angle) * Double(baseSize) * 0.9
            )
            .scaleEffect(boltScale)
            .opacity(boltOpacity)
    }

    // MARK: - Trigger

    private func trigger(for count: Int) {
        let tier: Tier = {
            if count > 0 && count % 10 == 0 { return .mega }
            if count > 0 && count % 5 == 0  { return .mid }
            return .standard
        }()
        currentTier = tier

        // Reset animatable state.
        shockScale = 1
        shockOpacity = 0.95
        flashOpacity = peakFlashOpacity
        particleProgress = 0
        particleSeed &+= 1

        // Shockwave + flash.
        withAnimation(.easeOut(duration: shockwaveDuration)) {
            shockScale = peakShockScale
            shockOpacity = 0
        }
        withAnimation(.easeOut(duration: shockwaveDuration * 0.55)) {
            flashOpacity = 0
        }

        // Embers.
        withAnimation(.easeOut(duration: particleDuration)) {
            particleProgress = 1
        }

        // Milestone label for mid + mega.
        if tier != .standard {
            labelText = "x\(count)"
            labelOffset = 0
            labelOpacity = 1
            withAnimation(.easeOut(duration: 0.9)) {
                labelOffset = -baseSize * 1.1
                labelOpacity = 0
            }
        }

        // Lightning bolts — drawn for mid + mega, trigger animation.
        if tier != .standard {
            boltOpacity = 1
            boltScale = 0.7
            withAnimation(.easeOut(duration: 0.15)) {
                boltScale = 1.25
            }
            withAnimation(.easeOut(duration: 0.55).delay(0.1)) {
                boltOpacity = 0
            }
        }

        // Sound moved to the milestone "Level Up" ladder in
        // CameraWorkoutView — the visual burst stays, the synth zap is gone.
    }

    private func easeOut(_ t: Double) -> Double {
        1 - pow(1 - t, 2)
    }
}

/// Classic zig-zag lightning glyph, normalized to the host rect. Rect
/// is expected to be roughly 3×1 aspect (width ≈ line width × 3).
struct LightningBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        path.move(to:    p(0.55, 0.00))
        path.addLine(to: p(0.18, 0.45))
        path.addLine(to: p(0.48, 0.48))
        path.addLine(to: p(0.15, 0.72))
        path.addLine(to: p(0.50, 0.72))
        path.addLine(to: p(0.22, 1.00))
        return path
    }
}
