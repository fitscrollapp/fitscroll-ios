import Foundation
import os

private let repLog = os.Logger(
    subsystem: "com.fitscroll",
    category: "rep"
)

struct ExerciseThresholds: Sendable {
    let upAngle: Double
    let downAngle: Double
    let minimumConfidence: Float
    let debounceInterval: TimeInterval
    let minimumRepDuration: TimeInterval

    // Relaxed thresholds: Vision's joint detection is noisy under non-standard
    // poses, so we allow a wider motion range and lower confidence to avoid
    // silently rejecting valid reps.

    static let squat = ExerciseThresholds(
        upAngle: 155, downAngle: 110, minimumConfidence: 0.3,
        debounceInterval: 0.5, minimumRepDuration: 0.5
    )

    static let pushUp = ExerciseThresholds(
        upAngle: 140, downAngle: 115, minimumConfidence: 0.25,
        debounceInterval: 0.4, minimumRepDuration: 0.4
    )

    // Hip-shoulder-wrist angle. Arms at sides ~15°, arms out horizontal
    // ~90°, arms overhead ~170°. We count a rep when the user goes from
    // arms-down to arms-overhead — ignoring the legs for now because
    // Vision's ankle detection is too noisy from a front-facing camera.
    static let jumpingJacks = ExerciseThresholds(
        upAngle: 140, downAngle: 40, minimumConfidence: 0.25,
        debounceInterval: 0.25, minimumRepDuration: 0.25
    )

    // Averaged knee angle. Standing upright ~175°; lunge pose has one
    // knee bent to ~90° while the back leg stays relatively straight
    // (~160°), averaging around 125° for a deep rep. In practice the
    // front camera averages in noise from the occluded back leg, so
    // mid-depth lunges only dip to ~140°. Threshold widened accordingly.
    static let lunge = ExerciseThresholds(
        upAngle: 165, downAngle: 145, minimumConfidence: 0.3,
        debounceInterval: 0.35, minimumRepDuration: 0.3
    )

    static func thresholds(for exerciseType: ExerciseType) -> ExerciseThresholds {
        switch exerciseType {
        case .squat: return .squat
        case .pushUp: return .pushUp
        case .jumpingJacks: return .jumpingJacks
        case .lunge: return .lunge
        }
    }
}

enum MotionPhase: String, Sendable {
    case idle
    case goingDown
    case down
    case goingUp
    case up
}

final class RepDetectionEngine: @unchecked Sendable {
    private let exerciseType: ExerciseType
    private let thresholds: ExerciseThresholds
    private(set) var currentPhase: MotionPhase = .idle
    private(set) var repCount: Int = 0
    private var lastRepTime: Date?
    private var phaseStartTime: Date?
    private var lastAngle: Double = 0

    struct DebugInfo: Sendable {
        let angle: Double
        let phase: MotionPhase
        let repCount: Int
        let confidence: Float
        let wasRejected: Bool
        let rejectionReason: String?
    }

    var onRepCompleted: ((Int, Double) -> Void)?
    var onDebugUpdate: ((DebugInfo) -> Void)?

    init(exerciseType: ExerciseType) {
        self.exerciseType = exerciseType
        self.thresholds = ExerciseThresholds.thresholds(for: exerciseType)
    }

