import Foundation
import CryptoKit
import DeviceCheck
import UIKit

/// Thin client for the FitScroll backend (leaderboard + challenges).
///
/// Identity model mirrors the OriensBlocks backend: no login. The device
/// identifies itself with a stable hashed device id (`X-Device-Id`); on real
/// devices an App Attest key is enrolled once and score submissions carry a
/// per-request assertion (`X-App-Attest-Assertion`) the server verifies
/// against the enrolled public key. Simulators / attest failures fall back to
/// plain device-id auth, which the backend accepts.
final class FitScrollAPI {
    static let shared = FitScrollAPI()

    // MARK: - Config

    /// Production API. DEBUG builds can override with the
    /// `FITSCROLL_API_URL` environment variable (used by Maestro tests
    /// against a locally running backend).
    private var baseURL: URL {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["FITSCROLL_API_URL"],
           let url = URL(string: raw) {
            return url
        }
        #endif
        return URL(string: "https://api.fit-scroll.app")!
    }

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        return URLSession(configuration: cfg)
    }()

    // MARK: - Identity

    /// Stable per-install device id (sha256 hex). Persisted so it survives
    /// identifierForVendor rotation edge cases.
    var deviceID: String {
        let key = "fitscroll.api.deviceid"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let seed = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let hashed = SHA256.hash(data: Data(seed.utf8))
            .map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hashed, forKey: key)
        return hashed
    }

    private var attestKeyID: String? {
        get { UserDefaults.standard.string(forKey: "fitscroll.api.attestkeyid") }
        set { UserDefaults.standard.set(newValue, forKey: "fitscroll.api.attestkeyid") }
    }

    var username: String? {
        get {
            let v = UserDefaults.standard.string(forKey: "fitscroll.username")
            return (v?.isEmpty ?? true) ? nil : v
        }
        set { UserDefaults.standard.set(newValue, forKey: "fitscroll.username") }
    }

    // MARK: - Models

    struct User: Decodable {
        let id: String
        let username: String?
    }

    struct LeaderboardEntry: Decodable, Identifiable {
        let rank: Int
        let username: String
        let score: Int
        let isMe: Bool

        var id: String { username }

        enum CodingKeys: String, CodingKey {
            case rank, username, score
            case isMe = "is_me"
        }
    }

    struct LeaderboardResponse: Decodable {
        struct Me: Decodable {
            let rank: Int
            let score: Int
        }
        let entries: [LeaderboardEntry]
        let me: Me?
    }

    struct Challenge: Decodable {
        let id: String
        let fromUsername: String
        let exercise: String
        let targetReps: Int
        /// pending | accepted | rejected (v0.2 backend; nil on older responses)
        let status: String?
        let toUsername: String?

        enum CodingKeys: String, CodingKey {
            case id, exercise, status
            case fromUsername = "from_username"
            case targetReps = "target_reps"
            case toUsername = "to_username"
        }
    }

    struct MyChallenges: Decodable {
        let sent: [Challenge]
        let received: [Challenge]
    }

    enum APIError: LocalizedError {
        case http(Int, String)
        case usernameTaken

        var errorDescription: String? {
            switch self {
            case .usernameTaken: return "That name is taken — try another."
            case .http(let code, let body): return "Request failed (\(code)): \(body)"
            }
        }
    }

    // MARK: - Endpoints

    /// Create-or-fetch the user for this device.
    @discardableResult
    func identify() async throws -> User {
        struct Wrapper: Decodable { let user: User }
        let w: Wrapper = try await request("POST", "/v1/devices/identify")
        return w.user
    }

    /// Register the chosen leaderboard name (3–24 chars, unique).
    @discardableResult
    func setUsername(_ name: String) async throws -> User {
        struct Wrapper: Decodable { let user: User }
        do {
            let w: Wrapper = try await request(
                "PATCH", "/v1/me",
                body: ["username": name]
            )
            username = w.user.username
            return w.user
        } catch APIError.http(409, _) {
            throw APIError.usernameTaken
        }
    }

    /// Report a finished workout so the leaderboard stays current.
    func submitWorkout(exercise: ExerciseType, reps: Int) async {
        guard reps > 0 else { return }
        struct Ack: Decodable { let accepted: Bool }
        do {
            // Cheap idempotent identify keeps the user row present even if
            // the app was reinstalled between leaderboard visits.
            try? await identify()
            let _: Ack = try await request(
                "POST", "/v1/workouts",
                body: ["exercise": exercise.rawValue, "reps": reps],
                asserted: true
            )
        } catch {
            // Offline / backend down: leaderboard falls back to local data,
            // so a lost submission is not fatal. Logged for diagnosis.
            Logger.log("workout submit failed: \(error.localizedDescription)", level: .warning)
        }
    }

    func leaderboard(
        exercise: ExerciseType,
        period: LeaderboardPeriod
    ) async throws -> LeaderboardResponse {
        try await request(
            "GET",
            "/v1/leaderboard?exercise=\(exercise.rawValue)&period=\(period == .weekly ? "weekly" : "alltime")&limit=50"
        )
    }

    /// Create a challenge. With `toUsername` (must be a friend) it's sent
    /// directly — the backend pushes them a notification; without it you get
    /// a shareable code/link.
    func createChallenge(
        exercise: ExerciseType,
        targetReps: Int,
        toUsername: String? = nil
    ) async throws -> Challenge {
        var body: [String: Any] = ["exercise": exercise.rawValue, "target_reps": targetReps]
        if let toUsername { body["to_username"] = toUsername }
        return try await request("POST", "/v1/challenges", body: body)
    }

    func challenge(id: String) async throws -> Challenge {
        try await request("GET", "/v1/challenges/\(id)")
    }

    /// Accept or reject an incoming challenge (records who-challenged-whom
    /// server-side; both parties can then see the status).
    @discardableResult
    func respondChallenge(id: String, accept: Bool) async throws -> Challenge {
        try await request(
            "POST", "/v1/challenges/\(id)/respond",
            body: ["action": accept ? "accept" : "reject"]
        )
    }

    /// Challenges I sent + ones directed at / responded to by me.
    func myChallenges() async throws -> MyChallenges {
        try await request("GET", "/v1/me/challenges")
    }

    // MARK: - Friends

    struct Friend: Decodable, Identifiable {
        let username: String
        let since: String?
        var id: String { username }
    }

    private struct FriendsResponse: Decodable { let friends: [Friend] }

    func friends() async throws -> [Friend] {
        let r: FriendsResponse = try await request("GET", "/v1/friends")
        return r.friends
    }

    @discardableResult
    func addFriend(username: String) async throws -> [Friend] {
        let r: FriendsResponse = try await request(
            "POST", "/v1/friends", body: ["username": username]
        )
        return r.friends
    }

    @discardableResult
    func removeFriend(username: String) async throws -> [Friend] {
        let r: FriendsResponse = try await request("DELETE", "/v1/friends/\(username)")
        return r.friends
    }

    // MARK: - Push token

    /// Upload the FCM registration token so the backend can push challenge
    /// notifications to this device. `authorized` carries the real
    /// notification-permission state (tokens exist even when denied).
    func setFCMToken(_ token: String, authorized: Bool? = nil) async {
        struct Ack: Decodable { let ok: Bool? }
        var body: [String: Any] = ["token": token]
        if let authorized { body["authorized"] = authorized }
        do {
            try? await identify()
            let _: Ack = try await request(
                "POST", "/v1/me/fcm-token", body: body
            )
        } catch {
            Logger.log("fcm token upload failed: \(error.localizedDescription)", level: .warning)
        }
    }

    // MARK: - App Attest

    /// Enroll an App Attest key once per install (real devices only). Safe to
    /// call repeatedly — it early-outs when already enrolled or unsupported.
    func enrollAttestationIfNeeded() async {
        guard attestKeyID == nil, DCAppAttestService.shared.isSupported else { return }
        do {
            let keyID = try await DCAppAttestService.shared.generateKey()
            let challenge = Data(deviceID.utf8)
            let attestation = try await DCAppAttestService.shared.attestKey(
                keyID,
                clientDataHash: Data(SHA256.hash(data: challenge))
            )
            struct Ack: Decodable { let enrolled: Bool? }
            let _: Ack = try await request(
                "POST", "/v1/devices/attest",
                body: [
                    "key_id": keyID,
                    "attestation": attestation.base64EncodedString(),
                    "challenge": challenge.base64EncodedString(),
                ]
            )
            attestKeyID = keyID
        } catch {
            // Simulator, unsupported hardware or Apple service hiccup —
            // device-id fallback continues to work.
            Logger.log("app attest enroll skipped: \(error.localizedDescription)", level: .info)
        }
    }

    private func assertionHeaders(for body: Data) async -> [String: String] {
        guard let keyID = attestKeyID, DCAppAttestService.shared.isSupported else { return [:] }
        do {
            let hash = Data(SHA256.hash(data: body))
            let assertion = try await DCAppAttestService.shared.generateAssertion(
                keyID, clientDataHash: hash
            )
            return [
                "X-App-Attest-Key-Id": keyID,
                "X-App-Attest-Assertion": assertion.base64EncodedString(),
            ]
        } catch {
            return [:]
        }
    }

    // MARK: - Core request

    private func request<T: Decodable>(
        _ method: String,
        _ path: String,
        body: [String: Any]? = nil,
        asserted: Bool = false
    ) async throws -> T {
        // Paths may carry query strings — string concat avoids the
        // percent-escaping that URL.appending(path:) applies to "?".
        guard let url = URL(string: baseURL.absoluteString + path) else {
            throw APIError.http(0, "bad url")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(deviceID, forHTTPHeaderField: "X-Device-Id")
        var bodyData = Data()
        if let body {
            bodyData = try JSONSerialization.data(withJSONObject: body)
            req.httpBody = bodyData
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if asserted {
            for (k, v) in await assertionHeaders(for: bodyData) {
                req.setValue(v, forHTTPHeaderField: k)
            }
        }

        let (data, response) = try await session.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw APIError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
