import SwiftUI

enum DS {
    /// Dark "neon" palette matching the FitScroll UI design system:
    /// near-black surfaces, neon green primary, electric blue accent.
    enum Colors {
        // Brand / accents
        static let neon = Color(red: 0.133, green: 0.957, blue: 0.659)      // #22F4A8
        static let primary = Color(red: 0.231, green: 0.510, blue: 0.965)   // #3B82F6 electric blue
        static let secondary = Color(red: 0.376, green: 0.647, blue: 0.980) // #60A5FA accent blue
        static let accent = Color(red: 1.0, green: 0.690, blue: 0.125)      // #FFB020 warning orange
        static let success = Color(red: 0.133, green: 0.957, blue: 0.659)   // #22F4A8
        static let warning = Color(red: 1.0, green: 0.690, blue: 0.125)     // #FFB020
        static let error = Color(red: 1.0, green: 0.353, blue: 0.373)       // #FF5A5F

        // Surfaces
        static let background = Color(red: 0.051, green: 0.067, blue: 0.090)        // #0D1117 Surface 1
        static let cardBackground = Color(red: 0.086, green: 0.106, blue: 0.133)    // #161B22 Surface 2
        static let secondaryBackground = Color(red: 0.122, green: 0.149, blue: 0.188) // #1F2630 Surface 3
        static let border = Color(red: 0.165, green: 0.196, blue: 0.235)           // #2A323C

        // Text
        static let textPrimary = Color(red: 0.949, green: 0.957, blue: 0.973)   // #F2F4F8
        static let textSecondary = Color(red: 0.596, green: 0.643, blue: 0.682) // #98A4AE
    }

    /// Standard reusable gradients pulled from the design system.
    enum Gradients {
        static let primaryButton = LinearGradient(
            colors: [Colors.primary, Colors.secondary],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let neonRing = LinearGradient(
            colors: [Colors.neon, Colors.secondary],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Corner {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum FontSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 16
        static let title3: CGFloat = 20
        static let title2: CGFloat = 24
        static let title: CGFloat = 28
        static let largeTitle: CGFloat = 34
        static let hero: CGFloat = 48
    }

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
    }
}

extension View {
    /// Standard dark card surface used across the redesigned screens:
    /// Surface 2 fill with a hairline Surface-border stroke.
    func dsCard(cornerRadius: CGFloat = DS.Corner.large) -> some View {
        self
            .background(DS.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
    }
}
