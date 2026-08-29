import SwiftUI
import AppKit

/// A transparent view that drags the containing window by its background,
/// scoped to wherever it's placed (the toolbar header) rather than the
/// whole panel.
struct DragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView { DragHandleView() }
    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

final class DragHandleView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
