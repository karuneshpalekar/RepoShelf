import SwiftUI
import AppKit

@main
struct RepoShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("RepoShelf", systemImage: "tray.full") {
            MenuBarCommands(panelState: appDelegate.panelState, store: appDelegate.store)
        }
    }
}

/// Its own view (rather than inline in the Scene body) so `panelState` is
/// truly observed — the Show RepoShelf checkmark stays in sync with
/// whatever else changes visibility, not just this toggle.
private struct MenuBarCommands: View {
    @ObservedObject var panelState: PanelState
    let store: Store

    var body: some View {
        Toggle("Show RepoShelf", isOn: Binding(
            get: { !panelState.isHidden },
            set: { panelState.isHidden = !$0 }
        ))
        Button("Refresh") {
            store.refreshCurrent()
        }
        Divider()
        Button("Open Workspace Folder") {
            NSWorkspace.shared.open(store.state.workspaceRoot)
        }
        Divider()
        Button("Quit RepoShelf") {
            NSApp.terminate(nil)
        }
    }
}
