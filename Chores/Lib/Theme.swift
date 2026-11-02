import SwiftUI
import CoreText

/// choresweb's design tokens (src/styles/global.css): a riso print of the fridge sheet —
/// cool paper, navy ink, and three spot colours that overprint into the members' colours.
enum Theme {
    static let paper = Color(light: 0xf2f4f7, dark: 0x13172c)
    static let sheet = Color(light: 0xffffff, dark: 0x1b2039)
    static let ink = Color(light: 0x1b2140, dark: 0xeceffa)
    static let muted = Color(light: 0x5c6383, dark: 0x9ba2c3)
    static let rule = Color(light: 0x1b2140, dark: 0xeceffa, alpha: (0.16, 0.14))
    static let pink = Color(light: 0xe6007a, dark: 0xff4fa3)
    static let blue = Color(light: 0x0a6cf0, dark: 0x5aa8ff)
    static let sun = Color(hex: 0xffe14d)
    static let onPink = Color(light: 0xffffff, dark: 0x13172c)
    static let error = Color(light: 0xc4004f, dark: 0xff7aa8)
    static let todaySelected = Color(light: 0xffe14d, dark: 0xff4fa3) // today's date on the selected day
    static let navy = Color(hex: 0x1b2140)

    static func registerFonts() {
        if let url = Bundle.main.url(forResource: "FamiljenGrotesk", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Familjen Grotesk, scaled with Dynamic Type. 17 is the body size.
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Familjen Grotesk", size: size, relativeTo: .body).weight(weight)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }

    init(light: UInt32, dark: UInt32, alpha: (Double, Double) = (1, 1)) {
        self.init(UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(Color(hex: isDark ? dark : light, alpha: isDark ? alpha.1 : alpha.0))
        })
    }
}
