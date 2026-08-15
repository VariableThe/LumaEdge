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
                    ForEach(enabledSegments) { segment in
                        SoftSegmentGlow(
                            segment: segment,
                            screenSize: geometry.size,
                            masterOpacity: opacity
                        )
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
    
}

// MARK: - Soft partial / ring-light segment

private struct SoftSegmentGlow: View {
    let segment: EdgeSegment
    let screenSize: CGSize
    let masterOpacity: Double
    
    var body: some View {
        let rect = segmentRect(for: segment, in: screenSize)
        let intensity = segment.brightness * masterOpacity
        let depth = segment.edge == .top || segment.edge == .bottom ? rect.height : rect.width
        let corner = min(max(depth * 0.15, 4.0), 14.0)
        let diffuserBlur = min(max(segment.softness * 0.35, depth * 0.035), 30.0)
        let bloomBlur = min(max(segment.bloom + segment.softness * 0.65, 4.0), 52.0)
        let colors = palette
        
        ZStack {
            capsuleGradientFill(
                rect: rect,
                corner: corner,
                fill: LinearGradient(
                    stops: [
                        .init(color: colors.bloom.opacity(intensity * 0.32), location: 0.0),
                        .init(color: colors.bloom.opacity(intensity * 0.15), location: 0.36),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: gradientStart(for: segment.edge),
                    endPoint: gradientEnd(for: segment.edge)
                ),
                blur: bloomBlur
            )

            capsuleGradientFill(
                rect: rect,
                corner: corner,
                fill: LinearGradient(
                    stops: [
                        .init(color: colors.highlight.opacity(intensity * 0.96), location: 0.0),
                        .init(color: colors.base.opacity(intensity * 0.72), location: 0.14),
                        .init(color: colors.base.opacity(intensity * 0.32), location: 0.42),
                        .init(color: colors.bloom.opacity(intensity * 0.08), location: 0.70),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: gradientStart(for: segment.edge),
                    endPoint: gradientEnd(for: segment.edge)
                ),
                blur: diffuserBlur
            )
        }
        .frame(width: screenSize.width, height: screenSize.height)
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
        let depth = min(max(segment.thickness * 0.65, 24.0), 240.0)
        
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

    private var palette: GlowPalette {
        if let colorHex = segment.colorHex,
           let customColor = Color(hexString: colorHex) {
            return GlowPalette(base: customColor, highlight: customColor, bloom: customColor)
        }

        return GlowPalette(
            base: ColorTemperature.color(fromKelvin: segment.kelvinTemp),
            highlight: ColorTemperature.highlightColor(fromKelvin: segment.kelvinTemp),
            bloom: ColorTemperature.bloomColor(fromKelvin: segment.kelvinTemp)
        )
    }
}

private struct GlowPalette {
    let base: Color
    let highlight: Color
    let bloom: Color
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
