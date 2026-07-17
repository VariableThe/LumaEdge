import SwiftUI
import LumaEdgeCore
import RenderingEngine

public struct OverlayHostView: View {
    let screenID: String
    @ObservedObject var engine = LightingEngine.shared
    let currentOpacity: Double
    
    public init(screenID: String, currentOpacity: Double = 1.0) {
        self.screenID = screenID
        self.currentOpacity = currentOpacity
    }
    
    public var body: some View {
        // Armed (master) + camera active only — no glow when webcam is idle
        if let config = engine.monitorConfigs[screenID],
           config.isEnabled,
           engine.isEffectivelyIlluminated {
            let cursorMultiplier = engine.cursorOpacityMultipliers[screenID] ?? 1.0
            let chromeMultiplier = engine.controlsUIOpacityMultiplier
            EdgeRenderer(
                config: config,
                masterOpacity: currentOpacity * cursorMultiplier * chromeMultiplier
            )
        } else {
            Color.clear.allowsHitTesting(false)
        }
    }
}
