import SwiftUI
import AppKit

/// One set of timings so every animation in the app feels related.
enum Motion {
    /// Content changing in place (tab switch, filter, sheet appearing).
    static let swap = Animation.easeInOut(duration: 0.2)
    /// Bigger context changes (switching tabs).
    static let screen = Animation.easeInOut(duration: 0.22)
}

/// Meaning-driven color for status tags — green = fine, orange = needs
/// attention, red = destructive, purple = informational, gray = inactive.
enum Tag {
    case onDisk, active, stale, destructive, info, inactive

    var color: Color {
        switch self {
        case .onDisk, .active: return .green
        case .stale: return .orange
        case .destructive: return .red
        case .info: return .purple
        case .inactive: return .secondary
        }
    }
}

/// Small status label: colored text on the same color at 15% opacity.
struct TagBadge: View {
    let text: String
    let tag: Tag

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(tag.color)
            .background(tag.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
    }
}

/// Capsule filter chip — selected = primary color fill with window-background
/// text, unselected = secondary at 12%.
struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.callout)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .foregroundStyle(selected ? Color(nsColor: .windowBackgroundColor) : .primary)
                .background(selected ? Color.primary : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A card surface — `.background` fill with a hairline `.separator` stroke.
extension View {
    func cardStyle(radius: CGFloat = 10) -> some View {
        background(.background, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(.separator))
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

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var title: String { rawValue.capitalized }
}

/// Compact System / Light / Dark switch, segmented with SF Symbols.
struct AppearanceToggle: View {
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some View {
        Picker("Appearance", selection: $appearanceRaw) {
            ForEach(AppearanceMode.allCases) { mode in
                Image(systemName: mode.symbol)
                    .help(mode.title)
                    .accessibilityLabel(mode.title)
                    .tag(mode.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 76)
    }
}

/// Per-account identity color — functional (tells accounts apart at a
/// glance), not decorative, so it stays outside the semantic Tag palette.
enum AccountPalette {
    static let colors: [Color] = [.blue, .orange, .green, .purple, .pink, .teal]

    static func color(_ login: String) -> Color {
        guard !login.isEmpty else { return colors[0] }
        return colors[abs(login.hashValue) % colors.count]
    }
}
