import SwiftUI
import UIKit

// MARK: - Challenge model (parsed from an incoming deep link)

struct ChallengeInvite: Identifiable {
    let id = UUID()
    let from: String
    let exercise: ExerciseType
    let target: Int
    /// Matching `InboxChallenge.id` — used for accept-once bookkeeping.
    var inboxID: String?

    init(from: String, exercise: ExerciseType, target: Int, inboxID: String? = nil) {
        self.from = from
        self.exercise = exercise
        self.target = target
        self.inboxID = inboxID
    }

    /// Parses the inline-parameter form
    /// `fitscroll://challenge?ex=<raw>&target=<n>&from=<name>` — the offline
    /// fallback when a backend challenge id isn't present/resolvable.
    init?(url: URL) {
        guard url.scheme == "fitscroll", url.host == "challenge",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let items = comps.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }
        guard let exRaw = value("ex"), let exercise = ExerciseType(rawValue: exRaw) else {
            return nil
        }
        self.exercise = exercise
        self.target = Int(value("target") ?? "") ?? 20
        self.from = value("from")?.replacingOccurrences(of: "+", with: " ") ?? "A friend"
    }

    /// Backend challenge id in a challenge deep link, if present:
    /// `fitscroll://challenge?id=<code>&...`
    static func backendID(in url: URL) -> String? {
        guard url.scheme == "fitscroll", url.host == "challenge",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        return comps.queryItems?.first(where: { $0.name == "id" })?.value
    }
}

// MARK: - Send a challenge (share sheet)

