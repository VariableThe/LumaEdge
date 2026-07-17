import XCTest
import CoreGraphics
@testable import LumaEdgeCore
@testable import WindowManager

@MainActor
final class LumaEdgePhase3Tests: XCTestCase {
    func testSmartWorkspaceDefaultOptInGuardrail() {
        let manager = SmartWorkspaceManager()
        XCTAssertEqual(manager.globalSafeWorkspaceMode, .off, "Smart Workspace MUST be opt-in and disabled by default (.off)")
    }
    
    func testCalculateSafeAreaFrameAllEdges() {
        let manager = SmartWorkspaceManager()
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        let config = MonitorConfig(
            id: "testScreen",
            segments: [
                EdgeSegment(edge: .top, thickness: 64, isEnabled: true),
                EdgeSegment(edge: .bottom, thickness: 64, isEnabled: true),
                EdgeSegment(edge: .left, thickness: 64, isEnabled: true),
                EdgeSegment(edge: .right, thickness: 64, isEnabled: true)
            ]
        )
        
        // 64 + 8 buffer = 72px inset per edge
        let safeBounds = manager.calculateSafeAreaFrame(for: screenFrame, config: config)
        XCTAssertEqual(safeBounds.minX, 72, accuracy: 0.001)
        XCTAssertEqual(safeBounds.minY, 72, accuracy: 0.001)
        XCTAssertEqual(safeBounds.width, 1920 - 144, accuracy: 0.001)
        XCTAssertEqual(safeBounds.height, 1080 - 144, accuracy: 0.001)
    }
    
    func testCalculateSafeAreaFrameSelectiveEdges() {
        let manager = SmartWorkspaceManager()
        let screenFrame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        
        manager.isInsetLeft = false
        manager.isInsetRight = false
        
        let config = MonitorConfig(
            id: "testScreen",
            segments: [
                EdgeSegment(edge: .top, thickness: 80, isEnabled: true),
                EdgeSegment(edge: .bottom, thickness: 80, isEnabled: true),
                EdgeSegment(edge: .left, thickness: 80, isEnabled: true),
                EdgeSegment(edge: .right, thickness: 80, isEnabled: true)
            ]
        )
        
        // Only top and bottom should be inset (80 + 8 = 88px each)
        let safeBounds = manager.calculateSafeAreaFrame(for: screenFrame, config: config)
        XCTAssertEqual(safeBounds.minX, 0, accuracy: 0.001)
        XCTAssertEqual(safeBounds.width, 2560, accuracy: 0.001)
        XCTAssertEqual(safeBounds.minY, 88, accuracy: 0.001)
        XCTAssertEqual(safeBounds.height, 1440 - 176, accuracy: 0.001)
    }
}
