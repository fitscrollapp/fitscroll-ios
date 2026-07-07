import Foundation
import SwiftUI

// MARK: - Inbox item

/// A received challenge, persisted locally so the bell/notification center
/// can list it and so an accepted challenge can never be accepted twice.
struct InboxChallenge: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case pending
        case accepted
        case rejected
    }

    /// Backend challenge code when available, otherwise a generated UUID
    /// (offline inline-parameter links carry no code).
    let id: String
    let from: String
    let exerciseRaw: String
    let target: Int
    let receivedAt: Date
    var status: Status
    var isRead: Bool

    var exercise: ExerciseType? { ExerciseType(rawValue: exerciseRaw) }
}

// MARK: - Store

/// UserDefaults-backed store for received challenges. Single source of truth
/// for the bell badge, the notification list, and accept-once semantics.
@MainActor
final class ChallengeInbox: ObservableObject {
    static let shared = ChallengeInbox()

    @Published private(set) var items: [InboxChallenge] = [] {
        didSet { persist() }
    }

    private static let storageKey = "fitscroll.challenge.inbox"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([InboxChallenge].self, from: data) {
            items = decoded
        }
    }

    var unreadCount: Int { items.filter { !$0.isRead }.count }
    var pendingCount: Int { items.filter { $0.status == .pending }.count }

    /// Record an incoming challenge. Same backend code twice → returns the
    /// existing entry (so a re-tapped link can't duplicate or re-accept).
    @discardableResult
    func add(code: String?, from: String, exercise: ExerciseType, target: Int) -> InboxChallenge {
        if let code, let existing = items.first(where: { $0.id == code }) {
            return existing
        }
        let item = InboxChallenge(
            id: code ?? UUID().uuidString,
            from: from,
            exerciseRaw: exercise.rawValue,
            target: target,
            receivedAt: Date(),
            status: .pending,
            isRead: false
        )
        items.insert(item, at: 0)
        return item
    }

    func isAccepted(_ id: String) -> Bool {
        items.first(where: { $0.id == id })?.status == .accepted
    }

    func markAccepted(_ id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].status = .accepted
        items[idx].isRead = true
    }

    func markRejected(_ id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].status = .rejected
        items[idx].isRead = true
    }

    func markAllRead() {
        guard items.contains(where: { !$0.isRead }) else { return }
        for idx in items.indices { items[idx].isRead = true }
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
    }

    /// Merge challenges the backend says were directed at me (friend →
    /// friend sends arrive server-side first, possibly via push while the
    /// app was closed). Keeps local statuses in sync with the server's.
    func syncRemote(received: [FitScrollAPI.Challenge]) {
        for c in received {
            guard let exercise = ExerciseType(rawValue: c.exercise) else { continue }
            if let idx = items.firstIndex(where: { $0.id == c.id }) {
                // Server status wins for accepted/rejected.
                if c.status == "accepted" { items[idx].status = .accepted }
                if c.status == "rejected" { items[idx].status = .rejected }
            } else {
                var item = InboxChallenge(
                    id: c.id,
                    from: c.fromUsername,
                    exerciseRaw: exercise.rawValue,
                    target: c.targetReps,
                    receivedAt: Date(),
                    status: .pending,
                    isRead: false
                )
                if c.status == "accepted" { item.status = .accepted; item.isRead = true }
                if c.status == "rejected" { item.status = .rejected; item.isRead = true }
                items.insert(item, at: 0)
            }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
