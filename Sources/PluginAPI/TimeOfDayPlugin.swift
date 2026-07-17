import Foundation
import LumaEdgeCore

@MainActor
public final class TimeOfDayPlugin: LumaEdgePlugin {
    public let id = "circadian_rhythm"
    public let name = "Circadian Rhythm Adaptation"
    public let description = "Automatically adjusts edge lighting color temperature throughout the day (5600K daylight at noon -> 2700K warm glow at night)."
    
    public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "LumaEdge_Plugin_\(id)")
            if isEnabled { start() } else { stop() }
        }
    }
    
    private var timer: Timer?
    
    public init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "LumaEdge_Plugin_circadian_rhythm")
    }
    
    public func start() {
        stop()
        guard isEnabled else { return }
        
        applyCircadianKelvin()
        
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyCircadianKelvin()
            }
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    public func applyCircadianKelvin(now: Date = Date()) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let timeInHours = Double(hour) + Double(minute) / 60.0
        
        var targetKelvin: Double = 5600.0
        
        if timeInHours >= 9.0 && timeInHours <= 17.0 {
            targetKelvin = 5600.0
        } else if timeInHours > 17.0 && timeInHours < 21.0 {
            let progress = Double((timeInHours - 17.0) / 4.0)
            targetKelvin = 5600.0 - progress * (5600.0 - 2700.0)
        } else if timeInHours >= 21.0 || timeInHours < 6.0 {
            targetKelvin = 2700.0
        } else if timeInHours >= 6.0 && timeInHours < 9.0 {
            let progress = Double((timeInHours - 6.0) / 3.0)
            targetKelvin = 2700.0 + progress * (5600.0 - 2700.0)
        }
        
        let engine = LightingEngine.shared
        for key in engine.monitorConfigs.keys {
            guard var config = engine.monitorConfigs[key] else { continue }
            for i in 0..<config.segments.count {
                config.segments[i].kelvinTemp = targetKelvin
            }
            engine.monitorConfigs[key] = config
        }
    }
}
