import AppKit
import SwiftUI
import LumaEdgeCore

public final class OverlayWindow: NSPanel {
    public let screenID: String
    private var hostingView: NSHostingView<OverlayHostView>?
    
    public init(screen: NSScreen, screenID: String) {
        self.screenID = screenID
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Sit above normal app windows but *below* menu bar popovers / status menus
        // so brightness/preset controls stay readable and clickable.
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 2)
        self.ignoresMouseEvents = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        
        // Ensure colorSpace can show DisplayP3 / wide-gamut glow
        if let p3Space = NSColorSpace(cgColorSpace: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()) {
            self.colorSpace = p3Space
        }
        
        self.animationBehavior = .none
        self.identifier = NSUserInterfaceItemIdentifier(screenID)
        
        updateContent(opacity: 1.0)
    }
    
    public func updateFrame(to screenFrame: NSRect) {
        if self.frame != screenFrame {
            self.setFrame(screenFrame, display: true)
        }
    }
    
    public func updateContent(opacity: Double = 1.0) {
        let rootView = OverlayHostView(screenID: screenID, currentOpacity: opacity)
        if let existing = hostingView {
            existing.rootView = rootView
        } else {
            let host = NSHostingView(rootView: rootView)
            host.frame = self.contentRect(forFrameRect: self.frame)
            host.autoresizingMask = [.width, .height]
            // Layer-backed hosting for additive (.plusLighter) multi-blur stacks
            host.wantsLayer = true
            host.layer?.isOpaque = false
            host.layer?.backgroundColor = NSColor.clear.cgColor
            self.contentView = host
            self.hostingView = host
        }
    }
}
