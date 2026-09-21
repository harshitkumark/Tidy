import SwiftUI

// MARK: - Color Palette (Section 10 of CLAUDE.md)

extension Color {
    /// Ink #0F1B2D — primary text, dark backgrounds
    static let tidyInk = Color("TidyInk", bundle: .main)
    /// Mint #2EC4A6 — primary accent
    static let tidyMint = Color("TidyMint", bundle: .main)
    /// Coral #FF6B5E — warnings, destructive actions
    static let tidyCoral = Color("TidyCoral", bundle: .main)
    /// Cloud #F4F7FA — light backgrounds, cards
    static let tidyCloud = Color("TidyCloud", bundle: .main)

    // Fallback initializers when color assets aren't set up yet
    static let tidyInkFallback = Color(red: 15/255, green: 27/255, blue: 45/255)
    static let tidyMintFallback = Color(red: 46/255, green: 196/255, blue: 166/255)
    static let tidyCoralFallback = Color(red: 255/255, green: 107/255, blue: 94/255)
    static let tidyCloudFallback = Color(red: 244/255, green: 247/255, blue: 250/255)
}

// MARK: - Theme

enum Theme {
    // MARK: Colors (adaptive)
    enum Colors {
        static let ink = Color(light: .tidyInkFallback, dark: .white)
        static let inkSecondary = Color(light: .tidyInkFallback.opacity(0.6), dark: .white.opacity(0.6))
        static let mint = Color.tidyMintFallback
        static let coral = Color.tidyCoralFallback
        static let cloud = Color(light: .tidyCloudFallback, dark: Color(red: 0.1, green: 0.1, blue: 0.12))
        static let cardBackground = Color(light: .white, dark: Color(red: 0.13, green: 0.13, blue: 0.15))
        static let background = Color(light: .tidyCloudFallback, dark: Color(red: 0.06, green: 0.06, blue: 0.08))
        static let testModePill = Color.orange
    }

    // MARK: Typography
    enum Typography {
        static func largeTitle() -> Font { .system(.largeTitle, design: .rounded, weight: .bold) }
        static func title() -> Font { .system(.title2, design: .rounded, weight: .semibold) }
        static func headline() -> Font { .system(.headline, design: .rounded, weight: .semibold) }
        static func body() -> Font { .system(.body, design: .default) }
        static func caption() -> Font { .system(.caption, design: .default) }
        static func bigNumber() -> Font { .system(size: 42, weight: .bold, design: .rounded) }
        static func mediumNumber() -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    }

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: Radius
    enum Radius {
        static let card: CGFloat = 20
        static let button: CGFloat = 14
        static let small: CGFloat = 8
    }
}

// MARK: - Adaptive Color Helper

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
