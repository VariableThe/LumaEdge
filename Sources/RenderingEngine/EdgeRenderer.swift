import SwiftUI
import LumaEdgeCore

public struct EdgeRenderer: View {
    public let config: MonitorConfig
    public let masterOpacity: Double
    
    public init(config: MonitorConfig, masterOpacity: Double = 1.0) {
        self.config = config
        self.masterOpacity = masterOpacity
    }
    
    public var body: some View {
        CanvasEdgeView(config: config, masterOpacity: masterOpacity)
    }
}
