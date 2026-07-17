import XCTest
@testable import LumaEdgeCore
@testable import PluginAPI

@MainActor
final class LumaEdgePhase5Tests: XCTestCase {
    func testBuiltInPluginsRegistered() {
        let registry = PluginRegistry()
        XCTAssertEqual(registry.plugins.count, 2)
        XCTAssertTrue(registry.plugins.contains(where: { $0.id == "circadian_rhythm" }))
        XCTAssertTrue(registry.plugins.contains(where: { $0.id == "adaptive_battery_saver" }))
    }
    
    func testCircadianRhythmAdaptationKelvin() {
        let plugin = TimeOfDayPlugin()
        let engine = LightingEngine.shared
        
        var comp = DateComponents()
        comp.hour = 12 // Noon -> 5600K
        comp.minute = 0
        let noon = Calendar.current.date(from: comp)!
        
        plugin.applyCircadianKelvin(now: noon)
        if let config = engine.monitorConfigs.values.first, let seg = config.segments.first {
            XCTAssertEqual(seg.kelvinTemp, 5600.0, accuracy: 0.1)
        }
        
        comp.hour = 23 // 11 PM -> 2700K
        let night = Calendar.current.date(from: comp)!
        plugin.applyCircadianKelvin(now: night)
        if let config = engine.monitorConfigs.values.first, let seg = config.segments.first {
            XCTAssertEqual(seg.kelvinTemp, 2700.0, accuracy: 0.1)
        }
    }
    
    func testIPCHandlerToggleAndPreset() {
        let registry = PluginRegistry()
        let engine = LightingEngine.shared
        
        engine.isMasterEnabled = false
        registry.handleIPCCommand(jsonString: "{\"action\": \"toggle\"}")
        XCTAssertTrue(engine.isMasterEnabled)
        
        registry.handleIPCCommand(jsonString: "{\"action\": \"preset\", \"presetID\": \"sunset\"}")
        XCTAssertEqual(engine.activePreset.id, "sunset")
    }
}
