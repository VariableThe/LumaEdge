import AppKit
import Combine
import LumaEdgeCore

@MainActor
public final class CursorMonitor: ObservableObject {
    public static let shared = CursorMonitor()
    
    private var timer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let engine = LightingEngine.shared
    
    public init() {}
    
    public func startMonitoring() {
        stopMonitoring()
        
        // 60Hz polling to ensure smooth transitions when cursor moves or stops
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCursorOpacity()
            }
        }
        
        // Also register for mouse events to react instantly
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCursorOpacity()
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.updateCursorOpacity()
            }
            return event
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    public func updateCursorOpacity() {
        guard engine.isEffectivelyIlluminated && engine.isCursorFadingEnabled else {
            for key in engine.monitorConfigs.keys {
                if engine.cursorOpacityMultipliers[key] != 1.0 {
                    engine.cursorOpacityMultipliers[key] = 1.0
                }
            }
            return
        }
        
        let mouseLoc = NSEvent.mouseLocation
        let fadeDistance = engine.cursorFadeDistance
        let minOpacity = engine.cursorMinOpacity
        
        for screen in NSScreen.screens {
            let screenID = screenIDFor(screen)
            guard let config = engine.monitorConfigs[screenID], config.isEnabled else { continue }
            
            let multiplier = Self.calculateOpacityMultiplier(
                mouseLocation: mouseLoc,
                screenFrame: screen.frame,
                segments: config.segments,
                fadeDistance: fadeDistance,
                minOpacity: minOpacity
            )
            
            // Only update if changed significantly (avoid unnecessary redraws)
            let current = engine.cursorOpacityMultipliers[screenID] ?? 1.0
            if abs(current - multiplier) > 0.005 {
                engine.cursorOpacityMultipliers[screenID] = multiplier
            }
        }
    }
    
    private func screenIDFor(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return "unknown"
        }
        return "\(number.uint32Value)"
    }
    
    /// Pure, static helper function for calculating opacity multiplier based on distance to active border segments.
    public static func calculateOpacityMultiplier(
        mouseLocation: CGPoint,
        screenFrame: CGRect,
        segments: [EdgeSegment],
        fadeDistance: Double,
        minOpacity: Double
    ) -> Double {
        guard fadeDistance > 0 else { return 1.0 }
        
        var minDistance: Double = .greatestFiniteMagnitude
        
        for segment in segments where segment.isEnabled {
            let dist = distanceToSegment(mouseLocation: mouseLocation, screenFrame: screenFrame, segment: segment)
            if dist < minDistance {
                minDistance = dist
            }
        }
        
        guard minDistance < .greatestFiniteMagnitude else { return 1.0 }
        
        // If distance > fadeDistance, 100% opacity.
        // If distance <= innerBuffer (near border), minimum opacity.
        let innerBuffer = 24.0
        if minDistance >= fadeDistance {
            return 1.0
        } else if minDistance <= innerBuffer {
            return minOpacity
        } else {
            let t = (minDistance - innerBuffer) / (fadeDistance - innerBuffer)
            // Smoothstep curve for elegant fading
            let smoothT = t * t * (3.0 - 2.0 * t)
            return minOpacity + (1.0 - minOpacity) * smoothT
        }
    }
    
    public static func distanceToSegment(
        mouseLocation: CGPoint,
        screenFrame: CGRect,
        segment: EdgeSegment
    ) -> Double {
        let x = mouseLocation.x
        let y = mouseLocation.y
        let sx = screenFrame.minX
        let sy = screenFrame.minY
        let w = screenFrame.width
        let h = screenFrame.height
        
        switch segment.edge {
        case .top:
            let segMinX = sx + segment.startFraction * w
            let segMaxX = sx + segment.endFraction * w
            let edgeY = sy + h
            if x >= segMinX && x <= segMaxX {
                return abs(edgeY - y)
            } else if x < segMinX {
                return hypot(segMinX - x, edgeY - y)
            } else {
                return hypot(x - segMaxX, edgeY - y)
            }
            
        case .bottom:
            let segMinX = sx + segment.startFraction * w
            let segMaxX = sx + segment.endFraction * w
            let edgeY = sy
            if x >= segMinX && x <= segMaxX {
                return abs(y - edgeY)
            } else if x < segMinX {
                return hypot(segMinX - x, y - edgeY)
            } else {
                return hypot(x - segMaxX, y - edgeY)
            }
            
        case .left:
            let segMinY = sy + segment.startFraction * h
            let segMaxY = sy + segment.endFraction * h
            let edgeX = sx
            if y >= segMinY && y <= segMaxY {
                return abs(x - edgeX)
            } else if y < segMinY {
                return hypot(x - edgeX, segMinY - y)
            } else {
                return hypot(x - edgeX, y - segMaxY)
            }
            
        case .right:
            let segMinY = sy + segment.startFraction * h
            let segMaxY = sy + segment.endFraction * h
            let edgeX = sx + w
            if y >= segMinY && y <= segMaxY {
                return abs(edgeX - x)
            } else if y < segMinY {
                return hypot(edgeX - x, segMinY - y)
            } else {
                return hypot(edgeX - x, y - segMaxY)
            }
        }
    }
}
