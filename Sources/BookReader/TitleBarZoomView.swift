import SwiftUI
import AppKit

/// Invisible view that installs an event monitor for double-clicks in the window's title bar
/// (the strip with the red/yellow/green traffic lights). Does not capture hits or block the back button.
final class TitleBarDoubleClickMonitorView: NSView {
    private var monitor: Any?
    private static var savedFrame: NSRect?
    
    override var acceptsFirstResponder: Bool { false }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMonitor()
        } else {
            removeMonitor()
        }
    }
    
    private func installMonitor() {
        guard monitor == nil, let win = window else { return }
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, event.window === win, event.clickCount == 2 else {
                return event
            }
            // Title bar = top ~28pt of window (traffic lights). Content view origin is bottom-left.
            guard let contentView = win.contentView else { return event }
            let topBarHeight: CGFloat = 28
            let inTitleBar = event.locationInWindow.y >= contentView.frame.height - topBarHeight
            
            if inTitleBar {
                self.performZoom(on: win)
                return nil  // Consume event
            }
            return event
        }
    }
    
    private func removeMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
    
    private func performZoom(on win: NSWindow) {
        guard let screen = win.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let current = win.frame
        let zoomThreshold: CGFloat = 20
        let isZoomed = current.origin.x <= visible.origin.x + zoomThreshold
            && current.origin.y <= visible.origin.y + zoomThreshold
            && current.width >= visible.width - zoomThreshold
            && current.height >= visible.height - zoomThreshold
        
        if isZoomed, let restore = Self.savedFrame {
            win.setFrame(restore, display: true, animate: true)
            Self.savedFrame = nil
        } else {
            Self.savedFrame = current
            win.setFrame(visible, display: true, animate: true)
        }
    }
    
    deinit {
        removeMonitor()
    }
}

struct TitleBarDoubleClickMonitor: NSViewRepresentable {
    func makeNSView(context: Context) -> TitleBarDoubleClickMonitorView {
        let v = TitleBarDoubleClickMonitorView()
        v.wantsLayer = false
        return v
    }
    func updateNSView(_ nsView: TitleBarDoubleClickMonitorView, context: Context) {}
}
