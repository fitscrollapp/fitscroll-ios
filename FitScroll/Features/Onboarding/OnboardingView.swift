import SwiftUI
import SwiftData
import AVFoundation
import FamilyControls

/// Five-stage onboarding flow:
///   1. Hook           — animated character + value prop
///   2. Transformation — before / after comparison
///   3. Privacy        — framing for the two system permissions
///   4. Screen Time    — triggers Apple authorization popup
///   5. Camera         — triggers Apple authorization popup
/// Progress bar + Back/Continue buttons visible on every stage.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var screenTimeService: ScreenTimeService

    private enum Stage: Int, CaseIterable {
        case hook
        case transformation
        case privacy
        case screenTime
        case camera
    }

    @State private var stage: Stage = .hook
    @State private var animatedProgress: Double = 0
    @State private var screenTimeGranted = false
    @State private var cameraGranted = false
    @State private var isRequestingPermission = false

    var body: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

            stageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )

            bottomControls
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .onAppear { updateProgress() }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Stage.allCases, id: \.self) { s in
                Capsule()
                    .fill(
                        s.rawValue <= stage.rawValue
                        ? DS.Colors.primary
                        : DS.Colors.primary.opacity(0.15)
                    )
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Stage content

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .hook:           HookStage()
        case .transformation: TransformationStage()
        case .privacy:        PrivacyStage()
        case .screenTime:
            ScreenTimeStageView(
                isRequesting: $isRequestingPermission,
                granted: $screenTimeGranted
            )
            .environmentObject(screenTimeService)
        case .camera:
            CameraStageView(
                isRequesting: $isRequestingPermission,
                granted: $cameraGranted
            )
        }
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: DS.Spacing.sm) {
            PrimaryButton(
                title: primaryButtonTitle,
                action: advance,
                isLoading: isRequestingPermission
            )

            if stage != .hook {
                Button(backButtonTitle, action: back)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // Preserve bottom space so the layout doesn't jump.
                Color.clear.frame(height: 20)
            }
        }
    }

    private var primaryButtonTitle: String {
        switch stage {
        case .hook, .transformation, .privacy: return Strings.Onboarding.continue
        case .screenTime:
            return screenTimeGranted ? Strings.Onboarding.continue : Strings.Onboarding.ScreenTimeStage.cta
        case .camera:
            return cameraGranted ? Strings.Onboarding.finish : Strings.Onboarding.CameraStage.cta
        }
    }

    private var backButtonTitle: String {
        switch stage {
        case .screenTime, .camera: return Strings.Onboarding.ScreenTimeStage.later
        default: return Strings.Onboarding.back
        }
    }

    // MARK: - Navigation

    private func advance() {
        switch stage {
        case .hook, .transformation, .privacy:
            goForward()
        case .screenTime:
            if screenTimeGranted {
                goForward()
            } else {
                Task { await requestScreenTime() }
            }
        case .camera:
            if cameraGranted {
                finishOnboarding()
            } else {
                Task { await requestCamera() }
            }
        }
    }

    private func back() {
        switch stage {
        case .hook:
            return
        case .screenTime, .camera:
            // "I'll do this later" simply skips this stage.
            if stage == .camera {
                finishOnboarding()
            } else {
                goForward()
            }
        default:
            goBackward()
        }
    }

    private func goForward() {
        guard let next = Stage(rawValue: stage.rawValue + 1) else {
            finishOnboarding()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            stage = next
            updateProgress()
        }
    }

    private func goBackward() {
        guard let prev = Stage(rawValue: stage.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            stage = prev
            updateProgress()
        }
    }

    private func updateProgress() {
        animatedProgress = Double(stage.rawValue + 1) / Double(Stage.allCases.count)
    }

    // MARK: - Permission requests

    private func requestScreenTime() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            screenTimeGranted = true
        } catch {
            // User denied — still allow them to proceed; real picker will retry later.
            screenTimeGranted = false
        }

        // Whether granted or not, move on so the user is not stuck.
        goForward()
    }

    private func requestCamera() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            cameraGranted = true
        } else if status == .notDetermined {
            cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            cameraGranted = false
        }

        finishOnboarding()
    }

    // MARK: - Completion

    private func finishOnboarding() {
        // Persist user settings + default reward rules on first completion.
        let existingSettings = try? modelContext.fetch(FetchDescriptor<UserSettings>())
        if existingSettings?.isEmpty ?? true {
            let settings = UserSettings(hasCompletedOnboarding: true)
            modelContext.insert(settings)

            for exercise in ExerciseType.allCases {
                modelContext.insert(ExerciseRewardRule(exerciseType: exercise))
            }
            modelContext.insert(UsageLimitRule())
        } else if let existing = existingSettings?.first {
            existing.hasCompletedOnboarding = true
            existing.updatedAt = Date()
        }

        try? modelContext.save()
    }
}

