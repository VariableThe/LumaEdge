import Foundation

public enum ScreenEdge: String, Codable, CaseIterable, Identifiable, Sendable {
    case top = "Top"
    case bottom = "Bottom"
    case left = "Left"
    case right = "Right"
    
    public var id: String { rawValue }
}

public enum VirtualRingPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case webcamCenter = "Webcam Center (Top 50%)"
    case topLeft = "Top Left Corner"
    case topRight = "Top Right Corner"
    case custom = "Custom Segment"
    
    public var id: String { rawValue }
    
    public var defaultSegment: EdgeSegment {
        switch self {
        case .webcamCenter:
            return EdgeSegment(
                id: UUID().uuidString,
                edge: .top,
                startFraction: 0.33,
                endFraction: 0.67,
                thickness: 96,
                kelvinTemp: 5600,
                brightness: 0.88,
                softness: 14,
                bloom: 6,
                isEnabled: true
            )
        case .topLeft:
            return EdgeSegment(
                id: UUID().uuidString,
                edge: .top,
                startFraction: 0.0,
                endFraction: 0.28,
                thickness: 96,
                kelvinTemp: 5600,
                brightness: 0.88,
                softness: 14,
                bloom: 6,
                isEnabled: true
            )
        case .topRight:
            return EdgeSegment(
                id: UUID().uuidString,
                edge: .top,
                startFraction: 0.72,
                endFraction: 1.0,
                thickness: 96,
                kelvinTemp: 5600,
                brightness: 0.88,
                softness: 14,
                bloom: 6,
                isEnabled: true
            )
        case .custom:
            return EdgeSegment(
                id: UUID().uuidString,
                edge: .top,
                startFraction: 0.25,
                endFraction: 0.75,
                thickness: 88,
                kelvinTemp: 5600,
                brightness: 0.82,
                softness: 12,
                bloom: 5,
                isEnabled: true
            )
        }
    }
}

public struct EdgeSegment: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var edge: ScreenEdge
    public var startFraction: Double // 0.0 to 1.0 along the edge
    public var endFraction: Double   // 0.0 to 1.0 along the edge
    public var thickness: Double     // e.g., 10px to 200px
    public var kelvinTemp: Double    // e.g., 2000K to 10000K
    public var colorHex: String?     // Optional RGB hex override if not using pure Kelvin
    public var brightness: Double    // 0.0 to 1.0
    public var softness: Double      // Blur radius in points
    public var bloom: Double         // Inner/Outer glow bloom in points
    public var isEnabled: Bool
    
    public init(
        id: String = UUID().uuidString,
        edge: ScreenEdge,
        startFraction: Double = 0.0,
        endFraction: Double = 1.0,
        thickness: Double = 60,
        kelvinTemp: Double = 5600,
        colorHex: String? = nil,
        brightness: Double = 0.8,
        softness: Double = 20,
        bloom: Double = 12,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.edge = edge
        self.startFraction = max(0.0, min(1.0, startFraction))
        self.endFraction = max(self.startFraction, min(1.0, endFraction))
        self.thickness = max(4.0, min(2000.0, thickness))
        self.kelvinTemp = max(2000.0, min(10000.0, kelvinTemp))
        self.colorHex = colorHex
        self.brightness = max(0.0, min(1.0, brightness))
        self.softness = max(0.0, min(150.0, softness))
        self.bloom = max(0.0, min(100.0, bloom))
        self.isEnabled = isEnabled
    }
    
    public static var defaultTop: EdgeSegment {
        EdgeSegment(edge: .top, startFraction: 0.0, endFraction: 1.0, thickness: 64, kelvinTemp: 5600, brightness: 0.82, softness: 16, bloom: 8, isEnabled: true)
    }
    
    /// Soft fill from below — enabled so the continuous ring path can join all corners.
    public static var defaultBottom: EdgeSegment {
        EdgeSegment(edge: .bottom, startFraction: 0.0, endFraction: 1.0, thickness: 48, kelvinTemp: 5600, brightness: 0.55, softness: 14, bloom: 6, isEnabled: true)
    }
    
    public static var defaultLeft: EdgeSegment {
        EdgeSegment(edge: .left, startFraction: 0.0, endFraction: 1.0, thickness: 56, kelvinTemp: 5600, brightness: 0.72, softness: 14, bloom: 7, isEnabled: true)
    }
    
    public static var defaultRight: EdgeSegment {
        EdgeSegment(edge: .right, startFraction: 0.0, endFraction: 1.0, thickness: 56, kelvinTemp: 5600, brightness: 0.72, softness: 14, bloom: 7, isEnabled: true)
    }
}
