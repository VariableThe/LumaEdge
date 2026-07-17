import SwiftUI
import LumaEdgeCore

// MARK: - Public entry

public struct CanvasEdgeView: View {
    public let config: MonitorConfig
    public let masterOpacity: Double
    
    public init(config: MonitorConfig, masterOpacity: Double = 1.0) {
        self.config = config
        self.masterOpacity = masterOpacity
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let opacity = masterOpacity * config.brightnessScale
            ZStack {
                if config.isEnabled && opacity > 0.01 {
                    if config.isVirtualRingMode {
                        ForEach(enabledSegments) { segment in
                            SoftSegmentGlow(
                                segment: segment,
                                screenSize: geometry.size,
                                masterOpacity: opacity
                            )
                        }
                    } else if isContinuousFullFrame {
                        ContinuousFrameGlow(
                            segments: enabledSegments,
                            screenSize: geometry.size,
                            masterOpacity: opacity
                        )
                    } else {
                        ForEach(enabledSegments) { segment in
                            SoftSegmentGlow(
                                segment: segment,
                                screenSize: geometry.size,
                                masterOpacity: opacity
                            )
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
        }
        .allowsHitTesting(false)
    }
    
    private var enabledSegments: [EdgeSegment] {
        config.segments.filter(\.isEnabled)
    }
    
    private var isContinuousFullFrame: Bool {
        let edges = Set(enabledSegments.map(\.edge))
        guard edges.count == 4,
              edges.contains(.top), edges.contains(.bottom),
              edges.contains(.left), edges.contains(.right) else {
            return false
        }
        return enabledSegments.allSatisfy { seg in
            seg.startFraction <= 0.02 && seg.endFraction >= 0.98
        }
    }
}

// MARK: - Continuous full-frame glow
// All layers share the same path inset so bloom never drifts away from the light.

private struct ContinuousFrameGlow: View {
    let segments: [EdgeSegment]
    let screenSize: CGSize
    let masterOpacity: Double
    
    var body: some View {
        let metrics = FrameMetrics(segments: segments, screenSize: screenSize)
        let palette = GlowPalette(from: metrics.representativeSegment)
        let intensity = metrics.averageBrightness * masterOpacity
        
        let inset = metrics.inset
        let corner = metrics.outerRadius
        let width = metrics.thickness
        
        ZStack {
            // Soft halo — controlled stroke with restrained blur to avoid foggy smearing
            frameStroke(
                inset: inset,
                lineWidth: width * 1.10,
                blur: min(metrics.softBlur, 8.0),
                color: palette.bloom.opacity(0.15 * intensity),
                cornerRadius: corner
            )
            
            // Body light — sleek, clean diffusion
            frameStroke(
                inset: inset,
                lineWidth: width * 0.72,
                blur: min(metrics.bodyBlur, 4.0),
                color: palette.base.opacity(0.80 * intensity),
                cornerRadius: corner
            )
            
            // Core band (tighter highlight ring)
            frameStroke(
                inset: inset,
                lineWidth: width * 0.36,
                blur: max(metrics.bodyBlur * 0.35, 1.0),
                color: palette.highlight.opacity(0.75 * intensity),
                cornerRadius: corner
            )
            
            // Crisp bezel rim
            frameStroke(
                inset: inset,
                lineWidth: max(width * 0.12, 2.0),
                blur: 0.5,
                color: palette.highlight.opacity(0.60 * intensity),
                cornerRadius: corner
            )
        }
        .blendMode(.plusLighter)
        .frame(width: screenSize.width, height: screenSize.height)
    }
    
    private func frameStroke(
        inset: CGFloat,
        lineWidth: CGFloat,
        blur: CGFloat,
        color: Color,
        cornerRadius: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .inset(by: inset)
            .stroke(color, lineWidth: lineWidth)
            .blur(radius: blur)
    }
}

// MARK: - Soft partial / ring-light segment

private struct SoftSegmentGlow: View {
    let segment: EdgeSegment
    let screenSize: CGSize
    let masterOpacity: Double
    
    var body: some View {
        let rect = segmentRect(for: segment, in: screenSize)
        let palette = GlowPalette(from: segment)
        let intensity = segment.brightness * masterOpacity
        
        // Controlled optical depth & restrained blur so it NEVER turns into a foggy, stretched blob
        let depth = rect.height
        let soft = min(max(segment.softness * 0.18, 1.0), 6.0)
        let bloom = min(max(segment.bloom * 0.15, 0.0), 5.0)
        let corner = min(max(depth * 0.15, 4.0), 14.0)
        
        ZStack {
            // Layer 1: Subtle Diffuse Ambient Halo (Tightly bounded to gradient path)
            if bloom > 0.1 {
                capsuleGradientFill(
                    rect: rect,
                    corner: corner,
                    fill: LinearGradient(
                        stops: [
                            .init(color: palette.bloom.opacity(0.20 * intensity), location: 0.0),
                            .init(color: palette.bloom.opacity(0.05 * intensity), location: 0.45),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: gradientStart(for: segment.edge),
                        endPoint: gradientEnd(for: segment.edge)
                    ),
                    blur: soft + bloom * 0.6
                )
            }
            
            // Layer 2: Studio Diffuser Body Light (Smooth inward decay along the edge)
            capsuleGradientFill(
                rect: rect,
                corner: corner,
                fill: LinearGradient(
                    stops: [
                        .init(color: palette.base.opacity(0.92 * intensity), location: 0.0),
                        .init(color: palette.base.opacity(0.55 * intensity), location: 0.25),
                        .init(color: palette.base.opacity(0.18 * intensity), location: 0.60),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: gradientStart(for: segment.edge),
                    endPoint: gradientEnd(for: segment.edge)
                ),
                blur: max(soft * 0.5, 0.5)
            )
            
            // Layer 3: Inner Core Highlight Band (Proximity anchor near bezel)
            capsuleGradientFill(
                rect: coreRect(from: rect, edge: segment.edge, scale: 0.45),
                corner: corner * 0.5,
                fill: LinearGradient(
                    stops: [
                        .init(color: palette.highlight.opacity(0.88 * intensity), location: 0.0),
                        .init(color: palette.base.opacity(0.35 * intensity), location: 0.50),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: gradientStart(for: segment.edge),
                    endPoint: gradientEnd(for: segment.edge)
                ),
                blur: max(soft * 0.25, 0.5)
            )
            
            // Layer 4: Razor-Sharp Bezel Rim (Anchors right against monitor bezel)
            capsuleGradientFill(
                rect: coreRect(from: rect, edge: segment.edge, scale: 0.12),
                corner: max(corner * 0.2, 2.0),
                fill: palette.highlight.opacity(0.65 * intensity),
                blur: 0.4
            )
        }
        .mask(endFeatherMask(for: segment, in: screenSize))
        .blendMode(.plusLighter)
    }
    
    private func capsuleGradientFill(
        rect: CGRect,
        corner: CGFloat,
        fill: some ShapeStyle,
        blur: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(fill)
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .position(x: rect.midX, y: rect.midY)
            .blur(radius: blur)
    }
    
    @ViewBuilder
    private func endFeatherMask(for segment: EdgeSegment, in size: CGSize) -> some View {
        let fullSpan = segment.startFraction <= 0.02 && segment.endFraction >= 0.98
        if fullSpan {
            Color.white
        } else {
            // Tight, natural smoothstep end rounding (~3.5% of span) so studio bar ends look clean and polished
            let span = max(segment.endFraction - segment.startFraction, 0.05)
            let feather = min(max(0.025 / span, 0.03), 0.08)
            let isHorizontal = segment.edge == .top || segment.edge == .bottom
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white, location: feather),
                            .init(color: .white, location: 1 - feather),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: isHorizontal ? .leading : .top,
                        endPoint: isHorizontal ? .trailing : .bottom
                    )
                )
                .frame(width: size.width, height: size.height)
        }
    }
    
    private func segmentRect(for segment: EdgeSegment, in size: CGSize) -> CGRect {
        let start = max(0.0, min(1.0, segment.startFraction))
        let end = max(start, min(1.0, segment.endFraction))
        // Thickness directly controls how deep the light gradient penetrates from the bezel edge into the screen
        let depth = min(max(segment.thickness * 0.65, 28.0), 180.0)
        
        switch segment.edge {
        case .top:
            return CGRect(x: size.width * start, y: 0, width: size.width * (end - start), height: depth)
        case .bottom:
            return CGRect(x: size.width * start, y: size.height - depth, width: size.width * (end - start), height: depth)
        case .left:
            return CGRect(x: 0, y: size.height * start, width: depth, height: size.height * (end - start))
        case .right:
            return CGRect(x: size.width - depth, y: size.height * start, width: depth, height: size.height * (end - start))
        }
    }
    
    private func coreRect(from rect: CGRect, edge: ScreenEdge, scale: CGFloat) -> CGRect {
        switch edge {
        case .top:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * scale)
        case .bottom:
            let h = rect.height * scale
            return CGRect(x: rect.minX, y: rect.maxY - h, width: rect.width, height: h)
        case .left:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width * scale, height: rect.height)
        case .right:
            let w = rect.width * scale
            return CGRect(x: rect.maxX - w, y: rect.minY, width: w, height: rect.height)
        }
    }
    
    private func gradientStart(for edge: ScreenEdge) -> UnitPoint {
        switch edge {
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }
    
    private func gradientEnd(for edge: ScreenEdge) -> UnitPoint {
        switch edge {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .trailing
        case .right: return .leading
        }
    }
}

// MARK: - Metrics & palette

private struct FrameMetrics {
    let thickness: CGFloat
    let softBlur: CGFloat
    let bodyBlur: CGFloat
    let averageBrightness: Double
    let inset: CGFloat
    let outerRadius: CGFloat
    let representativeSegment: EdgeSegment
    
    init(segments: [EdgeSegment], screenSize: CGSize) {
        let top = segments.first(where: { $0.edge == .top })
        let left = segments.first(where: { $0.edge == .left })
        let right = segments.first(where: { $0.edge == .right })
        let bottom = segments.first(where: { $0.edge == .bottom })
        
        let topT = top?.thickness ?? 64.0
        let leftT = left?.thickness ?? 56.0
        let rightT = right?.thickness ?? 56.0
        let bottomT = bottom?.thickness ?? 48.0
        // Clean optical scaling so the frame stays balanced even at high widths
        let avgThickness = min(max((topT * 1.1 + leftT + rightT + bottomT * 0.9) / 4.0, 32.0), 240.0) * 0.55
        
        let count = Double(max(segments.count, 1))
        let softness = segments.reduce(0.0) { $0 + $1.softness } / count
        let bloom = segments.reduce(0.0) { $0 + $1.bloom } / count
        let brightness = segments.reduce(0.0) { $0 + $1.brightness } / count
        
        self.thickness = CGFloat(avgThickness)
        self.softBlur = min(CGFloat(softness) * 0.22 + CGFloat(bloom) * 0.12, 10.0)
        self.bodyBlur = min(CGFloat(softness) * 0.12, 5.0)
        self.averageBrightness = brightness
        self.inset = max(self.thickness * 0.38, 6)
        let maxCorner = min(screenSize.width, screenSize.height) * 0.045
        self.outerRadius = min(max(self.thickness * 0.80, 14), maxCorner)
        self.representativeSegment = top ?? left ?? right ?? bottom ?? .defaultTop
    }
}

private struct GlowPalette {
    let base: Color
    let bloom: Color
    let highlight: Color
    
    init(from segment: EdgeSegment) {
        if let hex = segment.colorHex, let color = Color(hexString: hex) {
            self.base = color
        } else {
            self.base = ColorTemperature.color(fromKelvin: segment.kelvinTemp)
        }
        self.bloom = ColorTemperature.bloomColor(fromKelvin: segment.kelvinTemp)
        self.highlight = ColorTemperature.highlightColor(fromKelvin: segment.kelvinTemp)
    }
}

// MARK: - Hex color helper

extension Color {
    init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .displayP3,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
