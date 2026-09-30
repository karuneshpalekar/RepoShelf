import SwiftUI

final class PanelState: ObservableObject {
    /// Whether the panel is showing — toggled from the menu bar. Not
    /// persisted: the panel always shows on next launch.
    @Published var isHidden: Bool = false

    /// Which tab is showing and which overlay sheet (if any) is up. Not
    /// persisted, and not just local view state: living here lets the
    /// DEBUG screenshot tour (see Screenshots.swift) drive the UI from
    /// outside ContentView.
    @Published var tab: ShelfTab = .repos
    @Published var activeSheet: ActiveSheet?
}
