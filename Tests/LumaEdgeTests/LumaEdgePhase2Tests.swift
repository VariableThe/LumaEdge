import XCTest
import Combine
import CoreGraphics
@testable import LumaEdgeCore
@testable import AnimationEngine
@testable import ApplicationProfiles

@MainActor
final class LumaEdgePhase2Tests: XCTestCase {
    func testCursorMonitorFarDistanceOpacity() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let mouseLocation = CGPoint(x: 960, y: 540) // Center of screen
        
        let segments = [
            EdgeSegment(edge: .top, isEnabled: true),
            EdgeSegment(edge: .bottom, isEnabled: true),
            EdgeSegment(edge: .left, isEnabled: true),
            EdgeSegment(edge: .right, isEnabled: true)
        ]
        
        let multiplier = CursorMonitor.calculateOpacityMultiplier(
            mouseLocation: mouseLocation,
            screenFrame: screenFrame,
            segments: segments,
            fadeDistance: 120.0,
            minOpacity: 0.18
        )
        
        XCTAssertEqual(multiplier, 1.0, accuracy: 0.001, "Cursor far from all borders should yield 1.0 multiplier")
    }
    
    func testCursorMonitorNearBorderOpacity() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let mouseLocation = CGPoint(x: 960, y: 1075) // 5px below top border
        
        let segments = [
            EdgeSegment(edge: .top, isEnabled: true)
        ]
        
        let multiplier = CursorMonitor.calculateOpacityMultiplier(
            mouseLocation: mouseLocation,
            screenFrame: screenFrame,
            segments: segments,
            fadeDistance: 120.0,
            minOpacity: 0.20
        )
        
        XCTAssertEqual(multiplier, 0.20, accuracy: 0.001, "Cursor near top border <= 24px should yield minOpacity")
    }
    
    func testCursorMonitorSmoothstepMidFade() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let mouseLocation = CGPoint(x: 960, y: 1008) // 72px below top border (halfway between 24 and 120)
        
        let segments = [
            EdgeSegment(edge: .top, isEnabled: true)
        ]
        
        let multiplier = CursorMonitor.calculateOpacityMultiplier(
            mouseLocation: mouseLocation,
            screenFrame: screenFrame,
            segments: segments,
            fadeDistance: 120.0,
            minOpacity: 0.20
        )
        
        XCTAssertGreaterThan(multiplier, 0.20)
        XCTAssertLessThan(multiplier, 1.0)
        XCTAssertEqual(multiplier, 0.60, accuracy: 0.05, "Halfway smoothstep should be approximately 0.60")
    }
    
    func testCursorMonitorIgnoresDisabledEdges() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        // Cursor near left border (10px from minX)
        let mouseLocation = CGPoint(x: 10, y: 540)
        
        // Left border disabled, only top enabled
        let segments = [
            EdgeSegment(edge: .top, isEnabled: true),
            EdgeSegment(edge: .left, isEnabled: false)
        ]
        
        let multiplier = CursorMonitor.calculateOpacityMultiplier(
            mouseLocation: mouseLocation,
            screenFrame: screenFrame,
            segments: segments,
            fadeDistance: 120.0,
            minOpacity: 0.18
        )
        
        XCTAssertEqual(multiplier, 1.0, accuracy: 0.001, "Cursor near disabled left border should not trigger opacity dimming")
    }
    
    func testAppProfilesDefaultAndApplication() {
        let manager = LightingProfilesManager()
        let engine = LightingEngine.shared
        
        XCTAssertGreaterThanOrEqual(manager.profiles.count, 4)
        guard let zoomProfile = manager.profiles.first(where: { $0.bundleID == "us.zoom.xos" }) else {
            XCTFail("Default Zoom profile not found")
            return
        }
        
        // Set initial preset to warm_lamp
        if let warm = GlowPreset.builtInPresets.first(where: { $0.id == "warm_lamp" }) {
            engine.applyPreset(warm)
        }
        
        // Apply Zoom profile
        manager.applyProfile(zoomProfile)
        XCTAssertEqual(engine.activePreset.id, "daylight", "Applying Zoom profile should switch preset to daylight")
        XCTAssertEqual(manager.activeTriggeredProfile?.id, zoomProfile.id)
        
        // Revert profile
        manager.revertProfile()
        XCTAssertEqual(engine.activePreset.id, "warm_lamp", "Reverting profile should restore previous warm_lamp preset")
        XCTAssertNil(manager.activeTriggeredProfile)
    }
}
