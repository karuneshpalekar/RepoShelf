import SwiftUI

/// A borderless button style (like `.plain`) that makes the **entire** area
/// of the label clickable — not just the glyphs/text — and adds a light
/// press feedback. Pair it with a label whose padding / background / overlay
/// live *inside* the label closure so the whole visual is the hit target.
struct HitFullButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

extension ButtonStyle where Self == HitFullButtonStyle {
    /// Whole-control hit area + press feedback. Use everywhere `.plain` was used.
    static var hitFull: HitFullButtonStyle { HitFullButtonStyle() }
}

extension View {
    /// Belt-and-braces: guarantees the full frame of this view is hit-tested.
    /// Apply as the final modifier on a control whose tappable area must
    /// match its visible bounds.
    func fullyClickable() -> some View {
        contentShape(Rectangle())
    }
}

/// Standard sheet footer button — the whole pill is the hit target.
struct SheetButton: View {
    enum Kind { case primary, secondary }

    let title: String
    var kind: Kind = .secondary
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: kind == .primary ? .bold : .medium))
                .foregroundStyle(kind == .primary ? Color.white : Color.secondary)
                .padding(.horizontal, kind == .primary ? 15 : 13)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(kind == .primary ? Theme.accent : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(kind == .primary ? Color.clear : Theme.border)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.hitFull)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}
