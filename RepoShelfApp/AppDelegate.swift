import SwiftUI
import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?
    let store = Store()
    let panelState = PanelState()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = ContentView()
            .environmentObject(store)
            .environmentObject(panelState)

        let panel = FloatingPanel(contentView: content)
        if let screen = NSScreen.main {
            if let saved = FloatingPanel.savedFrame(fittingIn: screen.visibleFrame) {
                panel.setFrame(saved, display: false)
            } else {
                let origin = NSPoint(
                    x: screen.visibleFrame.maxX - panel.frame.width - 24,
                    y: screen.visibleFrame.maxY - panel.frame.height - 24
                )
                panel.setFrameOrigin(origin)
            }
        }
        if panelState.isCollapsed {
            panel.setCollapsed(true)
        }
        panel.orderFrontRegardless()
        panel.frameTrackingEnabled = true
        self.panel = panel

        panelState.$isCollapsed
            .removeDuplicates()
            .dropFirst()
            .sink { [weak panel] collapsed in panel?.setCollapsed(collapsed) }
            .store(in: &cancellables)

        panelState.$isHidden
            .removeDuplicates()
            .dropFirst()
            .sink { [weak panel] hidden in
                if hidden { panel?.orderOut(nil) } else { panel?.orderFrontRegardless() }
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )

        store.bootstrap()
    }

    @objc private func handleWake() {
        store.refreshCurrent()
    }

    func togglePanel() {
        panelState.isHidden.toggle()
    }
}
