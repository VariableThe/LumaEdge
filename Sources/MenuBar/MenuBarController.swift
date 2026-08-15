import AppKit
import Combine
import SwiftUI
import LumaEdgeCore
import Settings

@MainActor
public final class MenuBarController: NSObject, NSPopoverDelegate {
    public static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        LightingEngine.shared.onOverlayUpdateNeeded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
        updateStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = statusImage(named: "sun.max.fill")
            button.imagePosition = .imageOnly
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 360)
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

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let engine = LightingEngine.shared
        let imageName = engine.isEffectivelyIlluminated ? "sun.max.fill" : "sun.max"
        button.image = statusImage(named: imageName)
        button.contentTintColor = nil

        if !engine.isMasterEnabled {
            button.toolTip = "LumaEdge is off"
        } else if engine.isCameraActive {
            button.toolTip = "LumaEdge is active for your camera"
        } else {
            button.toolTip = "LumaEdge is armed for your next call"
        }
    }

    private func statusImage(named symbolName: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        guard let symbol = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "LumaEdge"
        )?.withSymbolConfiguration(configuration) else {
            return nil
        }

        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
            symbol.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)

            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setBlendMode(.sourceIn)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(bounds)
            return true
        }
        image.isTemplate = false
        return image
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
