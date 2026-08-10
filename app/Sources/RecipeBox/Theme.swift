import SwiftUI

// Dark, warm, muted palette — mirrors the approved mockup.
enum Theme {
    static let bg       = Color(hex: 0x1A1714)
    static let surface  = Color(hex: 0x23201B)
    static let surface2 = Color(hex: 0x2B271F)
    static let line     = Color(hex: 0x383229)
    static let text     = Color(hex: 0xE9E1D4)
    static let muted    = Color(hex: 0xA89D8B)
    static let faint    = Color(hex: 0x7C7363)
    static let amber    = Color(hex: 0xC89D61)
    static let amberDim = Color(hex: 0xA07E44)
    static let green    = Color(hex: 0x8FA173)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// Pill-style button used in the reading view toolbar.
struct PillButton: ButtonStyle {
    var active = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(active ? Theme.amber : Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? Theme.amber.opacity(0.14) : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? Theme.amberDim : Theme.line, lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
