import SwiftUI

final class PanelState: ObservableObject {
    private static let isCollapsedKey = "panelIsCollapsed"

    @Published var isCollapsed: Bool {
        didSet { UserDefaults.standard.set(isCollapsed, forKey: Self.isCollapsedKey) }
    }

    /// Not persisted — the panel always shows on next launch.
    @Published var isHidden: Bool = false

    init() {
        isCollapsed = UserDefaults.standard.bool(forKey: Self.isCollapsedKey)
    }
}
