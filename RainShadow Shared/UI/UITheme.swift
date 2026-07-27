import SpriteKit

/// Shared RainShadow UI tokens for live text and ephemeral tints.
/// Visible chrome is always painted PNG; this type never invents decorative art.
enum UITheme {
    enum Font {
        static let dialogueBody = "Palatino-Roman"
        static let dialogueBodyBold = "Palatino-Bold"
        static let dialogueName = "Palatino-Bold"
        static let hudVital = "Palatino-Bold"
        static let overlayTitle = "Copperplate"
        static let overlayBody = "AvenirNext-Medium"
        static let overlayBodyBold = "AvenirNext-DemiBold"
        static let overlayCondensed = "AvenirNextCondensed-DemiBold"
        static let typewriter = "CourierNewPS-BoldMT"
    }

    enum Color {
        static let parchment = SKColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 1)
        static let parchmentMuted = SKColor(red: 0.72, green: 0.68, blue: 0.60, alpha: 1)
        static let ink = SKColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
        static let inkMuted = SKColor(red: 0.28, green: 0.24, blue: 0.20, alpha: 1)
        static let oxblood = SKColor(red: 0.62, green: 0.12, blue: 0.14, alpha: 1)
        static let oxbloodHot = SKColor(red: 0.82, green: 0.22, blue: 0.20, alpha: 1)
        static let gunmetal = SKColor(red: 0.30, green: 0.33, blue: 0.34, alpha: 1)
        static let brass = SKColor(red: 0.68, green: 0.47, blue: 0.23, alpha: 1)
        static let healthy = SKColor(red: 0.18, green: 0.74, blue: 0.35, alpha: 1)
        static let wounded = SKColor(red: 0.86, green: 0.58, blue: 0.18, alpha: 1)
        static let critical = SKColor(red: 0.82, green: 0.16, blue: 0.13, alpha: 1)
        static let veil = SKColor(white: 0, alpha: 0.55)
        static let paper = SKColor(red: 0.94, green: 0.91, blue: 0.84, alpha: 1)
        static let stubCaption = SKColor(red: 0.78, green: 0.72, blue: 0.62, alpha: 0.92)
    }

    enum Tint {
        /// Ephemeral hover brighten applied via `colorBlendFactor` on painted icons.
        static let hoverBlend: CGFloat = 0.22
        static let pressedBlend: CGFloat = 0.38
        static let hoverColor = SKColor(white: 1, alpha: 1)
        static let pressedColor = SKColor(red: 0.72, green: 0.78, blue: 0.82, alpha: 1)
        static let disabledAlpha: CGFloat = 0.42
    }
}
