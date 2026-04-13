import SwiftUI

/// Small icon that continuously loops between an exercise's "up" and "down"
/// illustrations, using the character style (woman/man) from user settings.
///
/// Uses TimelineView to drive opacity from the clock so there is no
/// SwiftUI state animation — surrounding layout stays completely still.
struct AnimatedExerciseIcon: View {
    let exerciseType: ExerciseType
    var characterStyle: CharacterStyle = .woman
    /// Full cycle duration — one up→down→up round trip.
    var cycleDuration: Double = 1.6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = smoothProgress(at: context.date)
            ZStack {
                Image(characterStyle.upImageName(for: exerciseType))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(1 - t)

                Image(characterStyle.downImageName(for: exerciseType))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(t)
            }
        }
    }

    /// Smooth 0↔1↔0 cycle driven by the current time.
    private func smoothProgress(at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate
        let phase = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        return (1 - cos(phase * 2 * .pi)) / 2
    }
}

#Preview {
    HStack(spacing: 30) {
        VStack {
            AnimatedExerciseIcon(exerciseType: .pushUp, characterStyle: .woman)
                .frame(width: 80, height: 80)
            Text("Push-up · Woman")
        }
        VStack {
            AnimatedExerciseIcon(exerciseType: .squat, characterStyle: .man)
                .frame(width: 80, height: 80)
            Text("Squat · Man")
        }
    }
    .padding()
}
