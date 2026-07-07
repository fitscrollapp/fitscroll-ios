import SwiftUI

/// Duolingo-style building blocks shared across every screen so the whole app
/// reads with the same playful, gamified language: chunky "candy" buttons with
/// a pressable 3D lip, bright circular icon badges, and heavy rounded numerals.
enum Duo {
    /// Per-exercise accent so the colourful circular badges stay consistent
    /// everywhere they appear (Dashboard, History, Settings, Challenge).
    static func color(for exercise: ExerciseType) -> Color {
        switch exercise {
        case .squat:        return DS.Colors.primary   // electric blue
        case .pushUp:       return DS.Colors.accent     // orange
        case .jumpingJacks: return DS.Colors.neon       // neon green
        case .lunge:        return Color(red: 0.62, green: 0.35, blue: 0.98) // purple
        }
    }
}

/// The signature Duolingo button: a solid saturated fill with a darker bottom
/// "lip" that makes it look physically pressable, big rounded corners, and a
/// bold rounded label. Press animates the button down onto its lip.
struct DuoButton<Label: View>: View {
    var fill: Color = DS.Colors.neon
    var foreground: Color = DS.Colors.background
    var height: CGFloat = 58
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var pressed = false
    private let lip: CGFloat = 5

    var body: some View {
        Button {
            // Every candy button in the app clicks the same way (Duolingo-style
            // uniform tap sound) — one sound, everywhere.
            SoundManager.click()
            action()
        } label: {
            label()
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fill)
                )
                .offset(y: pressed ? lip : 0)
                .background(
                    // The darker lip sits just below the face; when pressed the
                    // face drops onto it so the button appears to depress.
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fill.duoShade(0.78))
                        .offset(y: lip)
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.06)) { pressed = true } }
                .onEnded { _ in withAnimation(.easeOut(duration: 0.10)) { pressed = false } }
        )
    }
}

/// Bright circular icon badge — a filled colour disc holding a white glyph,
/// echoing the leaderboard avatars. Replaces thin line icons in list rows.
struct DuoIconBadge: View {
    let systemName: String
    var color: Color = DS.Colors.neon
    var size: CGFloat = 44
    var glyphScale: CGFloat = 0.5

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.duoShade(0.82)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Image(systemName: systemName)
                .font(.system(size: size * glyphScale, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.35), radius: 6, y: 2)
    }
}

/// Chunky stat tile: big rounded number over a circular icon badge, on a
/// rounded card. Used for the dashboard / history stat rows.
struct DuoStatTile: View {
    let value: String
    let title: String
    let systemName: String
    var color: Color = DS.Colors.primary

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            DuoIconBadge(systemName: systemName, color: color, size: 40)
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(DS.Colors.textPrimary)
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.sm)
        .dsCard(cornerRadius: DS.Corner.xl)
    }
}

extension Color {
    /// Multiply the RGB channels toward black to derive a darker shade of the
    /// same hue — used for button lips and badge gradients. `factor` < 1.
    func duoShade(_ factor: CGFloat) -> Color {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r * factor, green: g * factor, blue: b * factor, opacity: a)
        #else
        return self.opacity(0.8)
        #endif
    }
}
