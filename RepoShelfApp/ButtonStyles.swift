import SwiftUI

extension View {
    /// Insurance for a custom (non-native-chrome) button label: guarantees
    /// the whole visible area is the hit target, not just its non-empty
    /// subviews (matters for HStacks with a Spacer in the label).
    func fullyClickable() -> some View {
        contentShape(Rectangle())
    }
}
