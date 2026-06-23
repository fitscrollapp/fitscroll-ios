import SwiftUI

/// Cross-fades between the "up" and "down" illustrations of the selected
/// character style based on motion progress.
struct WorkoutCharacterView: View {
    let exerciseType: ExerciseType
    /// 0 = fully up position, 1 = fully down position.
    var progress: Double
    /// Character illustration style (male/female).
    var style: CharacterStyle = .woman

    /// Temporally smoothed copy of `progress` driven by a 30 Hz timer.
    /// Raw joint angles snap back much faster on the way up than they
    /// decay on the way down — a plain `withAnimation(...)` keeps
    /// getting interrupted by each new frame, so we instead run our
    /// own first-order low-pass filter with a fixed time constant.
    /// This gives identical smoothing in both directions regardless
    /// of how quickly the source value changes.
    @State private var displayedProgress: Double = 0

    /// ~30 Hz timer, matches the pose provider's frame cadence.
    private let tick = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Image(style.upImageName(for: exerciseType))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(1 - displayedProgress)
            Image(style.downImageName(for: exerciseType))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(displayedProgress)
        }
        .onAppear {
            displayedProgress = max(0, min(1, progress))
        }
        .onReceive(tick) { _ in
            let target = max(0, min(1, progress))
            let delta = target - displayedProgress
            // Pull ~12% of the way to target each tick. With a 30 Hz
            // cadence this lands ~90% of the remaining distance in
            // about 0.6 s — slow enough to read, fast enough not to
            // feel laggy.
            displayedProgress += delta * 0.12
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(CharacterStyle.allCases) { style in
            HStack(spacing: 20) {
                VStack {
                    WorkoutCharacterView(exerciseType: .pushUp, progress: 0, style: style)
                        .frame(width: 90, height: 140)
                    Text("\(style.rawValue) UP").font(.caption)
                }
                VStack {
                    WorkoutCharacterView(exerciseType: .pushUp, progress: 1, style: style)
                        .frame(width: 90, height: 140)
                    Text("\(style.rawValue) DOWN").font(.caption)
                }
            }
        }
    }
    .padding()
    .background(Color.black)
    .foregroundColor(.white)
}
