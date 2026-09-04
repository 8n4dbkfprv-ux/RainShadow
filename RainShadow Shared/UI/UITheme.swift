import SpriteKit

/// Shared RainShadow UI tokens for live text and ephemeral tints.
/// Visible chrome is always painted PNG; this type never invents decorative art.
enum UITheme {
    enum Font {
        static let dialogueBody = "Palatino-Roman"
        static let dialogueBodyBold = "Palatino-Bold"
        static let dialogueName = "Palatino-Bold"
        static let dialogueCommand = "Palatino-Bold"
        static let hudVital = "Palatino-Bold"
        static let overlayTitle = "Copperplate"
        static let overlayBody = "AvenirNext-Medium"
        static let overlayBodyBold = "AvenirNext-DemiBold"
        static let overlayCondensed = "AvenirNextCondensed-DemiBold"
        static let typewriter = "CourierNewPS-BoldMT"
    }

    enum Color {
        /// Primary dialogue body — near-white parchment for contrast on the black content well.
        static let parchment = SKColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1)
        static let parchmentMuted = SKColor(red: 0.72, green: 0.72, blue: 0.70, alpha: 1)
        static let ink = SKColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
        static let inkMuted = SKColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1)
        static let oxblood = SKColor(red: 0.72, green: 0.22, blue: 0.22, alpha: 1)
        static let oxbloodHot = SKColor(red: 0.92, green: 0.36, blue: 0.30, alpha: 1)
        static let gunmetal = SKColor(red: 0.32, green: 0.33, blue: 0.34, alpha: 1)
        /// Speaker names / case titles — bright aged brass on black.
        static let brass = SKColor(red: 0.90, green: 0.86, blue: 0.72, alpha: 1)
        static let healthy = SKColor(red: 0.72, green: 0.74, blue: 0.76, alpha: 1)
        static let wounded = SKColor(red: 0.82, green: 0.62, blue: 0.28, alpha: 1)
        static let critical = SKColor(red: 0.72, green: 0.18, blue: 0.16, alpha: 1)
        static let veil = SKColor(white: 0, alpha: 0.55)
        static let paper = SKColor(red: 0.92, green: 0.89, blue: 0.82, alpha: 1)
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