/// Lets the user pick an exercise + target and share a `fitscroll://challenge`
/// deep link via the system share sheet.
struct ChallengeSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Optional name of the person being challenged (pre-fills the copy).
    var opponentName: String?
    /// Best-effort default target (user's best for that exercise, else 20).
    var defaultTarget: Int = 20
    var defaultExercise: ExerciseType = .pushUp

    @State private var exercise: ExerciseType
    @State private var target: Int
    @State private var showShare = false
    @State private var isCreating = false
    /// Backend challenge code, once created — included in the shared link so
    /// the receiver's app can resolve it server-side.
    @State private var backendChallengeID: String?
    /// Friend list for direct sending (no link/WhatsApp needed).
    @State private var friends: [FitScrollAPI.Friend] = []
    @State private var selectedFriend: String?
    @State private var directSentTo: String?

    init(opponentName: String? = nil, defaultTarget: Int = 20, defaultExercise: ExerciseType = .pushUp) {
        self.opponentName = opponentName
        self.defaultTarget = defaultTarget
        self.defaultExercise = defaultExercise
        _exercise = State(initialValue: defaultExercise)
        _target = State(initialValue: max(1, defaultTarget))
    }

    private var senderName: String {
        FitScrollAPI.shared.username ?? "You"
    }

    private var shareURL: URL {
        // Preferred: https Universal Link — clickable in WhatsApp & friends,
        // opens the app directly when installed, otherwise lands on the
        // challenge web page with an App Store button.
        if let backendChallengeID,
           let url = URL(string: "https://fit-scroll.app/c/\(backendChallengeID)") {
            return url
        }
        // Offline fallback: inline-parameter custom-scheme link (not
        // clickable in most messengers, but preserves the flow).
        var comps = URLComponents()
        comps.scheme = "fitscroll"
        comps.host = "challenge"
        comps.queryItems = [
            .init(name: "ex", value: exercise.rawValue),
            .init(name: "target", value: String(target)),
            .init(name: "from", value: senderName),
        ]
        return comps.url ?? URL(string: "fitscroll://challenge")!
    }

    private var shareMessage: String {
        "🔥 I challenge you to \(target) \(exercise.displayName) on FitScroll! Tap to accept: \(shareURL.absoluteString)"
    }

    /// Register the challenge on the backend (best effort), then open the
    /// share sheet. Falls back to the inline-parameter link when offline.
    private func createAndShare() {
        guard !isCreating else { return }
        isCreating = true
        Task {
            defer {
                isCreating = false
                showShare = true
            }
            do {
                let c = try await FitScrollAPI.shared.createChallenge(
                    exercise: exercise, targetReps: target
                )
                backendChallengeID = c.id
            } catch {
                backendChallengeID = nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    header

                    if !friends.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("SEND TO")
                                .font(.caption2).fontWeight(.bold)
                                .foregroundColor(DS.Colors.textSecondary)
                            friendPicker
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("EXERCISE")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundColor(DS.Colors.textSecondary)
                        exercisePicker
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("TARGET REPS")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundColor(DS.Colors.textSecondary)
                        targetStepper
                    }

                    Spacer(minLength: DS.Spacing.md)

                    if let sentTo = directSentTo {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Sent to \(sentTo)! They'll get a notification 🔔")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.neon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                    } else {
                        DuoButton(fill: DS.Colors.neon, foreground: DS.Colors.background, height: 58) {
                            if selectedFriend != nil {
                                sendDirect()
                            } else {
                                createAndShare()
                            }
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                if isCreating {
                                    ProgressView().tint(DS.Colors.background)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text(selectedFriend.map { "Send to \($0)" } ?? "Share Challenge Link")
                            }
                        }
                        .disabled(isCreating)
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Challenge a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                ActivityView(items: [shareMessage])
            }
            .task {
                friends = (try? await FitScrollAPI.shared.friends()) ?? []
                // Pre-select when opened via "challenge this player" and the
                // player happens to be a friend.
                if let opponentName,
                   friends.contains(where: { $0.username.caseInsensitiveCompare(opponentName) == .orderedSame }) {
                    selectedFriend = opponentName
                }
            }
        }
    }

    // MARK: - Friends

    private var friendPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                friendChip(label: "🔗 Link", isSelected: selectedFriend == nil) {
                    selectedFriend = nil
                }
                ForEach(friends) { f in
                    friendChip(
                        label: f.username,
                        isSelected: selectedFriend == f.username
                    ) {
                        selectedFriend = f.username
                    }
                }
            }
        }
    }

    private func friendChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            SoundManager.click()
            action()
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? DS.Colors.background : DS.Colors.textPrimary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(isSelected ? DS.Colors.neon : DS.Colors.cardBackground))
                .overlay(Capsule().stroke(DS.Colors.border, lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    /// Directed challenge to a friend — the backend pushes them a
    /// notification, no link sharing needed.
    private func sendDirect() {
        guard let friend = selectedFriend, !isCreating else { return }
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                _ = try await FitScrollAPI.shared.createChallenge(
                    exercise: exercise, targetReps: target, toUsername: friend
                )
                directSentTo = friend
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    dismiss()
                }
            } catch {
                // Fall back to the share-link path if direct send fails.
                selectedFriend = nil
                createAndShare()
            }
        }
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(DS.Gradients.neonRing)
                    .frame(width: 76, height: 76)
                Image(systemName: "flame.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(DS.Colors.background)
            }
            Text(opponentName.map { "Challenge \($0)!" } ?? "Throw down the gauntlet")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Send a link — they tap it to accept and race you.")
                .font(.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DS.Spacing.sm)
    }

    private var exercisePicker: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(ExerciseType.allCases) { ex in
                Button {
                    exercise = ex
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: ex.iconName)
                            .font(.title3)
                            .frame(width: 28)
                        Text(ex.displayName)
                            .font(.body).fontWeight(.semibold)
                        Spacer()
                        if exercise == ex {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .foregroundColor(exercise == ex ? DS.Colors.background : DS.Colors.textPrimary)
                    .padding(DS.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Corner.medium, style: .continuous)
                            .fill(exercise == ex ? DS.Colors.neon : DS.Colors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Corner.medium, style: .continuous)
                            .stroke(DS.Colors.border, lineWidth: exercise == ex ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var targetStepper: some View {
        HStack(spacing: DS.Spacing.lg) {
            stepButton(system: "minus") { target = max(1, target - 1) }
            Text("\(target)")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(DS.Colors.neon)
                .frame(minWidth: 80)
                .monospacedDigit()
            stepButton(system: "plus") { target = min(500, target + 1) }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .dsCard()
    }

    private func stepButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.title2).fontWeight(.bold)
                .foregroundColor(DS.Colors.textPrimary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(DS.Colors.secondaryBackground))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Incoming challenge (from a tapped deep link)

struct ChallengeInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inbox = ChallengeInbox.shared
    let invite: ChallengeInvite

    @State private var startExercise: ExerciseType?
    @State private var didStartWorkout = false
    @State private var showLaterConfirm = false
    /// Challenges are strictly between two registered users — accepting
    /// without a username first routes through the username gate.
    @State private var showUsernameGate = false
    /// nil = unknown, false = not yet friends, true = friends.
    @State private var isFriend: Bool?
    @State private var isAddingFriend = false

    /// A challenge can only be accepted once — resolved live from the inbox
    /// so re-opening the same link shows the "already accepted" state.
    private var isAccepted: Bool {
        guard let id = invite.inboxID else { return false }
        return inbox.isAccepted(id)
    }

    /// You can't accept your own challenge.
    private var isOwnChallenge: Bool {
        guard let me = FitScrollAPI.shared.username else { return false }
        return me.caseInsensitiveCompare(invite.from) == .orderedSame
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.background.ignoresSafeArea()
                VStack(spacing: DS.Spacing.lg) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(DS.Gradients.neonRing)
                            .frame(width: 120, height: 120)
                            .shadow(color: DS.Colors.neon.opacity(0.5), radius: 24)
                        Image(systemName: isAccepted ? "checkmark" : "flame.fill")
                            .font(.system(size: 54, weight: .black))
                            .foregroundColor(DS.Colors.background)
                    }

                    VStack(spacing: DS.Spacing.sm) {
                        Text(isAccepted ? "Challenge Accepted" : "Challenge Received!")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(DS.Colors.neon)
                        Text("🔥 \(invite.from) challenged you to\n\(invite.target) \(invite.exercise.displayName)!")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(DS.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                        if isAccepted {
                            Text("You already accepted this one — it can't be accepted twice.")
                                .font(.subheadline)
                                .foregroundColor(DS.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DS.Spacing.lg)
                        }

                        // Befriend the sender so future challenges can go
                        // directly (no link sharing needed).
                        if !isOwnChallenge, FitScrollAPI.shared.username != nil {
                            addFriendButton
                        }
                    }

                    Spacer()

                    if isAccepted {
                        DuoButton(fill: DS.Colors.primary, foreground: .white, height: 58) {
                            dismiss()
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "house.fill")
                                Text("Back to Home")
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.xl)
                    } else if isOwnChallenge {
                        Text("This is your own challenge — share it with a friend instead 😉")
                            .font(.subheadline)
                            .foregroundColor(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                        DuoButton(fill: DS.Colors.primary, foreground: .white, height: 58) {
                            dismiss()
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "house.fill")
                                Text("Back to Home")
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.xl)
                    } else {
                        PrimaryButton(title: "Accept & Start") {
                            accept()
                        }
                        .padding(.horizontal, DS.Spacing.lg)

                        Button("Maybe later") { showLaterConfirm = true }
                            .foregroundColor(DS.Colors.textSecondary)
                            .padding(.bottom, DS.Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $startExercise) { ex in
                CameraWorkoutView(exerciseType: ex)
            }
            // The camera pops itself off after the summary is dismissed; when
            // that happens close the whole invite cover too, so the user
            // lands back on the Dashboard instead of this accept screen.
            .onChange(of: startExercise) { old, new in
                if didStartWorkout, old != nil, new == nil {
                    dismiss()
                }
            }
            .confirmationDialog(
                "Skip this challenge?",
                isPresented: $showLaterConfirm,
                titleVisibility: .visible
            ) {
                Button("Reject Challenge", role: .destructive) { reject() }
                Button("Decide Later") { dismiss() }
                Button("Keep looking at it", role: .cancel) {}
            } message: {
                Text("Reject tells \(invite.from) you passed. Decide Later keeps it waiting under the bell on the home screen.")
            }
            // Challenges are between two registered users: pick a username
            // first if the accepter doesn't have one yet.
            .sheet(isPresented: $showUsernameGate) {
                UsernameGateView { _ in
                    showUsernameGate = false
                    startAcceptedWorkout()
                }
            }
        }
    }

    // MARK: - Friend button

    @ViewBuilder
    private var addFriendButton: some View {
        Button {
            addFriend()
        } label: {
            HStack(spacing: 6) {
                if isAddingFriend {
                    ProgressView().tint(DS.Colors.neon).scaleEffect(0.8)
                } else {
                    Image(systemName: isFriend == true ? "checkmark.circle.fill" : "person.badge.plus")
                }
                Text(isFriend == true ? "Friends with \(invite.from)" : "Add \(invite.from) as friend")
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(isFriend == true ? DS.Colors.neon : DS.Colors.textPrimary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 8)
            .background(Capsule().fill(DS.Colors.cardBackground))
            .overlay(
                Capsule().stroke(
                    isFriend == true ? DS.Colors.neon.opacity(0.5) : DS.Colors.border,
                    lineWidth: 1.5
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isFriend == true || isAddingFriend)
        .padding(.top, DS.Spacing.xs)
        .task {
            // Resolve current friendship once so the button reflects reality.
            if let friends = try? await FitScrollAPI.shared.friends() {
                isFriend = friends.contains {
                    $0.username.caseInsensitiveCompare(invite.from) == .orderedSame
                }
            }
        }
    }

    private func addFriend() {
        guard !isAddingFriend else { return }
        isAddingFriend = true
        Task {
            defer { isAddingFriend = false }
            if (try? await FitScrollAPI.shared.addFriend(username: invite.from)) != nil {
                isFriend = true
                SoundManager.click()
            }
        }
    }

    // MARK: - Actions

    private func accept() {
        guard FitScrollAPI.shared.username != nil else {
            showUsernameGate = true
            return
        }
        startAcceptedWorkout()
    }

    private func startAcceptedWorkout() {
        if let id = invite.inboxID {
            inbox.markAccepted(id)
            // Record who-accepted-whom server-side (best effort; offline
            // failures don't block the workout).
            Task.detached {
                try? await FitScrollAPI.shared.respondChallenge(id: id, accept: true)
            }
        }
        didStartWorkout = true
        startExercise = invite.exercise
    }

    private func reject() {
        if let id = invite.inboxID {
            inbox.markRejected(id)
            Task.detached {
                try? await FitScrollAPI.shared.respondChallenge(id: id, accept: false)
            }
        }
        dismiss()
    }
}
