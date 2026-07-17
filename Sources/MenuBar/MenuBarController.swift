import AppKit
import SwiftUI
import LumaEdgeCore
import Settings

@MainActor
public final class MenuBarController: NSObject, NSPopoverDelegate {
    public static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsController: SettingsWindowController?
    
    public override init() {
        super.init()
        setupStatusItem()
        setupPopover()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "LumaEdge")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 320)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        
        let menuBarView = MenuBarView(
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.showSettings()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        
        popover.contentViewController = NSHostingController(rootView: menuBarView)
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                // Dim edge light *before* the popover appears so controls aren't washed out
                LightingEngine.shared.isControlsUIVisible = true
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                if let popoverWindow = popover.contentViewController?.view.window {
                    // Ensure the control UI stacks above any residual overlay glow
                    popoverWindow.level = .popUpMenu
                    popoverWindow.makeKey()
                }
            }
        }
    }
    
    public func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        LightingEngine.shared.isControlsUIVisible = true
        settingsController?.showWindow()
    }
    
    // MARK: - NSPopoverDelegate
    
    public func popoverDidShow(_ notification: Notification) {
        LightingEngine.shared.isControlsUIVisible = true
        if let popoverWindow = popover.contentViewController?.view.window {
            popoverWindow.level = .popUpMenu
        }
    }
    
    public func popoverDidClose(_ notification: Notification) {
        // Keep dimmed if settings window is still open
        let settingsOpen = settingsController?.isWindowVisible == true
        LightingEngine.shared.isControlsUIVisible = settingsOpen
    }
}
