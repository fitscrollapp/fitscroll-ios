import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @StateObject private var vm = LeaderboardViewModel()

    @State private var challengeOpponent: LeaderboardPlayer?
    @State private var showChallenge = false
    @State private var selectedBadge: LeaderboardBadge?
    /// Backing store for the leaderboard username; empty = not picked yet.
    @AppStorage("fitscroll.username") private var storedUsername = ""

    // Medal / tier colours
    private static let gold = Color(hexString: "FFD65C")!
    private static let goldDeep = Color(hexString: "F5A623")!
    private static let silver = Color(hexString: "C0C7D0")!
    private static let bronze = Color(hexString: "CD7F32")!

    private var entries: [RankedEntry] {
        vm.remoteEntries ?? vm.rankedEntries(sessions: sessions)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                header
                challengeCTA
                categorySelector
                periodToggle
                podium
                rankedList
                badgeShelf
            }
            .padding(DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        // First visit: pick a username before the boards are shown.
        .fullScreenCover(
            isPresented: .constant(storedUsername.isEmpty),
            content: {
                UsernameGateView { name in
                    storedUsername = name
                    Task { await vm.refresh() }
                }
            }
        )
        // (Re)fetch from the backend whenever category or period changes.
        .task(id: "\(vm.category.rawValue)|\(vm.period.rawValue)|\(storedUsername)") {
            await vm.refresh()
        }
        .sheet(item: $challengeOpponent) { player in
            ChallengeSheet(
                opponentName: player.name,
                defaultTarget: defaultTarget,
                defaultExercise: defaultExercise
            )
        }
        .sheet(isPresented: $showChallenge) {
            ChallengeSheet(defaultTarget: defaultTarget, defaultExercise: defaultExercise)
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailSheet(badge: badge, isEarned: isEarned(badge))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Leaderboard")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                Text("Compete. Climb. Conquer.")
                    .font(.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            Spacer()
            resetPill
        }
    }

    private var resetPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "hourglass")
                .font(.caption2)
            Text(vm.resetCountdown())
                .font(.caption2).fontWeight(.bold)
                .monospacedDigit()
        }
        .foregroundColor(DS.Colors.accent)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(DS.Colors.accent.opacity(0.15))
        )
        .overlay(Capsule().stroke(DS.Colors.accent.opacity(0.4), lineWidth: 1))
    }

    private var challengeCTA: some View {
        DuoButton(fill: DS.Colors.neon, foreground: DS.Colors.background, height: 58) {
            showChallenge = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "flame.fill")
                Text("Challenge a Friend")
            }
        }
    }

    // MARK: - Category selector

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(LeaderboardCategory.allCases) { cat in
                    let selected = vm.category == cat
                    Button {
                        SoundManager.click()
                        withAnimation(DS.Animation.quick) { vm.category = cat }
                    } label: {
                        HStack(spacing: 6) {
                            Text(cat.emoji)
                            Text(cat.shortTitle)
                                .fontWeight(.bold)
                        }
                        .font(.subheadline)
                        .foregroundColor(selected ? DS.Colors.background : DS.Colors.textPrimary)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            Capsule().fill(selected ? DS.Colors.neon : DS.Colors.cardBackground)
                        )
                        .overlay(
                            Capsule().stroke(DS.Colors.border, lineWidth: selected ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var periodToggle: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardPeriod.allCases) { period in
                let selected = vm.period == period
                Button {
                    SoundManager.click()
                    withAnimation(DS.Animation.quick) { vm.period = period }
                } label: {
                    Text(period.title)
                        .font(.footnote).fontWeight(.bold)
                        .foregroundColor(selected ? DS.Colors.background : DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Corner.medium, style: .continuous)
                                .fill(selected ? DS.Colors.textPrimary : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: DS.Corner.large, style: .continuous)
                .fill(DS.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.large, style: .continuous)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
    }

    // MARK: - Podium

    private var podium: some View {
        let top = Array(entries.prefix(3))
        return HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            if top.count > 1 { podiumColumn(top[1], height: 96, color: Self.silver) }
            if top.count > 0 { podiumColumn(top[0], height: 128, color: Self.gold, isFirst: true) }
            if top.count > 2 { podiumColumn(top[2], height: 72, color: Self.bronze) }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.md)
    }

    private func podiumColumn(_ entry: RankedEntry, height: CGFloat, color: Color, isFirst: Bool = false) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            if isFirst {
                Image("BadgeCrown")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(Self.gold)
            } else {
                Spacer().frame(height: 30)
            }

            AvatarCircle(player: entry.player, size: isFirst ? 68 : 56, ringColor: color)

            Text(entry.player.name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(DS.Colors.textPrimary)
                .lineLimit(1)

            Text(scoreText(entry.score))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()

            // Pedestal block
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: DS.Corner.medium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.55)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: height)
                Text("\(entry.rank)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(DS.Colors.background.opacity(0.85))
                    .padding(.top, DS.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ranked list

    private var rankedList: some View {
        let list = Array(entries.dropFirst(3))
        let total = entries.count
        let demotionRank = total - 4 // first of the last five

        return VStack(spacing: DS.Spacing.sm) {
            ForEach(list) { entry in
                if entry.rank == 6 {
                    zoneDivider(label: "PROMOTION ZONE", color: DS.Colors.neon, icon: "arrow.up.circle.fill")
                }
                if entry.rank == demotionRank && demotionRank > 6 {
                    zoneDivider(label: "DEMOTION ZONE", color: DS.Colors.error, icon: "arrow.down.circle.fill")
                }
                rankRow(entry)
            }
        }
    }

    private func rankRow(_ entry: RankedEntry) -> some View {
        let isUser = entry.player.isCurrentUser
        return Button {
            if !isUser { challengeOpponent = entry.player }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text("\(entry.rank)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.textSecondary)
                    .frame(width: 28)
                    .monospacedDigit()

                AvatarCircle(player: entry.player, size: 40, ringColor: nil)

                HStack(spacing: DS.Spacing.sm) {
                    Text(entry.player.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Colors.textPrimary)
                    if isUser {
                        Text("YOU")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(DS.Colors.background)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(DS.Colors.neon))
                    }
                }

                Spacer()

                Text(scoreText(entry.score))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(isUser ? DS.Colors.neon : DS.Colors.textPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Corner.large, style: .continuous)
                    .fill(isUser ? DS.Colors.neon.opacity(0.1) : DS.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Corner.large, style: .continuous)
                    .stroke(isUser ? DS.Colors.neon : DS.Colors.border, lineWidth: isUser ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func zoneDivider(label: String, color: Color, icon: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Rectangle().fill(color.opacity(0.4)).frame(height: 1)
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2)
                Text(label).font(.system(size: 10, weight: .black))
            }
            .foregroundColor(color)
            Rectangle().fill(color.opacity(0.4)).frame(height: 1)
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: - Badge shelf

    private var badgeShelf: some View {
        let items = vm.badges(sessions: sessions)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Your Badges")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text("\(items.filter { $0.earned }.count)/\(items.count)")
                    .font(.footnote).fontWeight(.bold)
                    .foregroundColor(DS.Colors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(items, id: \.badge.id) { item in
                        Button {
                            selectedBadge = item.badge
                        } label: {
                            VStack(spacing: DS.Spacing.xs) {
                                BadgeView(badge: item.badge, isEarned: item.earned, size: 64)
                                Text(item.badge.title)
                                    .font(.caption2).fontWeight(.semibold)
                                    .foregroundColor(item.earned ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                                    .lineLimit(1)
                                    .frame(width: 74)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }
        }
        .padding(DS.Spacing.md)
        .dsCard()
    }

    // MARK: - Helpers

    private func scoreText(_ score: Int) -> String {
        "\(score) \(vm.category.unit)"
    }

    private var stats: UserStats { vm.userStats(from: sessions) }

    private var defaultExercise: ExerciseType { vm.category.exercise }

    private var defaultTarget: Int {
        let s = stats
        switch defaultExercise {
        case .pushUp: return max(20, s.pushUps)
        case .squat: return max(20, s.squats)
        case .jumpingJacks: return max(20, s.jumpingJacks)
        case .lunge: return max(20, s.lunges)
        }
    }

    private func isEarned(_ badge: LeaderboardBadge) -> Bool {
        badge.requirement.isSatisfied(by: stats)
    }
}

// MARK: - Avatar

struct AvatarCircle: View {
    let player: LeaderboardPlayer
    var size: CGFloat = 40
    var ringColor: Color?

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [player.avatarColor, player.avatarColor.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Text(player.initials)
                .font(.system(size: size * 0.4, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().stroke(ringColor ?? Color.white.opacity(0.15), lineWidth: ringColor != nil ? 3 : 1)
        )
    }
}

// MARK: - Badge detail sheet

struct BadgeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let badge: LeaderboardBadge
    let isEarned: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Capsule().fill(DS.Colors.border).frame(width: 40, height: 5)
                .padding(.top, DS.Spacing.sm)

            Spacer()

            BadgeView(badge: badge, isEarned: isEarned, size: 120)

            VStack(spacing: DS.Spacing.sm) {
                Text(badge.title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)

                Text(isEarned ? "Earned ✓" : "Locked")
                    .font(.footnote).fontWeight(.bold)
                    .foregroundColor(isEarned ? DS.Colors.neon : DS.Colors.textSecondary)

                Text(badge.howToEarn)
                    .font(.body)
                    .foregroundColor(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
            }

            Spacer()

            DuoButton(fill: DS.Colors.neon, foreground: DS.Colors.background, height: 56) {
                dismiss()
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Got it")
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
