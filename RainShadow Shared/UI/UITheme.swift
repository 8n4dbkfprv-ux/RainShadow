import SpriteKit

/// Parchment, sepia ink, oxblood and antique brass shared by the fantasy UI.
enum UITheme {
    /// Bookish serif typography complements the parchment without sacrificing legibility.
    enum Font {
        static let dialogueBody = "Baskerville"
        static let dialogueBodyItalic = "Baskerville-Italic"
        static let dialogueBodyBold = "Baskerville-SemiBold"
        static let dialogueName = "Baskerville-SemiBold"
        static let dialogueCommand = "Baskerville-SemiBold"
        static let hudVital = "Baskerville-SemiBold"
        static let overlayTitle = "Baskerville-SemiBold"
        static let overlayBody = "Baskerville"
        static let overlayBodyBold = "Baskerville-SemiBold"
        static let overlayCondensed = "Baskerville-SemiBold"
        static let typewriter = "Baskerville-SemiBold"
    }

    enum Color {
        /// Primary dialogue body — near-white parchment for contrast on the black content well.
        static let parchment = SKColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1)
        static let parchmentMuted = SKColor(red: 0.72, green: 0.72, blue: 0.70, alpha: 1)
        static let ink = SKColor(red: 0.19, green: 0.12, blue: 0.075, alpha: 1)
        static let inkMuted = SKColor(red: 0.38, green: 0.27, blue: 0.17, alpha: 1)
        static let oxblood = SKColor(red: 0.72, green: 0.22, blue: 0.22, alpha: 1)
        static let oxbloodHot = SKColor(red: 0.92, green: 0.36, blue: 0.30, alpha: 1)
        static let gunmetal = SKColor(red: 0.32, green: 0.33, blue: 0.34, alpha: 1)
        /// Speaker names / case titles — bright aged brass on black.
        static let brass = SKColor(red: 0.90, green: 0.86, blue: 0.72, alpha: 1)
        static let healthy = SKColor(red: 0.72, green: 0.74, blue: 0.76, alpha: 1)
        static let wounded = SKColor(red: 0.82, green: 0.62, blue: 0.28, alpha: 1)
        static let critical = SKColor(red: 0.72, green: 0.18, blue: 0.16, alpha: 1)
        static let veil = SKColor(white: 0, alpha: 0.55)
        static let paper = SKColor(red: 0.92, green: 0.84, blue: 0.66, alpha: 1)
        static let paperShadow = SKColor(red: 0.77, green: 0.65, blue: 0.45, alpha: 1)
        static let engraved = SKColor(red: 0.47, green: 0.32, blue: 0.15, alpha: 1)
        static let wax = SKColor(red: 0.43, green: 0.12, blue: 0.10, alpha: 1)
        static let stubCaption = SKColor(red: 0.78, green: 0.72, blue: 0.62, alpha: 0.92)
        /// CONTINUE / END label on the gunmetal command plate.
        static let commandLabel = SKColor(red: 0.88, green: 0.86, blue: 0.78, alpha: 1)
    }

    enum Tint {
        /// Ephemeral hover brighten applied via `colorBlendFactor` on painted icons.
        static let hoverBlend: CGFloat = 0.22
        static let pressedBlend: CGFloat = 0.38
        static let hoverColor = SKColor(white: 1, alpha: 1)
        static let pressedColor = SKColor(red: 0.72, green: 0.78, blue: 0.82, alpha: 1)
        /// Stub icons stay readable on dark chrome while still reading as inactive.
        static let disabledAlpha: CGFloat = 0.72
    }
}
