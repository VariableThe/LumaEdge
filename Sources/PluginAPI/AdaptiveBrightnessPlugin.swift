import Foundation
import IOKit.ps
import LumaEdgeCore

@MainActor
public final class AdaptiveBrightnessPlugin: LumaEdgePlugin {
    public let id = "adaptive_battery_saver"
    public let name = "Battery Saver Dimming"
    public let description = "Automatically reduces edge lighting brightness when running on battery power to maximize MacBook battery life."
    
    public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "LumaEdge_Plugin_\(id)")
            if isEnabled { start() } else { stop() }
        }
    }
    
    private var timer: Timer?
    
    public init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "LumaEdge_Plugin_adaptive_battery_saver")
    }
    
    public func start() {
        stop()
        guard isEnabled else { return }
        
        evaluatePowerState()
        
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluatePowerState()
            }
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    public func evaluatePowerState() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        var isOnBattery = false
        for ps in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as? [String: Any],
               let state = info[kIOPSPowerSourceStateKey] as? String,
               state == kIOPSBatteryPowerValue {
                isOnBattery = true
                break
            }
        }
        
        let engine = LightingEngine.shared
        let multiplier: Double = isOnBattery ? 0.7 : 1.0
        
        for key in engine.monitorConfigs.keys {
            guard var config = engine.monitorConfigs[key] else { continue }
            for i in 0..<config.segments.count {
                let target = multiplier * engine.activePreset.defaultBrightness
                if abs(config.segments[i].brightness - target) > 0.05 {
                    config.segments[i].brightness = target
                }
            }
            engine.monitorConfigs[key] = config
        }
    }
}
