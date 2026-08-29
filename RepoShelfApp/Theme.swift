import SwiftUI
import AppKit

/// Hand-tuned palette per appearance — the same indigo-on-off-white family
/// as the Kanban Timeline widget so the two panels feel like a set.
enum Theme {
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    static var panelBackground: Color {
        dynamic(light: NSColor(red: 0.969, green: 0.973, blue: 0.980, alpha: 1),
                dark: NSColor(red: 0.090, green: 0.094, blue: 0.114, alpha: 1))
    }

    static var surface: Color {
        dynamic(light: .white,
                dark: NSColor(red: 0.137, green: 0.145, blue: 0.188, alpha: 1))
    }

    static var surfaceSecondary: Color {
        dynamic(light: NSColor(red: 0.949, green: 0.957, blue: 0.969, alpha: 1),
                dark: NSColor(red: 0.110, green: 0.114, blue: 0.141, alpha: 1))
    }

    static var border: Color {
        dynamic(light: NSColor(red: 0.878, green: 0.890, blue: 0.914, alpha: 1),
                dark: NSColor(red: 0.227, green: 0.239, blue: 0.282, alpha: 1))
    }

    static var borderSoft: Color {
        dynamic(light: NSColor(red: 0.910, green: 0.918, blue: 0.937, alpha: 1),
                dark: NSColor(red: 0.165, green: 0.173, blue: 0.212, alpha: 1))
    }

    static var accent: Color {
        dynamic(light: NSColor(red: 0.345, green: 0.412, blue: 0.953, alpha: 1),
                dark: NSColor(red: 0.541, green: 0.588, blue: 1.0, alpha: 1))
    }

    static var chipBackground: Color {
        dynamic(light: NSColor(red: 0.949, green: 0.957, blue: 1.0, alpha: 1),
                dark: NSColor(red: 0.149, green: 0.169, blue: 0.271, alpha: 1))
    }

    static var chipBorder: Color {
        dynamic(light: NSColor(red: 0.788, green: 0.816, blue: 1.0, alpha: 1),
                dark: NSColor(red: 0.239, green: 0.271, blue: 0.439, alpha: 1))
    }

    static var ok: Color {
        dynamic(light: NSColor(red: 0.184, green: 0.616, blue: 0.345, alpha: 1),
                dark: NSColor(red: 0.361, green: 0.827, blue: 0.522, alpha: 1))
    }

    static var okBackground: Color {
        dynamic(light: NSColor(red: 0.906, green: 0.965, blue: 0.933, alpha: 1),
                dark: NSColor(red: 0.118, green: 0.200, blue: 0.157, alpha: 1))
    }

    static var okBorder: Color {
        dynamic(light: NSColor(red: 0.874, green: 0.902, blue: 1.0, alpha: 1),
                dark: NSColor(red: 0.184, green: 0.227, blue: 0.345, alpha: 1))
    }

    static var danger: Color {
        dynamic(light: NSColor(red: 0.878, green: 0.267, blue: 0.298, alpha: 1),
                dark: NSColor(red: 1.0, green: 0.443, blue: 0.463, alpha: 1))
    }

    static var dangerBorder: Color {
        dynamic(light: NSColor(red: 0.949, green: 0.824, blue: 0.831, alpha: 1),
                dark: NSColor(red: 0.353, green: 0.180, blue: 0.188, alpha: 1))
    }

    static var dangerBackground: Color {
        dynamic(light: NSColor(red: 0.992, green: 0.925, blue: 0.925, alpha: 1),
                dark: NSColor(red: 0.200, green: 0.114, blue: 0.122, alpha: 1))
    }

    static let accountPalette: [Color] = [
        Color(red: 0.345, green: 0.412, blue: 0.953),
        Color(red: 0.878, green: 0.537, blue: 0.294),
        Color(red: 0.247, green: 0.651, blue: 0.416),
        Color(red: 0.714, green: 0.373, blue: 0.690),
        Color(red: 0.294, green: 0.529, blue: 0.761),
    ]

    static func accountColor(_ login: String) -> Color {
        guard !login.isEmpty else { return accountPalette[0] }
        let hash = abs(login.hashValue)
        return accountPalette[hash % accountPalette.count]
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var label: String { rawValue.capitalized }
}
