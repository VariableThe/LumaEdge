import AppKit
import LumaEdgeCore
import DisplayManager
import OverlayManager
import MenuBar
import Settings
import AnimationEngine
import CameraDetection
import ApplicationProfiles
import WindowManager
import AccessibilityManager
import PluginAPI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a clean accessory / menu bar app (no Dock icon unless preferences open)
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Initialize Core Orchestration & Display management
        _ = DisplayController.shared
        _ = OverlayWindowManager.shared
        _ = MenuBarController.shared
        
        // Initialize Phase 2 automation monitors
        CursorMonitor.shared.startMonitoring()
        // Always monitor webcam — edge light is gated by camera activity
        CameraMicDetector.shared.startMonitoring()
        _ = LightingProfilesManager.shared
        
        // Initialize Phase 3 & Phase 4 workspace guardrails and region carver
        _ = SmartWorkspaceManager.shared
        _ = RegionCarver.shared
        
        // Initialize Phase 5 plugins & IPC registry
        _ = PluginRegistry.shared
        
        // Register custom URL scheme handler (lumaedge://)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        
        // Trigger initial render
        LightingEngine.shared.onOverlayUpdateNeeded.send()
    }
    
    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "lumaedge" else {
            return
        }
        
        let host = url.host?.lowercased() ?? ""
        let engine = LightingEngine.shared
        
        switch host {
        case "toggle":
            engine.isMasterEnabled.toggle()
        case "on":
            engine.isMasterEnabled = true
        case "off":
            engine.isMasterEnabled = false
        case "preset":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let presetID = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let preset = GlowPreset.builtInPresets.first(where: { $0.id == presetID }) {
                engine.applyPreset(preset)
            }
        case "brightness":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let valStr = components.queryItems?.first(where: { $0.name == "value" })?.value,
               let val = Double(valStr) {
                for key in engine.monitorConfigs.keys {
                    guard var config = engine.monitorConfigs[key] else { continue }
                    for i in 0..<config.segments.count {
                        config.segments[i].brightness = Double(max(0.0, min(1.0, val)))
                    }
                    engine.monitorConfigs[key] = config
                }
            }
        case "width", "thickness":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let valStr = components.queryItems?.first(where: { $0.name == "value" })?.value,
               let val = Double(valStr) {
                for key in engine.monitorConfigs.keys {
                    guard var config = engine.monitorConfigs[key] else { continue }
                    for i in 0..<config.segments.count {
                        config.segments[i].thickness = Double(max(16.0, min(400.0, val)))
                    }
                    engine.monitorConfigs[key] = config
                }
            }
        default:
            break
        }
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
