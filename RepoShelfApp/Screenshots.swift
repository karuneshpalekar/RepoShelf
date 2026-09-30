#if DEBUG
import AppKit
import SwiftUI

/// Walks RepoShelf through every tab, overlay sheet and appearance so a
/// restyle can be checked without clicking through it by hand.
///
///   REPOSHELF_SHOTS=/tmp/shots /Applications/RepoShelf.app/Contents/MacOS/RepoShelf
///
/// Captures the panel's own NSWindow (an app may image its own windows
/// without screen-recording permission) — RepoShelf's overlay sheets are
/// drawn inside that same window, not real NSWindow sheets, so there's no
/// separate sheet-compositing step.
@MainActor
enum ScreenshotTour {
    static func run(store: Store, panelState: PanelState, panel: FloatingPanel, to dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        panel.setFrame(NSRect(x: panel.frame.minX, y: panel.frame.minY, width: 460, height: 640), display: true)
        panel.orderFrontRegardless()

        for _ in 0..<60 where store.accounts.isEmpty { await pause(0.5) }
        for _ in 0..<60 where store.isScanning || store.isLoadingRepos { await pause(0.5) }
        await pause(1.0)

        let sampleCloneID = store.rows.first { !$0.isCloned && !$0.isLocalOnly }?.id
        let samplePublishFolder = FileManager.default.homeDirectoryForCurrentUser.path

        for mode in [AppearanceMode.light, .dark] {
            UserDefaults.standard.set(mode.rawValue, forKey: "appearanceMode")
            panelState.activeSheet = nil
            panelState.isCollapsed = false

            for tab in ShelfTab.allCases {
                panelState.tab = tab
                await pause(0.8)
                save(panel, "\(tab.rawValue.lowercased())-\(mode.rawValue)", dir)
            }

            if let id = sampleCloneID {
                panelState.tab = .repos
                panelState.activeSheet = .clone(id)
                await pause(0.8)
                save(panel, "sheet-clone-\(mode.rawValue)", dir)
            }

            panelState.activeSheet = .addRepo
            await pause(0.6)
            save(panel, "sheet-addrepo-\(mode.rawValue)", dir)

            panelState.activeSheet = .addAccount
            await pause(0.6)
            save(panel, "sheet-addaccount-\(mode.rawValue)", dir)

            panelState.activeSheet = .publish(samplePublishFolder)
            await pause(0.6)
            save(panel, "sheet-publish-\(mode.rawValue)", dir)

            panelState.activeSheet = nil
            await pause(0.3)

            withAnimation(Motion.swap) { panelState.isCollapsed = true }
            await pause(1.2)
            save(panel, "pill-\(mode.rawValue)", dir)
            withAnimation(Motion.swap) { panelState.isCollapsed = false }
            await pause(0.4)
        }

        UserDefaults.standard.set(AppearanceMode.system.rawValue, forKey: "appearanceMode")
        print("SHOTS OK")
        exit(0)
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }

    private static func image(of window: NSWindow) -> CGImage? {
        CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber),
                                [.boundsIgnoreFraming, .bestResolution])
    }

    private static func save(_ window: NSWindow, _ name: String, _ dir: URL) {
        window.displayIfNeeded()
        guard let img = image(of: window) else { print("shots: failed \(name)"); return }
        let rep = NSBitmapImageRep(cgImage: img)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
        print("shots: \(name).png \(img.width)x\(img.height)")
    }
}
#endif
