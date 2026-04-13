import SwiftUI

/// Cross-fades between the "up" and "down" illustrations of the selected
/// character style based on motion progress.
struct WorkoutCharacterView: View {
    let exerciseType: ExerciseType
    /// 0 = fully up position, 1 = fully down position.
    var progress: Double
    /// Character illustration style (male/female).
    var style: CharacterStyle = .woman

    var body: some View {
        let p = max(0, min(1, progress))
        return ZStack {
            Image(style.upImageName(for: exerciseType))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(1 - p)
            Image(style.downImageName(for: exerciseType))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(p)
        }
        .animation(.easeInOut(duration: 0.15), value: p)
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
