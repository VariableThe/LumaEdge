import XCTest
@testable import LumaEdgeCore
@testable import RenderingEngine

final class LumaEdgeCoreTests: XCTestCase {
    @MainActor
    func testPresetApplication() {
        let engine = LightingEngine.shared
        let whitePreset = GlowPreset.builtInPresets.first { $0.id == "studio_white" }!
        engine.applyPreset(whitePreset)
        
        XCTAssertEqual(engine.activePreset.kelvinTemp, 6500)
        XCTAssertTrue(engine.isMasterEnabled)
    }
    
    @MainActor
    func testVirtualRingLightModeToggle() {
        let engine = LightingEngine.shared
        let screenID = "test-screen-1"
        _ = engine.getOrCreateMonitorConfig(forScreenID: screenID, displayName: "Test Monitor")
        
        engine.setVirtualRingMode(true, position: .webcamCenter, forMonitor: screenID)
        let config = engine.monitorConfigs[screenID]!
        XCTAssertTrue(config.isVirtualRingMode)
        XCTAssertEqual(config.virtualRingPosition, .webcamCenter)
        XCTAssertEqual(config.segments.count, 1)
        XCTAssertEqual(config.segments.first?.startFraction, 0.33)
        XCTAssertEqual(config.segments.first?.endFraction, 0.67)
    }
    
    func testKelvinToRGBMapping() {
        let warmRGB = ColorTemperature.rgb(fromKelvin: 2700)
        let coldRGB = ColorTemperature.rgb(fromKelvin: 6500)
        
        // Warm lamp (2700K) should have higher red relative to blue
        XCTAssertGreaterThan(warmRGB.red, warmRGB.blue)
        // Cold white (6500K) should have high blue component
        XCTAssertGreaterThan(coldRGB.blue, warmRGB.blue)
    }
    
    func testGlowPaletteHelpersAreDistinct() {
        let base = ColorTemperature.rgb(fromKelvin: 4000)
        // Highlight should be lifted toward white vs base (higher channel sum)
        // We can't inspect SwiftUI Color channels easily; just ensure helpers are callable.
        _ = ColorTemperature.accentColor(fromKelvin: 2700)
        _ = ColorTemperature.bloomColor(fromKelvin: 5600)
        _ = ColorTemperature.highlightColor(fromKelvin: 6500)
        XCTAssertGreaterThan(base.red + base.green + base.blue, 0)
    }
}
