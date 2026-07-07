import SwiftUI

/// Reusable medal-style badge. Earned badges are a colourful gradient coin with
/// a white template icon; locked ones are a muted grey coin with a lock.
struct BadgeView: View {
    let badge: LeaderboardBadge
    let isEarned: Bool
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(coinFill)
                .overlay(
                    Circle().stroke(
                        isEarned ? Color.white.opacity(0.35) : DS.Colors.border,
                        lineWidth: 2
                    )
                )
                .shadow(
                    color: isEarned ? tint.opacity(0.5) : .clear,
                    radius: 8, y: 3
                )

            Image(badge.asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.5, height: size * 0.5)
                .foregroundColor(isEarned ? .white : DS.Colors.textSecondary)

            if !isEarned {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundColor(.white)
                    .padding(size * 0.11)
                    .background(Circle().fill(DS.Colors.background))
                    .overlay(Circle().stroke(DS.Colors.border, lineWidth: 1.5))
                    .offset(x: size * 0.32, y: size * 0.32)
            }
        }
        .frame(width: size, height: size)
    }

    private var tint: Color {
        Color(hexString: badge.colorHex) ?? DS.Colors.accent
    }

    private var coinFill: AnyShapeStyle {
        if isEarned {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [tint, tint.opacity(0.65)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(DS.Colors.secondaryBackground)
    }
}

extension Color {
    /// Hex-string initializer ("#RRGGBB" or "RRGGBB").
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8) & 0xFF) / 255.0,
            blue: Double(v & 0xFF) / 255.0
        )
    }
}
