import SwiftUI

// MARK: - Bell button (Dashboard header)

/// Bell with an unread-count badge — the entry point of the in-app
/// notification center for challenges.
struct ChallengeBellButton: View {
    @ObservedObject private var inbox = ChallengeInbox.shared
    var action: () -> Void

    var body: some View {
        Button {
            SoundManager.click()
            action()
        } label: {
            ZStack(alignment: .topTrailing) {
                DuoIconBadge(systemName: "bell.fill", color: DS.Colors.secondary, size: 40)
                if inbox.unreadCount > 0 {
                    Text("\(min(inbox.unreadCount, 9))")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(DS.Colors.error))
                        .overlay(Circle().stroke(DS.Colors.background, lineWidth: 2))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification center

/// Lists received challenges (tap a pending one to accept) and the ones you
/// sent, with live accept/reject statuses from the backend.
struct ChallengeInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inbox = ChallengeInbox.shared

    /// Called when the user taps a pending received challenge.
    var onOpen: (ChallengeInvite) -> Void

    @State private var sent: [FitScrollAPI.Challenge] = []
    @State private var sentLoaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    receivedSection
                    sentSection
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if let mine = try? await FitScrollAPI.shared.myChallenges() {
                    sent = mine.sent
                    // Directed (friend-to-friend) challenges land server-side
                    // first — fold them into the local inbox.
                    inbox.syncRemote(received: mine.received)
                }
                sentLoaded = true
                inbox.markAllRead()
            }
        }
    }

    // MARK: - Received

    private var receivedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Challenges for You")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(DS.Colors.textPrimary)

            if inbox.items.isEmpty {
                emptyCard(
                    icon: "bell.slash.fill",
                    text: "No challenges yet. Share one from the Leaderboard!"
                )
            } else {
                ForEach(inbox.items) { item in
                    receivedRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private func receivedRow(_ item: InboxChallenge) -> some View {
        let exercise = item.exercise ?? .pushUp
        Button {
            guard item.status == .pending else { return }
            onOpen(ChallengeInvite(
                from: item.from,
                exercise: exercise,
                target: item.target,
                inboxID: item.id
            ))
        } label: {
            HStack(spacing: DS.Spacing.md) {
                avatar(name: item.from)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.from) challenged you")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.textPrimary)
                    Text("\(item.target) \(exercise.displayName) · \(TimeFormatter.relativeDate(item.receivedAt))")
                        .font(.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                Spacer()

                statusChip(for: item.status)
            }
            .padding(DS.Spacing.md)
            .dsCard(cornerRadius: DS.Corner.large)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sent

    private var sentSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Sent by You")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(DS.Colors.textPrimary)

            if !sentLoaded {
                HStack {
                    Spacer()
                    ProgressView().tint(DS.Colors.neon)
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.lg)
            } else if sent.isEmpty {
                emptyCard(
                    icon: "paperplane.fill",
                    text: "You haven't sent any challenges yet."
                )
            } else {
                ForEach(sent, id: \.id) { c in
                    sentRow(c)
                }
            }
        }
    }

    @ViewBuilder
    private func sentRow(_ c: FitScrollAPI.Challenge) -> some View {
        let exercise = ExerciseType(rawValue: c.exercise)
        HStack(spacing: DS.Spacing.md) {
            DuoIconBadge(
                systemName: exercise.map { $0.iconName } ?? "flame.fill",
                color: exercise.map { Duo.color(for: $0) } ?? DS.Colors.neon,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(c.targetReps) \(exercise?.displayName ?? c.exercise)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                Text(subtitleForSent(c))
                    .font(.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            statusChip(for: InboxChallenge.Status(rawValue: c.status ?? "pending") ?? .pending)
        }
        .padding(DS.Spacing.md)
        .dsCard(cornerRadius: DS.Corner.large)
    }

    private func subtitleForSent(_ c: FitScrollAPI.Challenge) -> String {
        switch c.status {
        case "accepted": return "Accepted by \(c.toUsername ?? "someone") 💪"
        case "rejected": return "Rejected by \(c.toUsername ?? "someone")"
        default: return "Waiting for a response…"
        }
    }

    // MARK: - Pieces

    private func statusChip(for status: InboxChallenge.Status) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .pending: return ("NEW", DS.Colors.accent)
            case .accepted: return ("✓ Accepted", DS.Colors.neon)
            case .rejected: return ("Rejected", DS.Colors.error)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
    }

    private func avatar(name: String) -> some View {
        var hash = 5381
        for scalar in name.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        let hue = Double(abs(hash) % 360) / 360.0
        return ZStack {
            Circle().fill(Color(hue: hue, saturation: 0.62, brightness: 0.92))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 44)
    }

    private func emptyCard(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(DS.Colors.textSecondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .dsCard(cornerRadius: DS.Corner.large)
    }
}
