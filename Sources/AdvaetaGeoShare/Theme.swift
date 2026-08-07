import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let bronze = Color(hex: 0xC4944A)
    static let bronzeBright = Color(hex: 0xD4A85A)
    static let bronzeDim = Color(hex: 0x8B6914)
    static let tealAccent = Color(hex: 0x2A7B7B)
    static let tealLight = Color(hex: 0x3AA0A0)
    static let backgroundBlack = Color(hex: 0x0C0C0C)
    static let backgroundSoft = Color(hex: 0x141414)
    static let textCream = Color(hex: 0xF5E6C8)
    static let textCreamDim = Color(hex: 0xD4C4A6)
    static let textMuted = Color(hex: 0x8B7B5E)
    static let darkBrown = Color(hex: 0x2A2015)
}

extension Font {
    static func display(_ size: CGFloat) -> Font {
        .custom("CinzelDecorative-Black", size: size)
    }

    static func heading(_ size: CGFloat) -> Font {
        .custom("Cinzel-Bold", size: size)
    }

    static func body(_ size: CGFloat = 18) -> Font {
        .custom("CormorantGaramond-Medium", size: size)
    }

    static func caption(_ size: CGFloat = 14) -> Font {
        .custom("CormorantGaramond-Regular", size: size)
    }
}

/// Outline button matching the website's .btn-primary/.btn-secondary: sharp corners, a
/// colored border, transparent fill, and an inverted fill on press (the touch equivalent
/// of the site's hover fill-sweep animation).
struct GoldOutlineButtonStyle: ButtonStyle {
    var tint: Color = .bronze
    var textColor: Color = .bronze

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.heading(14))
            .tracking(2)
            .foregroundStyle(configuration.isPressed ? Color.backgroundBlack : textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(configuration.isPressed ? tint : Color.clear)
            .overlay(Rectangle().strokeBorder(tint, lineWidth: 2))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Sharp-cornered, dark-background text field frame with a thin bronze border, matching the
/// site's flat/angular geometry (no rounded corners anywhere except the logo).
struct GoldFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body(18))
            .foregroundStyle(Color.textCream)
            .padding(12)
            .background(Color.backgroundSoft)
            .overlay(Rectangle().strokeBorder(Color.bronzeDim.opacity(0.5), lineWidth: 1))
    }
}

extension View {
    func goldFieldStyle() -> some View {
        modifier(GoldFieldStyle())
    }
}

/// The circular bronze-ringed medallion logo treatment used throughout the website.
struct MedallionLogo: View {
    var diameter: CGFloat

    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFill()
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.bronze, lineWidth: 3))
            .shadow(color: Color.bronze.opacity(0.35), radius: 16)
            .shadow(color: Color.tealAccent.opacity(0.15), radius: 28)
    }
}
