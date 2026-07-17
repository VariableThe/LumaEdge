import AppKit
import SwiftUI
import LumaEdgeCore

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    
    public var isWindowVisible: Bool {
        window?.isVisible == true
    }
    
    public override init() {
        super.init()
    }
    
    public func showWindow() {
        if let win = window {
            LightingEngine.shared.isControlsUIVisible = true
            win.level = .floating
            win.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsTabView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "LumaEdge Settings"
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 600, height: 440)
        // Keep settings above the edge overlay
        newWindow.level = .floating
        
        self.window = newWindow
        LightingEngine.shared.isControlsUIVisible = true
        newWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        LightingEngine.shared.isControlsUIVisible = false
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        LightingEngine.shared.isControlsUIVisible = true
    }
}
