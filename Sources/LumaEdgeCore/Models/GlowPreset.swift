import Foundation

public struct GlowPreset: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var kelvinTemp: Double
    public var defaultBrightness: Double
    public var defaultWidth: Double
    public var softness: Double
    public var bloom: Double
    public var colorHex: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String,
        kelvinTemp: Double,
        defaultBrightness: Double = 0.85,
        defaultWidth: Double = 64,
        softness: Double = 24,
        bloom: Double = 16,
        colorHex: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kelvinTemp = kelvinTemp
        self.defaultBrightness = defaultBrightness
        self.defaultWidth = defaultWidth
        self.softness = softness
        self.bloom = bloom
        self.colorHex = colorHex
    }
    
    public static let builtInPresets: [GlowPreset] = [
        GlowPreset(
            id: "studio_white",
            title: "Studio White",
            subtitle: "Crisp 6500K high-CRI fill",
            kelvinTemp: 6500,
            defaultBrightness: 0.85,
            defaultWidth: 68,
            softness: 16,
            bloom: 8
        ),
        GlowPreset(
            id: "daylight",
            title: "Daylight",
            subtitle: "Balanced 5600K daytime glow",
            kelvinTemp: 5600,
            defaultBrightness: 0.82,
            defaultWidth: 62,
            softness: 14,
            bloom: 7
        ),
        GlowPreset(
            id: "neutral_office",
            title: "Neutral Office",
            subtitle: "Natural 4000K workspace light",
            kelvinTemp: 4000,
            defaultBrightness: 0.76,
            defaultWidth: 56,
            softness: 12,
            bloom: 6
        ),
        GlowPreset(
            id: "warm_lamp",
            title: "Warm Lamp",
            subtitle: "Cozy 2700K golden desk tone",
            kelvinTemp: 2700,
            defaultBrightness: 0.72,
            defaultWidth: 60,
            softness: 16,
            bloom: 8
        ),
        GlowPreset(
            id: "sunset",
            title: "Sunset",
            subtitle: "Relaxing 2200K amber evening",
            kelvinTemp: 2200,
            defaultBrightness: 0.68,
            defaultWidth: 58,
            softness: 18,
            bloom: 9
        ),
        GlowPreset(
            id: "blue_hour",
            title: "Blue Hour",
            subtitle: "Alert 8000K twilight tone",
            kelvinTemp: 8000,
            defaultBrightness: 0.78,
            defaultWidth: 62,
            softness: 14,
            bloom: 7
        )
    ]
}
