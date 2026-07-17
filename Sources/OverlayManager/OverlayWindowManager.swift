import AppKit
import Combine
import LumaEdgeCore
import DisplayManager

@MainActor
public final class OverlayWindowManager: ObservableObject {
    public static let shared = OverlayWindowManager()
    
    private var windows: [String: OverlayWindow] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var currentOpacity: Double = 1.0
    
    public init() {
        DisplayController.shared.onScreensChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.rebuildWindows()
            }
            .store(in: &cancellables)
            
        LightingEngine.shared.onOverlayUpdateNeeded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshContent()
            }
            .store(in: &cancellables)
            
        rebuildWindows()
    }
    
    public func rebuildWindows() {
        let screens = DisplayController.shared.screens
        var activeIDs = Set<String>()
        
        for screen in screens {
            let screenID = DisplayController.shared.screenID(for: screen)
            activeIDs.insert(screenID)
            
            if let window = windows[screenID] {
                window.updateFrame(to: screen.frame)
                window.updateContent(opacity: currentOpacity)
                if !window.isVisible && LightingEngine.shared.isEffectivelyIlluminated {
                    window.orderFrontRegardless()
                } else if window.isVisible && !LightingEngine.shared.isEffectivelyIlluminated {
                    window.orderOut(nil)
                }
            } else {
                let window = OverlayWindow(screen: screen, screenID: screenID)
                windows[screenID] = window
                if LightingEngine.shared.isEffectivelyIlluminated {
                    window.orderFrontRegardless()
                }
            }
        }
        
        // Remove disconnected windows
        for (id, window) in windows where !activeIDs.contains(id) {
            window.close()
            windows.removeValue(forKey: id)
        }
    }
    
    public func refreshContent() {
        for window in windows.values {
            // Master toggle = armed; light only shows while camera is active
            if LightingEngine.shared.isEffectivelyIlluminated {
                window.updateContent(opacity: currentOpacity)
                if !window.isVisible {
                    window.orderFrontRegardless()
                }
            } else {
                window.orderOut(nil)
            }
        }
    }
    
    public func setGlobalOpacity(_ opacity: Double, animated: Bool = true) {
        guard abs(currentOpacity - opacity) > 0.01 else { return }
        self.currentOpacity = opacity
        for window in windows.values {
            window.updateContent(opacity: opacity)
        }
    }
    
    public func allWindows() -> [OverlayWindow] {
        Array(windows.values)
    }
}
