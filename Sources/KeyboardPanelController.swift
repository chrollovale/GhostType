import AppKit
import SwiftUI

// MARK: - Non-Activating Panel
// This panel subclass prevents focus stealing when the user clicks virtual keys.
// Focus stays on the target app (e.g., Parallels VM), so keystrokes land there.
final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // Accept mouse events even though we're not key window
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .leftMouseUp {
            super.sendEvent(event)
            return
        }
        super.sendEvent(event)
    }
}

// MARK: - Keyboard Panel Controller
@MainActor
final class KeyboardPanelController: ObservableObject {
    static let shared = KeyboardPanelController()

    @Published var isVisible = false
    private var panel: NonActivatingPanel?

    func toggle() {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFront(nil)
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    private func createPanel() {
        let keyboardView = VirtualKeyboardView()
        let hostingView = NSHostingView(rootView: keyboardView)
        hostingView.setFrameSize(hostingView.intrinsicContentSize)

        let contentSize = hostingView.intrinsicContentSize
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        // Position at the bottom center of the screen
        let panelOrigin = NSPoint(
            x: screenFrame.midX - contentSize.width / 2,
            y: screenFrame.minY
        )

        let p = NonActivatingPanel(
            contentRect: NSRect(origin: panelOrigin, size: contentSize),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        p.contentView = hostingView
        p.title = "Virtual Keyboard"
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .visible
        p.level = .floating
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.animationBehavior = .utilityWindow
        p.isReleasedWhenClosed = false
        p.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)

        // Observe close button to update isVisible
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: p,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isVisible = false
            }
        }

        panel = p
    }
}