    func processFrame(_ frame: PoseFrame) -> WorkoutRepEvent? {
        guard frame.confidence >= thresholds.minimumConfidence else {
            emitDebug(angle: lastAngle, confidence: frame.confidence, rejected: true, reason: "Low confidence")
            if exerciseType == .lunge {
                repLog.notice(
                    "lunge skip conf=\(frame.confidence, privacy: .public) < \(self.thresholds.minimumConfidence, privacy: .public)"
                )
            }
            return nil
        }

        // Note: we intentionally do NOT validate leg form for push-ups.
        // From a front-facing camera the body occludes its own lower half
        // and Vision can't reliably distinguish a proper plank from a
        // knee push-up — attempting to enforce form this way just blocks
        // legitimate reps. We trust the user, and recommend a side-view
        // camera position in the UI for strict form tracking.

        let angle = calculatePrimaryAngle(from: frame)
        guard angle > 0 else {
            emitDebug(angle: 0, confidence: frame.confidence, rejected: true, reason: "Cannot calculate angle")
            if exerciseType == .lunge {
                repLog.notice("lunge no-angle (both sides dropped)")
            }
            return nil
        }

        let previousPhase = currentPhase
        lastAngle = angle
        let result = updatePhase(angle: angle, confidence: frame.confidence, timestamp: frame.timestamp)
        emitDebug(angle: angle, confidence: frame.confidence, rejected: result == nil, reason: nil)

        // Per-frame logging for lunge tuning. We only log when exercise
        // type is lunge so squat/push-up workouts don't flood the log.
        if exerciseType == .lunge {
            let roundedAngle = (angle * 10).rounded() / 10
            let roundedConf = (Double(frame.confidence) * 100).rounded() / 100
            let phaseChanged = previousPhase != currentPhase
            let phaseStr = "\(previousPhase.rawValue)→\(currentPhase.rawValue)"
            if phaseChanged {
                repLog.notice(
                    "lunge angle=\(roundedAngle, privacy: .public) conf=\(roundedConf, privacy: .public) \(phaseStr, privacy: .public) reps=\(self.repCount, privacy: .public)"
                )
            } else {
                repLog.notice(
                    "lunge angle=\(roundedAngle, privacy: .public) phase=\(self.currentPhase.rawValue, privacy: .public)"
                )
            }
            if let result = result {
                let verdict = result.wasAccepted ? "ACCEPTED" : "rejected"
                let reasonStr = result.rejectionReason?.rawValue ?? "-"
                repLog.notice(
                    "lunge rep \(verdict, privacy: .public) #\(result.repNumber, privacy: .public) reason=\(reasonStr, privacy: .public)"
                )
            }
        }

        return result
    }


    func reset() {
        currentPhase = .idle
        repCount = 0
        lastRepTime = nil
        phaseStartTime = nil
        lastAngle = 0
    }

    // MARK: - Angle Calculations

    private func calculatePrimaryAngle(from frame: PoseFrame) -> Double {
        switch exerciseType {
        case .squat:
            return kneeAngle(from: frame)
        case .pushUp:
            return elbowAngle(from: frame)
        case .jumpingJacks:
            return armRaiseAngle(from: frame)
        case .lunge:
            // Lunges use the same hip-knee-ankle angle as squats — the
            // averaged knee angle drops as the front knee bends.
            return kneeAngle(from: frame)
        }
    }

    /// Minimum per-joint confidence for any joint to be trusted.
    private let jointConfidenceThreshold: Float = 0.2

    /// Computes a confidence-weighted average of the angle from BOTH sides (left and right).
    ///
    /// IMPORTANT: Vision normalizes joint coordinates against the source
    /// image's dimensions, which means the same physical pose produces a
    /// different (`x`, `y`) ratio in a 16:9 frame vs a 4:3 frame. If we
    /// compute angles directly from those normalized values, the answer
    /// changes when the camera format changes. We multiply by the actual
    /// image dimensions before computing the angle so the math works in
    /// pixel space and is aspect-ratio independent.
    private func bothSideWeightedAngle(
        _ frame: PoseFrame,
        _ a: (PoseFrame.JointName, PoseFrame.JointName),
        _ b: (PoseFrame.JointName, PoseFrame.JointName),
        _ c: (PoseFrame.JointName, PoseFrame.JointName)
    ) -> Double {
        let imgW = frame.imageSize.width > 0 ? frame.imageSize.width : 1
        let imgH = frame.imageSize.height > 0 ? frame.imageSize.height : 1

        func toPixel(_ p: PoseFrame.JointPosition) -> CGPoint {
            CGPoint(x: p.point.x * imgW, y: p.point.y * imgH)
        }

        var samples: [(angle: Double, weight: Float)] = []

        // Left side
        if let p1 = frame.position(for: a.0),
           let p2 = frame.position(for: b.0),
           let p3 = frame.position(for: c.0),
           p1.confidence >= jointConfidenceThreshold,
           p2.confidence >= jointConfidenceThreshold,
           p3.confidence >= jointConfidenceThreshold {
            let angle = JointAngleCalculator.angle(
                pointA: toPixel(p1), vertex: toPixel(p2), pointC: toPixel(p3)
            )
            let weight = (p1.confidence + p2.confidence + p3.confidence) / 3.0
            samples.append((angle, weight))
        }

        // Right side
        if let p1 = frame.position(for: a.1),
           let p2 = frame.position(for: b.1),
           let p3 = frame.position(for: c.1),
           p1.confidence >= jointConfidenceThreshold,
           p2.confidence >= jointConfidenceThreshold,
           p3.confidence >= jointConfidenceThreshold {
            let angle = JointAngleCalculator.angle(
                pointA: toPixel(p1), vertex: toPixel(p2), pointC: toPixel(p3)
            )
            let weight = (p1.confidence + p2.confidence + p3.confidence) / 3.0
            samples.append((angle, weight))
        }

        guard !samples.isEmpty else { return 0 }

        let totalWeight = samples.reduce(Float(0)) { $0 + $1.weight }
        let weightedSum = samples.reduce(0.0) { $0 + $1.angle * Double($1.weight) }
        return weightedSum / Double(totalWeight)
    }

