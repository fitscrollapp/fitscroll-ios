import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @State private var cameraAuthorized = false
    @State private var showError = false
    @State private var errorMessage = ""
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Text("Permissions")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("FitScroll needs these permissions to work")
                .foregroundColor(.secondary)

            Spacer()

            VStack(spacing: DS.Spacing.lg) {
                permissionCard(
                    title: Strings.Permissions.screenTimeTitle,
                    description: Strings.Permissions.screenTimeDescription,
                    icon: "hourglass",
                    isGranted: screenTimeService.isAuthorized,
                    action: requestScreenTime
                )

                permissionCard(
                    title: Strings.Permissions.cameraTitle,
                    description: Strings.Permissions.cameraDescription,
                    icon: "camera.fill",
                    isGranted: cameraAuthorized,
                    action: requestCamera
                )
            }

            Spacer()

            if screenTimeService.isAuthorized && cameraAuthorized {
                PrimaryButton(title: "Continue", action: onComplete)
            }

            if showError {
                ErrorBanner(message: errorMessage, recovery: nil)
            }
        }
        .padding(DS.Spacing.lg)
        .task {
            cameraAuthorized = CameraService.shared.isAuthorized
        }
    }

    @ViewBuilder
    private func permissionCard(title: String, description: String, icon: String, isGranted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isGranted ? DS.Colors.success : DS.Colors.primary)
                .frame(width: 44, height: 44)
                .background((isGranted ? DS.Colors.success : DS.Colors.primary).opacity(0.1))
                .cornerRadius(DS.Corner.small)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DS.Colors.success)
            } else {
                Button(Strings.Permissions.grantAccess) {
                    action()
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Corner.medium)
    }

    private func requestScreenTime() {
        Task {
            do {
                try await screenTimeService.requestAuthorization()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func requestCamera() {
        Task {
            cameraAuthorized = await CameraService.shared.requestPermission()
            if !cameraAuthorized {
                errorMessage = Strings.Errors.cameraPermissionDenied
                showError = true
            }
        }
    }
}
