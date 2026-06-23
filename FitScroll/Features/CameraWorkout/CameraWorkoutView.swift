import SwiftUI
import SwiftData
import AVFoundation
import UIKit

struct CameraWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @StateObject private var coordinator: WorkoutSessionCoordinator
    @Query private var settings: [UserSettings]
    @State private var showSummary = false
    @State private var completedSession: WorkoutSession?
    @State private var debugStatus: String = "init"
    @State private var counterPulse: CGFloat = 1.0
    @State private var counterIsWin: Bool = false
    @State private var showExitConfirm: Bool = false

    let exerciseType: ExerciseType

    init(exerciseType: ExerciseType) {
        self.exerciseType = exerciseType
        _coordinator = StateObject(wrappedValue: WorkoutSessionCoordinator(exerciseType: exerciseType))
    }

    var body: some View {
        ZStack {
            // Camera preview
            cameraPreview

            // Pose skeleton overlay
            PoseOverlayView(frame: coordinator.repCounter.currentFrame)
                .ignoresSafeArea()

            // Overlay
            VStack {
                topBar

                // Compact rep + character pill (top-right, matching design)
                HStack {
                    Spacer()
                    repCharacterPill
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)

                Spacer()

                if case .failed(let message) = coordinator.state {
                    failedStateView(message: message)
                } else {
                    if !coordinator.poseFeedback.isEmpty {
                        feedbackBanner
                    }
                    circularRepCounter
                    controlButtons
                }
            }

        }
        .ignoresSafeArea()
        // Hide the system navigation bar AND its back button so the only
        // way out of the workout is the on-screen X (which goes through
        // the confirmation dialog). Also disables the swipe-back gesture.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await coordinator.start()
        }
        .fullScreenCover(isPresented: $showSummary) {
            if let session = completedSession {
                SessionSummaryView(session: session) {
                    // After the summary is dismissed, also pop the camera
                    // view so the user lands back on the unlock session list
                    // (or the dashboard) instead of being stuck on the last
                    // camera frame.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog(
            "Quit this workout?",
            isPresented: $showExitConfirm,
            titleVisibility: .visible
        ) {
            Button("Quit & Discard", role: .destructive) {
                Task {
                    let session = await coordinator.cancel()
                    modelContext.insert(session)
                    try? modelContext.save()
                    dismiss()
                }
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Your reps so far won't be saved and the camera will stop.")
        }
        .onChange(of: coordinator.repCounter.acceptedReps) { oldValue, newValue in
            guard newValue > oldValue else { return }
            if settings.first?.hapticFeedbackEnabled ?? true {
                HapticManager.repCompleted()
            }
            SoundManager.repEarned()
            // Pulse effect: grow big + turn green, then shrink + back to orange
            withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
                counterPulse = 1.7
                counterIsWin = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    counterPulse = 1.0
                    counterIsWin = false
                }
            }
        }
    }

    @ViewBuilder
    private var cameraPreview: some View {
        if let visionProvider = coordinator.visionPoseProvider {
            CameraPreviewRepresentable(session: visionProvider.captureSessionForPreview)
                .ignoresSafeArea()
        } else {
            Color.black.ignoresSafeArea()
            VStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.5))
                Text("Simulator Mode")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                showExitConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(DS.Spacing.sm)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            Text(TimeFormatter.formatDuration(seconds: coordinator.elapsedSeconds))
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(.ultraThinMaterial)
                .cornerRadius(DS.Corner.small)

            Spacer()

            Text(exerciseType.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(.ultraThinMaterial)
                .cornerRadius(DS.Corner.small)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.xxl + DS.Spacing.lg)
    }

    /// Interpolation factor [0, 1] based on how far the user is from "up" (0)
    /// toward "down" (1) — derived from the detected joint angle.
    private var motionProgress: Double {
        let t = ExerciseThresholds.thresholds(for: exerciseType)
        let angle = coordinator.repCounter.currentAngle
        let range = t.upAngle - t.downAngle
        guard range > 0 else { return 0 }
        let raw = (t.upAngle - angle) / range
        return max(0, min(1, raw))
    }

    private var repCharacterPill: some View {
        WorkoutCharacterView(
            exerciseType: exerciseType,
            progress: motionProgress,
            style: settings.first?.characterStyle ?? .woman
        )
        .frame(width: 90, height: 140)
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial)
        .cornerRadius(DS.Corner.large)
    }

    private var counterGradientColors: [Color] {
        if counterIsWin {
            return [
                Color(red: 0.25, green: 0.95, blue: 0.45),
                Color(red: 0.10, green: 0.75, blue: 0.30)
            ]
        } else {
            return [
                Color(red: 1.0, green: 0.75, blue: 0.15),
                Color(red: 0.95, green: 0.55, blue: 0.10)
            ]
        }
    }

    private var counterShadowColor: Color {
        counterIsWin ? Color.green.opacity(0.8) : Color.orange.opacity(0.6)
    }

    private var circularRepCounter: some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack {
                // Electric + ember burst sits behind the counter; it's
                // triggered by each new rep via onChange inside the view
                // itself.
                RepBurstEffect(
                    repCount: coordinator.repCounter.acceptedReps,
                    baseSize: 96
                )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: counterGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: counterShadowColor, radius: 24)

                Circle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 3)
                    .frame(width: 96, height: 96)

                Text("\(coordinator.repCounter.acceptedReps)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(value: Double(coordinator.repCounter.acceptedReps)))
            }
            .scaleEffect(counterPulse)

            // Live "earned minutes" pill so the user sees the conversion as
            // reps land. Uses the same minutes-per-rep rule the session
            // coordinator applies on finish.
            let earned = Double(coordinator.repCounter.acceptedReps)
                * exerciseType.defaultMinutesPerRep
            Text("+\(formattedEarned(earned)) min earned")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DS.Colors.accent)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(DS.Corner.large)
        }
        .padding(.bottom, DS.Spacing.md)
    }

    private func formattedEarned(_ minutes: Double) -> String {
        if minutes == minutes.rounded() {
            return String(Int(minutes))
        }
        return String(format: "%.1f", minutes)
    }

    private var feedbackBanner: some View {
        Text(coordinator.poseFeedback)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(DS.Spacing.md)
            .background(DS.Colors.warning.opacity(0.8))
            .cornerRadius(DS.Corner.medium)
            .padding(.horizontal, DS.Spacing.lg)
    }

    private var controlButtons: some View {
        HStack(spacing: DS.Spacing.xl) {
            switch coordinator.state {
            case .preparing:
                Text(Strings.Workout.preparing)
                    .foregroundColor(.white)
            case .active:
                Button {
                    coordinator.pause()
                } label: {
                    controlButton(title: Strings.Workout.pause, icon: "pause.fill", color: DS.Colors.warning)
                }

                Button {
                    Task { await finishWorkout() }
                } label: {
                    controlButton(title: Strings.Workout.finish, icon: "stop.fill", color: DS.Colors.success)
                }
            case .paused:
                Button {
                    coordinator.resume()
                } label: {
                    controlButton(title: Strings.Workout.resume, icon: "play.fill", color: DS.Colors.primary)
                }

                Button {
                    Task { await finishWorkout() }
                } label: {
                    controlButton(title: Strings.Workout.finish, icon: "stop.fill", color: DS.Colors.success)
                }
            default:
                EmptyView()
            }
        }
        .padding(.bottom, DS.Spacing.xxl)
    }

    @ViewBuilder
    private func controlButton(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(1.0), color.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 78, height: 78)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 3)
                    )
                    .shadow(color: color.opacity(0.55), radius: 14, y: 4)

                Image(systemName: icon)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 3)
        }
    }

    private func statusString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }

    private var coordinatorStateString: String {
        switch coordinator.state {
        case .idle: return "idle"
        case .preparing: return "preparing"
        case .active: return "active"
        case .paused: return "paused"
        case .finished: return "finished"
        case .failed(let msg): return "failed: \(msg)"
        }
    }

    @ViewBuilder
    private func failedStateView(message: String) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(DS.Colors.warning)
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(DS.Corner.medium)
            Button("Close") {
                dismiss()
            }
            .foregroundColor(.white.opacity(0.8))
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial)
        .cornerRadius(DS.Corner.large)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xxl)
    }

    private func finishWorkout() async {
        let session = await coordinator.finish()
        modelContext.insert(session)

        let credit = UnlockCredit(
            earnedMinutes: session.earnedMinutes,
            sourceSessionId: session.id
        )
        modelContext.insert(credit)

        try? modelContext.save()

        HapticManager.sessionCompleted()
        completedSession = session
        showSummary = true
    }
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get { previewLayer.session }
        set {
            previewLayer.session = newValue
            previewLayer.videoGravity = .resizeAspectFill
        }
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if uiView.session !== session {
            uiView.session = session
        }
    }
}