    /// Hip-Knee-Ankle angle. Straight leg ~180°, deep squat ~60°.
    private func kneeAngle(from frame: PoseFrame) -> Double {
        bothSideWeightedAngle(
            frame,
            (.leftHip, .rightHip),
            (.leftKnee, .rightKnee),
            (.leftAnkle, .rightAnkle)
        )
    }

    /// Shoulder-Elbow-Wrist angle. Straight arm ~180°, fully bent ~30°.
    /// From front-view push-up: up position ~160-170°, down position ~80-100°.
    private func elbowAngle(from frame: PoseFrame) -> Double {
        bothSideWeightedAngle(
            frame,
            (.leftShoulder, .rightShoulder),
            (.leftElbow, .rightElbow),
            (.leftWrist, .rightWrist)
        )
    }

    /// Hip-Shoulder-Wrist angle — tracks how raised the arms are for
    /// jumping jacks. Arms at sides ~15°, arms horizontal ~90°, arms
    /// overhead ~160-170°. We intentionally ignore leg position here: the
    /// arm swing is the more reliable signal from a front camera because
    /// Vision's ankle detection drops confidence fast during jumps.
    private func armRaiseAngle(from frame: PoseFrame) -> Double {
        bothSideWeightedAngle(
            frame,
            (.leftHip, .rightHip),
            (.leftShoulder, .rightShoulder),
            (.leftWrist, .rightWrist)
        )
    }

    // MARK: - Phase State Machine

    private func updatePhase(angle: Double, confidence: Float, timestamp: Date) -> WorkoutRepEvent? {
        let now = timestamp

        switch currentPhase {
        case .idle, .up:
            if angle < thresholds.downAngle {
                currentPhase = .goingDown
                phaseStartTime = now
            }
        case .goingDown:
            if angle <= thresholds.downAngle {
                currentPhase = .down
                phaseStartTime = now
            } else if angle > thresholds.upAngle {
                currentPhase = .idle
            }
        case .down:
            if angle > thresholds.upAngle {
                currentPhase = .goingUp
            }
        case .goingUp:
            if angle >= thresholds.upAngle {
                // Check debounce
                if let lastRep = lastRepTime,
                   now.timeIntervalSince(lastRep) < thresholds.debounceInterval {
                    currentPhase = .up
                    return nil
                }

                // Check minimum rep duration
                if let phaseStart = phaseStartTime,
                   now.timeIntervalSince(phaseStart) < thresholds.minimumRepDuration {
                    currentPhase = .up
                    return WorkoutRepEvent(
                        exerciseType: exerciseType,
                        repNumber: repCount,
                        confidence: Double(confidence),
                        wasAccepted: false,
                        rejectionReason: .tooFast
                    )
                }

                repCount += 1
                lastRepTime = now
                currentPhase = .up
                onRepCompleted?(repCount, Double(confidence))

                return WorkoutRepEvent(
                    exerciseType: exerciseType,
                    repNumber: repCount,
                    confidence: Double(confidence),
                    wasAccepted: true
                )
            }
        }
        return nil
    }

    private func emitDebug(angle: Double, confidence: Float, rejected: Bool, reason: String?) {
        onDebugUpdate?(DebugInfo(
            angle: angle,
            phase: currentPhase,
            repCount: repCount,
            confidence: confidence,
            wasRejected: rejected,
            rejectionReason: reason
        ))
    }
}
