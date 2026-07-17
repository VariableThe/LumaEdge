import AppKit
import Combine
import LumaEdgeCore

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

public struct WindowSnapshot: Equatable, Sendable {
    public let windowID: CGWindowID
    public let pid: pid_t
    public let originalFrame: CGRect
    public let timestamp: Date
    
    public init(windowID: CGWindowID, pid: pid_t, originalFrame: CGRect, timestamp: Date = Date()) {
        self.windowID = windowID
        self.pid = pid
        self.originalFrame = originalFrame
        self.timestamp = timestamp
    }
}

@MainActor
public final class SmartWorkspaceManager: ObservableObject {
    public static let shared = SmartWorkspaceManager()
    
    @Published public var globalSafeWorkspaceMode: SafeWorkspaceMode = .off {
        didSet {
            UserDefaults.standard.set(globalSafeWorkspaceMode.rawValue, forKey: "LumaEdge_GlobalSafeWorkspaceMode")
            updateWorkspaceInsets()
        }
    }
    
    @Published public var isInsetTop: Bool = true
    @Published public var isInsetBottom: Bool = true
    @Published public var isInsetLeft: Bool = true
    @Published public var isInsetRight: Bool = true
    
    private var activeSnapshots: [CGWindowID: WindowSnapshot] = [:]
    private let engine = LightingEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        if let savedModeStr = UserDefaults.standard.string(forKey: "LumaEdge_GlobalSafeWorkspaceMode"),
           let mode = SafeWorkspaceMode(rawValue: savedModeStr) {
            self.globalSafeWorkspaceMode = mode
        }
        setupObservers()
    }
    
    private func setupObservers() {
        engine.$isMasterEnabled
            .combineLatest(engine.$isCameraActive)
            .sink { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    if self?.engine.isEffectivelyIlluminated == true {
                        self?.updateWorkspaceInsets()
                    } else {
                        self?.revertAllSnapshots()
                    }
                }
            }
            .store(in: &cancellables)
            
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    if self?.globalSafeWorkspaceMode == .currentAppOnly && self?.engine.isEffectivelyIlluminated == true {
                        self?.updateWorkspaceInsets()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    public func updateWorkspaceInsets() {
        guard engine.isEffectivelyIlluminated, globalSafeWorkspaceMode != .off else {
            revertAllSnapshots()
            return
        }
        
        for screen in NSScreen.screens {
            let screenID = screenIDFor(screen)
            guard let config = engine.monitorConfigs[screenID], config.isEnabled else { continue }
            
            let safeBounds = calculateSafeAreaFrame(for: screen.frame, config: config)
            
            if globalSafeWorkspaceMode == .currentAppOnly {
                if let frontApp = NSWorkspace.shared.frontmostApplication {
                    insetWindows(forPID: frontApp.processIdentifier, safeBounds: safeBounds, screenFrame: screen.frame)
                }
            } else if globalSafeWorkspaceMode == .allSupportedApps || globalSafeWorkspaceMode == .alwaysOn {
                for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                    insetWindows(forPID: app.processIdentifier, safeBounds: safeBounds, screenFrame: screen.frame)
                }
            }
        }
    }
    
    public func revertAllSnapshots() {
        guard !activeSnapshots.isEmpty else { return }
        
        for snapshot in activeSnapshots.values {
            let appElem = AXUIElementCreateApplication(snapshot.pid)
            var windowsValue: AnyObject?
            if AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &windowsValue) == .success,
               let windows = windowsValue as? [AXUIElement] {
                for win in windows {
                    if getWindowID(win) == snapshot.windowID {
                        setWindowFrame(win, to: snapshot.originalFrame)
                        break
                    }
                }
            }
        }
        activeSnapshots.removeAll()
    }
    
    public func calculateSafeAreaFrame(for screenFrame: CGRect, config: MonitorConfig) -> CGRect {
        var topInset: CGFloat = 0
        var bottomInset: CGFloat = 0
        var leftInset: CGFloat = 0
        var rightInset: CGFloat = 0
        
        for seg in config.segments where seg.isEnabled {
            switch seg.edge {
            case .top:
                if isInsetTop { topInset = max(topInset, CGFloat(seg.thickness) + 8.0) }
            case .bottom:
                if isInsetBottom { bottomInset = max(bottomInset, CGFloat(seg.thickness) + 8.0) }
            case .left:
                if isInsetLeft { leftInset = max(leftInset, CGFloat(seg.thickness) + 8.0) }
            case .right:
                if isInsetRight { rightInset = max(rightInset, CGFloat(seg.thickness) + 8.0) }
            }
        }
        
        return CGRect(
            x: screenFrame.minX + leftInset,
            y: screenFrame.minY + bottomInset,
            width: max(100, screenFrame.width - leftInset - rightInset),
            height: max(100, screenFrame.height - topInset - bottomInset)
        )
    }
    
    private func insetWindows(forPID pid: pid_t, safeBounds: CGRect, screenFrame: CGRect) {
        let appElem = AXUIElementCreateApplication(pid)
        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return
        }
        
        for win in windows {
            guard isWindowSafeToMove(win) else { continue }
            
            guard let currentFrame = getWindowFrame(win) else { continue }
            let center = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
            guard screenFrame.contains(center) else { continue }
            
            if let winID = getWindowID(win) {
                if activeSnapshots[winID] == nil {
                    activeSnapshots[winID] = WindowSnapshot(windowID: winID, pid: pid, originalFrame: currentFrame)
                }
            }
            
            var targetX = currentFrame.minX
            var targetY = currentFrame.minY
            var targetW = currentFrame.width
            var targetH = currentFrame.height
            
            if targetW > safeBounds.width { targetW = safeBounds.width }
            if targetH > safeBounds.height { targetH = safeBounds.height }
            if targetX < safeBounds.minX { targetX = safeBounds.minX }
            if targetY < safeBounds.minY { targetY = safeBounds.minY }
            if targetX + targetW > safeBounds.maxX { targetX = safeBounds.maxX - targetW }
            if targetY + targetH > safeBounds.maxY { targetY = safeBounds.maxY - targetH }
            
            let targetFrame = CGRect(x: targetX, y: targetY, width: targetW, height: targetH)
            if abs(targetFrame.minX - currentFrame.minX) > 1 || abs(targetFrame.minY - currentFrame.minY) > 1 ||
                abs(targetFrame.width - currentFrame.width) > 1 || abs(targetFrame.height - currentFrame.height) > 1 {
                setWindowFrame(win, to: targetFrame)
            }
        }
    }
    
    public func isWindowSafeToMove(_ window: AXUIElement) -> Bool {
        var fsVal: AnyObject?
        if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fsVal) == .success,
           let isFS = fsVal as? Bool, isFS {
            return false
        }
        
        var minVal: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minVal) == .success,
           let isMin = minVal as? Bool, isMin {
            return false
        }
        
        var roleVal: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleVal) == .success,
           let role = roleVal as? String, role != kAXWindowRole {
            return false
        }
        
        var subroleVal: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleVal) == .success,
           let subrole = subroleVal as? String {
            if subrole == kAXFloatingWindowSubrole || subrole == kAXDialogSubrole || subrole == kAXSystemDialogSubrole {
                return false
            }
        }
        
        var modalVal: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXModalAttribute as CFString, &modalVal) == .success,
           let isModal = modalVal as? Bool, isModal {
            return false
        }
        
        return true
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
    
    private func setWindowFrame(_ window: AXUIElement, to frame: CGRect) {
        var point = frame.origin
        var size = frame.size
        if let posValue = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }
    
    private func getWindowID(_ window: AXUIElement) -> CGWindowID? {
        var cgID: CGWindowID = 0
        let err = _AXUIElementGetWindow(window, &cgID)
        return err == .success ? cgID : nil
    }
    
    private func screenIDFor(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return "unknown"
        }
        return "\(number.uint32Value)"
    }
}
