import SwiftUI

final class PanelState: ObservableObject {
    private static let isCollapsedKey = "panelIsCollapsed"

    @Published var isCollapsed: Bool {
        didSet { UserDefaults.standard.set(isCollapsed, forKey: Self.isCollapsedKey) }
    }

    /// Not persisted — the panel always shows on next launch.
    @Published var isHidden: Bool = false

    /// Which tab is showing and which overlay sheet (if any) is up. Not
    /// persisted, and not just local view state: living here lets the
    /// DEBUG screenshot tour (see Screenshots.swift) drive the UI from
    /// outside ContentView.
    @Published var tab: ShelfTab = .repos
    @Published var activeSheet: ActiveSheet?

    init() {
        isCollapsed = UserDefaults.standard.bool(forKey: Self.isCollapsedKey)
    }
}