// MARK: - Stage 1: Hook

private struct HookStage: View {
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            AnimatedExerciseIcon(exerciseType: .pushUp, characterStyle: .woman, cycleDuration: 1.8)
                .frame(width: 200, height: 280)

            Text(Strings.Onboarding.Hook.title)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(Strings.Onboarding.Hook.subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)

            Spacer()
        }
    }
}

// MARK: - Stage 2: Before / After transformation

private struct TransformationStage: View {
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer(minLength: DS.Spacing.lg)

            Text(Strings.Onboarding.Transform.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)

            HStack(alignment: .top, spacing: DS.Spacing.md) {
                TransformColumn(
                    title: Strings.Onboarding.Transform.before,
                    tint: DS.Colors.error,
                    icon: "xmark.circle.fill",
                    items: [
                        Strings.Onboarding.Transform.before1,
                        Strings.Onboarding.Transform.before2,
                        Strings.Onboarding.Transform.before3,
                    ]
                )
                TransformColumn(
                    title: Strings.Onboarding.Transform.after,
                    tint: DS.Colors.success,
                    icon: "checkmark.circle.fill",
                    items: [
                        Strings.Onboarding.Transform.after1,
                        Strings.Onboarding.Transform.after2,
                        Strings.Onboarding.Transform.after3,
                    ]
                )
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer()
        }
    }
}

private struct TransformColumn: View {
    let title: String
    let tint: Color
    let icon: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(tint)
                .textCase(.uppercase)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: icon)
                        .foregroundColor(tint)
                        .font(.subheadline)
                    Text(item)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(tint.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.medium)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(DS.Corner.medium)
    }
}

// MARK: - Stage 3: Privacy framing

private struct PrivacyStage: View {
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer(minLength: DS.Spacing.lg)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundColor(DS.Colors.primary)

            Text(Strings.Onboarding.Privacy.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(Strings.Onboarding.Privacy.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.md) {
                PrivacyCard(
                    icon: "hourglass",
                    tint: DS.Colors.primary,
                    title: Strings.Onboarding.Privacy.screenTimeTitle,
                    message: Strings.Onboarding.Privacy.screenTimeBody
                )
                PrivacyCard(
                    icon: "camera.fill",
                    tint: DS.Colors.accent,
                    title: Strings.Onboarding.Privacy.cameraTitle,
                    message: Strings.Onboarding.Privacy.cameraBody
                )
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)

            Spacer()
        }
    }
}

private struct PrivacyCard: View {
    let icon: String
    let tint: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(tint)
                .cornerRadius(DS.Corner.small)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Corner.medium)
    }
}

// MARK: - Stage 4: Screen Time permission

private struct ScreenTimeStageView: View {
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @Binding var isRequesting: Bool
    @Binding var granted: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            Image(systemName: granted ? "checkmark.shield.fill" : "hourglass")
                .font(.system(size: 72))
                .foregroundColor(granted ? DS.Colors.success : DS.Colors.primary)

            Text(Strings.Onboarding.ScreenTimeStage.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(Strings.Onboarding.ScreenTimeStage.body)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)

            Spacer()
        }
    }
}

// MARK: - Stage 5: Camera permission

private struct CameraStageView: View {
    @Binding var isRequesting: Bool
    @Binding var granted: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            Image(systemName: granted ? "checkmark.circle.fill" : "camera.fill")
                .font(.system(size: 72))
                .foregroundColor(granted ? DS.Colors.success : DS.Colors.accent)

            Text(Strings.Onboarding.CameraStage.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(Strings.Onboarding.CameraStage.body)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)

            Spacer()
        }
    }
}
