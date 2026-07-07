import SwiftUI

/// Animated launch splash: the app logo drops in from above like a rock,
/// SLAMS into place (thud sound + heavy haptic + squash-and-shake), then the
/// wordmark pops up and the whole thing fades into the app (~1.8s).
struct SplashView: View {
    var onFinished: () -> Void

    /// Logo's vertical offset — starts far above the screen, falls to 0.
    @State private var dropOffset: CGFloat = -720
    @State private var squashX: CGFloat = 1.0
    @State private var squashY: CGFloat = 1.0
    /// Horizontal jitter applied to everything on impact ("the ground shook").
    @State private var shake: CGFloat = 0
    @State private var glow: Double = 0.1
    @State private var titleOffset: CGFloat = 18
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: DS.Colors.neon.opacity(glow), radius: 36)
                    // Squash anchored at the bottom so the logo flattens
                    // against the "ground" on impact.
                    .scaleEffect(x: squashX, y: squashY, anchor: .bottom)
                    .offset(y: dropOffset)

                VStack(spacing: 4) {
                    Text("FitScroll")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(DS.Colors.textPrimary)
                    Text("Move to Unlock")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.neon)
                }
                .offset(y: titleOffset)
                .opacity(titleOpacity)
            }
            .offset(x: shake)
        }
        .onAppear(perform: run)
    }

    private func run() {
        // Warm the sound engine off-main so the thud plays with zero lag at
        // the moment of impact (first-touch init loads ~19 audio files).
        DispatchQueue.global(qos: .userInitiated).async {
            _ = SoundManager.shared
        }

        // Free fall — easeIn reads as gravity. The impact is chained to the
        // ANIMATION's completion (not a wall-clock timer), so a busy launch
        // main thread can't open a gap between landing and the slam.
        withAnimation(.easeIn(duration: 0.5), completionCriteria: .logicallyComplete) {
            dropOffset = 0
        } completion: {
            impact()
        }
    }

    /// 💥 The slam: thud + heavy haptic + squash + ground shake, then the
    /// wordmark pops up and we hand off to the app.
    private func impact() {
        SoundManager.splashImpact()
        HapticManager.heavy()

        // Squash flat against the ground…
        withAnimation(.spring(response: 0.16, dampingFraction: 0.5)) {
            squashX = 1.28
            squashY = 0.72
        }
        // …while the ground shakes…
        withAnimation(.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true)) {
            shake = 7
        }
        withAnimation(.easeOut(duration: 0.9)) {
            glow = 0.75
        }

        // …then spring back to shape.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                squashX = 1.0
                squashY = 1.0
            }
            withAnimation(.easeOut(duration: 0.08)) {
                shake = 0
            }
        }

        // Wordmark pops up out of the dust.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.18)) {
            titleOffset = 0
            titleOpacity = 1
        }

        // Hand off to the app (relative to the impact, so delays never stack).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            onFinished()
        }
    }
}
