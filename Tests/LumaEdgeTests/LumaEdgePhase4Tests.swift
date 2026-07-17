import XCTest
@testable import LumaEdgeCore
@testable import AccessibilityManager

@MainActor
final class LumaEdgePhase4Tests: XCTestCase {
    func testCarveSegmentSingleCutout() {
        let preset = GlowPreset.builtInPresets[0]
        let cutout = KnownAppCutout(
            bundleID: "us.zoom.xos",
            appName: "Zoom Bar",
            edge: .bottom,
            startFraction: 0.35,
            endFraction: 0.65
        )
        
        let carved = RegionCarver.carveSegment(edge: .bottom, cutouts: [cutout], preset: preset)
        XCTAssertEqual(carved.count, 2, "Carving around a center cutout on bottom border should split into 2 segments")
        
        XCTAssertEqual(carved[0].startFraction, 0.0, accuracy: 0.001)
        XCTAssertEqual(carved[0].endFraction, 0.35, accuracy: 0.001)
        
        XCTAssertEqual(carved[1].startFraction, 0.65, accuracy: 0.001)
        XCTAssertEqual(carved[1].endFraction, 1.0, accuracy: 0.001)
    }
    
    func testCarveSegmentOverlappingCutouts() {
        let preset = GlowPreset.builtInPresets[0]
        let cut1 = KnownAppCutout(bundleID: "app1", appName: "App 1", edge: .top, startFraction: 0.30, endFraction: 0.50)
        let cut2 = KnownAppCutout(bundleID: "app2", appName: "App 2", edge: .top, startFraction: 0.45, endFraction: 0.70)
        
        let carved = RegionCarver.carveSegment(edge: .top, cutouts: [cut1, cut2], preset: preset)
        XCTAssertEqual(carved.count, 2, "Overlapping cutouts [0.3..0.5] and [0.45..0.7] should merge into [0.3..0.7]")
        
        XCTAssertEqual(carved[0].startFraction, 0.0, accuracy: 0.001)
        XCTAssertEqual(carved[0].endFraction, 0.30, accuracy: 0.001)
        
        XCTAssertEqual(carved[1].startFraction, 0.70, accuracy: 0.001)
        XCTAssertEqual(carved[1].endFraction, 1.0, accuracy: 0.001)
    }
    
    func testBuiltInCutoutsPreCalibratedApps() {
        let cutouts = KnownAppCutout.builtInCutouts
        let bundleIDs = Set(cutouts.map { $0.bundleID })
        XCTAssertTrue(bundleIDs.contains("us.zoom.xos"))
        XCTAssertTrue(bundleIDs.contains("com.google.Chrome"))
        XCTAssertTrue(bundleIDs.contains("com.apple.FaceTime"))
        XCTAssertTrue(bundleIDs.contains("com.microsoft.teams2"))
        XCTAssertTrue(bundleIDs.contains("com.obsproject.obs-studio"))
    }
    
    func testAvoidanceLayersOrder() {
        let layers = AvoidanceLayer.allCases
        XCTAssertEqual(layers.count, 4)
        XCTAssertEqual(layers[0], .accessibilityAPI)
        XCTAssertEqual(layers[1], .knownLayouts)
        XCTAssertEqual(layers[2], .cursorFading)
        XCTAssertEqual(layers[3], .safeWorkspace)
    }
}
