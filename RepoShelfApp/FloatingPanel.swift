import SwiftUI
import AppKit

/// An NSPanel that behaves like a persistent desktop widget: available
/// without a Dock icon, doesn't steal focus, stays on the Space it was
/// opened on. Repositioning is via DragHandle on the toolbar header only,
/// so it doesn't fight scroll/drag gestures inside the panel.
final class FloatingPanel: NSPanel, NSWindowDelegate {
    static let expandedSize = NSSize(width: 460, height: 640)
    static let collapsedSize = NSSize(width: 300, height: 78)

    private static let originXKey = "panelOriginX"
    private static let originYKey = "panelOriginY"
    private static let widthKey = "panelWidth"
    private static let heightKey = "panelHeight"

    private(set) var isCollapsedState = false
    var frameTrackingEnabled = false

    init(contentView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.expandedSize),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = false
        level = .normal
        collectionBehavior = [.stationary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        standardWindowButton(.zoomButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        delegate = self

        self.contentView = NSHostingView(rootView: contentView)
    }

    func setCollapsed(_ collapsed: Bool) {
        isCollapsedState = collapsed
        let newSize = collapsed ? Self.collapsedSize : Self.expandedSize
        let topRight = NSPoint(x: frame.maxX, y: frame.maxY)
        let newOrigin = NSPoint(x: topRight.x - newSize.width, y: topRight.y - newSize.height)
        setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: true)
    }

    func windowDidMove(_ notification: Notification) { persistFrameIfNeeded() }
    func windowDidResize(_ notification: Notification) { persistFrameIfNeeded() }

    private func persistFrameIfNeeded() {
        guard frameTrackingEnabled, !isCollapsedState else { return }
        let d = UserDefaults.standard
        d.set(frame.origin.x, forKey: Self.originXKey)
        d.set(frame.origin.y, forKey: Self.originYKey)
        d.set(frame.size.width, forKey: Self.widthKey)
        d.set(frame.size.height, forKey: Self.heightKey)
    }

    static func savedFrame(fittingIn screenFrame: NSRect) -> NSRect? {
        let d = UserDefaults.standard
        guard d.object(forKey: originXKey) != nil else { return nil }
        let width = d.double(forKey: widthKey)
        let height = d.double(forKey: heightKey)
        guard width > 100, height > 100 else { return nil }
        let rect = NSRect(x: d.double(forKey: originXKey), y: d.double(forKey: originYKey), width: width, height: height)
        return screenFrame.intersects(rect) ? rect : nil
    }
}
