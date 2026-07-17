import AppKit
import CoreGraphics
import LumaEdgeCore

@MainActor
public final class AXUIInspector {
    public static let shared = AXUIInspector()
    
    public init() {}
    
    /// Scans frontmost regular application windows for floating subroles or dialog panels near border edges and returns discovered cutouts.
    public func discoverFloatingCutouts(on screenFrame: CGRect) -> [KnownAppCutout] {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.activationPolicy == .regular else {
            return []
        }
        
        let pid = frontApp.processIdentifier
        let appElem = AXUIElementCreateApplication(pid)
        var windowsValue: AnyObject?
        
        guard AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return []
        }
        
        var discovered: [KnownAppCutout] = []
        let appName = frontApp.localizedName ?? "Application"
        let bundleID = frontApp.bundleIdentifier ?? "unknown"
        
        for win in windows {
            // Check if window is floating or dialog
            var subroleVal: AnyObject?
            if AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &subroleVal) == .success,
               let subrole = subroleVal as? String {
                if subrole == kAXFloatingWindowSubrole || subrole == kAXDialogSubrole || subrole == kAXSystemDialogSubrole {
                    if let frame = getWindowFrame(win) {
                        if let cutout = calculateCutout(from: frame, screenFrame: screenFrame, bundleID: bundleID, appName: "\(appName) Floating Panel") {
                            discovered.append(cutout)
                        }
                    }
                }
            }
        }
        
        return discovered
    }
    
    private func calculateCutout(from frame: CGRect, screenFrame: CGRect, bundleID: String, appName: String) -> KnownAppCutout? {
        // Only trigger if floating window intersects or approaches within 64px of a border edge
        let topDistance = abs(frame.maxY - screenFrame.maxY)
        let bottomDistance = abs(frame.minY - screenFrame.minY)
        let leftDistance = abs(frame.minX - screenFrame.minX)
        let rightDistance = abs(frame.maxX - screenFrame.maxX)
        
        if bottomDistance < 64 {
            let start = max(0.0, Double((frame.minX - screenFrame.minX) / screenFrame.width))
            let end = min(1.0, Double((frame.maxX - screenFrame.minX) / screenFrame.width))
            return KnownAppCutout(bundleID: bundleID, appName: appName, edge: .bottom, startFraction: start, endFraction: end)
        } else if topDistance < 64 {
            let start = max(0.0, Double((frame.minX - screenFrame.minX) / screenFrame.width))
            let end = min(1.0, Double((frame.maxX - screenFrame.minX) / screenFrame.width))
            return KnownAppCutout(bundleID: bundleID, appName: appName, edge: .top, startFraction: start, endFraction: end)
        } else if leftDistance < 64 {
            let start = max(0.0, Double((frame.minY - screenFrame.minY) / screenFrame.height))
            let end = min(1.0, Double((frame.maxY - screenFrame.minY) / screenFrame.height))
            return KnownAppCutout(bundleID: bundleID, appName: appName, edge: .left, startFraction: start, endFraction: end)
        } else if rightDistance < 64 {
            let start = max(0.0, Double((frame.minY - screenFrame.minY) / screenFrame.height))
            let end = min(1.0, Double((frame.maxY - screenFrame.minY) / screenFrame.height))
            return KnownAppCutout(bundleID: bundleID, appName: appName, edge: .right, startFraction: start, endFraction: end)
        }
        
        return nil
    }
    
    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var posVal: AnyObject?
        var sizeVal: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posVal) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeVal) == .success else {
            return nil
        }
        
        var point = CGPoint.zero
        var size = CGSize.zero
        guard let posValue = posVal as! AXValue?, AXValueGetValue(posValue, .cgPoint, &point),
              let sizeValue = sizeVal as! AXValue?, AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }
}
