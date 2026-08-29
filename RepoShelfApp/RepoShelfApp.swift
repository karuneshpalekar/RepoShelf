import SwiftUI
import AppKit

@main
struct RepoShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("RepoShelf", systemImage: "tray.full") {
            Button("Show / Hide RepoShelf") {
                appDelegate.togglePanel()
            }
            Button("Refresh") {
                appDelegate.store.refreshCurrent()
            }
            Divider()
            Button("Open Workspace Folder") {
                NSWorkspace.shared.open(appDelegate.store.state.workspaceRoot)
            }
            Divider()
            Button("Quit RepoShelf") {
                NSApp.terminate(nil)
            }
        }
    }
}
