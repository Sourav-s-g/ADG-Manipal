import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch cleaned.count {
        case 3:
            red = (value >> 8) * 17
            green = ((value >> 4) & 0xF) * 17
            blue = (value & 0xF) * 17
            alpha = 255
        case 6:
            red = value >> 16
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
            alpha = 255
        case 8:
            red = value >> 24
            green = (value >> 16) & 0xFF
            blue = (value >> 8) & 0xFF
            alpha = value & 0xFF
        default:
            red = 0
            green = 0
            blue = 0
            alpha = 255
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

enum ADGTheme {
    // MARK: - Core Structural Colors
    static let paper = Color(hex: "FBFAF6")
    static let surface = Color(hex: "F1EFE7")
    static let ink = Color.black
    static let hairline = Color.black.opacity(0.14)

    // MARK: - Rose Gold Brand Tokens
    static let roseGoldLight = Color(hex: "F4D1C2")   // Highlight shine
    static let roseGoldMedium = Color(hex: "E8AF9D")  // Core signature tint
    static let roseGoldDark = Color(hex: "D59B85")    // Shadow depth
    
    static let appBackground = Color(hex: "FFE8B8")

    // MARK: - Brand Gradients
    /// Core metallic rose gold gradient directly matching the community logo artwork
    static func roseGoldGradient() -> LinearGradient {
        LinearGradient(
            colors: [roseGoldLight, roseGoldMedium, roseGoldDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Soft transition context to smoothly shade views into the default paper background tone
    static func roseGoldToWhiteGradient() -> LinearGradient {
        LinearGradient(
            colors: [roseGoldLight.opacity(0.45), paper],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Layout Configurations
    static let cardRadius: CGFloat = 8
    static let pagePadding: CGFloat = 25
}
