import Foundation
import Combine
import AVFoundation

@MainActor
final class WorkoutSessionCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case active
        case paused
        case finished
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var repCounter: ExerciseRepCounter
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published var poseFeedback: String = ""

    private var poseProvider: PoseProvider
    private let exerciseType: ExerciseType
    private var timerTask: Task<Void, Never>?

    init(exerciseType: ExerciseType, poseProvider: PoseProvider? = nil) {
        self.exerciseType = exerciseType
        self.repCounter = ExerciseRepCounter(exerciseType: exerciseType)

        if let provider = poseProvider {
            self.poseProvider = provider
        } else {
            #if targetEnvironment(simulator)
            self.poseProvider = MockPoseProvider(exerciseType: exerciseType)
            #else
            let visionProvider = VisionPoseProvider()
            // Push-ups place the user inches from the lens; widen the camera
            // field of view for that exercise only so hips/knees/ankles stay
            // in frame. Squats use the default (it works fine and a wider
            // format degrades joint detection for upright poses).
            visionProvider.preferWideFieldOfView = (exerciseType == .pushUp)
            self.poseProvider = visionProvider
            #endif
        }
    }

    func start() async {
        state = .preparing

        // Check camera permission first for real device
        #if !targetEnvironment(simulator)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                state = .failed("Camera permission denied. Enable in Settings > FitScroll.")
                return
            }
        } else if status == .denied || status == .restricted {
            state = .failed("Camera access denied. Enable in Settings > FitScroll.")
            return
        }
        #endif

        poseProvider.onPoseFrame = { [weak self] frame in
            Task { @MainActor in
                guard let self, self.state == .active else { return }
                self.repCounter.processFrame(frame)
                self.updatePoseFeedback(frame)
            }
        }

        await poseProvider.startProviding()
        state = .active
        startTimer()
    }

    func pause() {
        state = .paused
        timerTask?.cancel()
    }

    func resume() {
        state = .active
        startTimer()
    }

    func finish() async -> WorkoutSession {
        state = .finished
        timerTask?.cancel()
        await poseProvider.stopProviding()

        let session = WorkoutSession(
            exerciseType: exerciseType,
            repCount: repCounter.acceptedReps,
            earnedMinutes: calculateEarnedMinutes(),
            averageConfidence: repCounter.averageConfidence,
            finishedAt: Date(),
            status: .completed
        )

        return session
    }

    func cancel() async -> WorkoutSession {
        state = .finished
        timerTask?.cancel()
        await poseProvider.stopProviding()

        return WorkoutSession(
            exerciseType: exerciseType,
            repCount: repCounter.acceptedReps,
            earnedMinutes: calculateEarnedMinutes(),
            averageConfidence: repCounter.averageConfidence,
            finishedAt: Date(),
            status: .cancelled
        )
    }

    var visionPoseProvider: VisionPoseProvider? {
        poseProvider as? VisionPoseProvider
    }

    private func calculateEarnedMinutes() -> Double {
        Double(repCounter.acceptedReps) * exerciseType.defaultMinutesPerRep
    }

    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled && state == .active {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if state == .active {
                    elapsedSeconds += 1
                }
            }
        }
    }

    private func updatePoseFeedback(_ frame: PoseFrame) {
        // Push-ups happen with the user close to the camera, so the lower
        // body falls outside the frame — this drags the average frame
        // confidence down even when the upper body is detected fine.
        // Use a relaxed threshold for push-ups so we don't constantly
        // flash a "low light" warning during a perfectly valid rep.
        let lowConfidenceThreshold: Float = exerciseType == .pushUp ? 0.25 : 0.5

        if !frame.isValid {
            poseFeedback = Strings.Workout.adjustPosition
        } else if frame.confidence < lowConfidenceThreshold {
            poseFeedback = Strings.Workout.moveBetterLight
        } else {
            poseFeedback = ""
        }
    }
}
