import SwiftUI
import CoreGraphics

public struct ColorTemperature {
    public static func rgb(fromKelvin kelvin: Double) -> (red: Double, green: Double, blue: Double) {
        let temp = max(2000.0, min(10000.0, kelvin)) / 100.0
        var red: Double
        var green: Double
        var blue: Double
        
        if temp <= 66.0 {
            red = 255.0
            green = temp <= 1.0 ? 0.0 : 99.4708025861 * log(temp) - 161.1195681661
            if temp <= 19.0 {
                blue = 0.0
            } else {
                blue = 138.5177312231 * log(temp - 10.0) - 305.0447927307
            }
        } else {
            red = 329.698727446 * pow(temp - 60.0, -0.1332047592)
            green = 288.1221695283 * pow(temp - 60.0, -0.0755148492)
            blue = 255.0
        }
        
        red = max(0.0, min(255.0, red)) / 255.0
        green = max(0.0, min(255.0, green)) / 255.0
        blue = max(0.0, min(255.0, blue)) / 255.0
        
        return (red, green, blue)
    }
    
    public static func color(fromKelvin kelvin: Double, brightness: Double = 1.0, opacity: Double = 1.0) -> Color {
        let (r, g, b) = rgb(fromKelvin: kelvin)
        return Color(
            .displayP3,
            red: r * brightness,
            green: g * brightness,
            blue: b * brightness,
            opacity: opacity
        )
    }
    
    /// Slightly shifted neighbor temperature for angular color variation (more natural light).
    public static func accentColor(fromKelvin kelvin: Double, brightness: Double = 1.0, opacity: Double = 1.0) -> Color {
        // Warm lights lean slightly amber; cool lights lean slightly sky-cyan.
        let shift = kelvin < 4500 ? -280.0 : (kelvin > 6500 ? 450.0 : 180.0)
        return color(fromKelvin: kelvin + shift, brightness: brightness * 0.92, opacity: opacity)
    }
    
    /// Desaturated, lifted bloom color so outer haze doesn't look muddy.
    public static func bloomColor(fromKelvin kelvin: Double, brightness: Double = 1.0, opacity: Double = 1.0) -> Color {
        let (r, g, b) = rgb(fromKelvin: kelvin)
        // Mix toward white for a soft atmospheric bloom
        let lift: Double = 0.35
        return Color(
            .displayP3,
            red: min(1.0, (r * (1.0 - lift) + lift) * brightness),
            green: min(1.0, (g * (1.0 - lift) + lift) * brightness),
            blue: min(1.0, (b * (1.0 - lift) + lift) * brightness),
            opacity: opacity
        )
    }
    
    /// Near-white rim highlight biased by temperature (warm gold vs cool silver).
    public static func highlightColor(fromKelvin kelvin: Double, brightness: Double = 1.0, opacity: Double = 1.0) -> Color {
        let (r, g, b) = rgb(fromKelvin: kelvin)
        let mix: Double = 0.72
        return Color(
            .displayP3,
            red: min(1.0, (r * (1.0 - mix) + 1.0 * mix) * brightness),
            green: min(1.0, (g * (1.0 - mix) + 1.0 * mix) * brightness),
            blue: min(1.0, (b * (1.0 - mix) + 1.0 * mix) * brightness),
            opacity: opacity
        )
    }
    
    public static func cgColor(fromKelvin kelvin: Double, brightness: Double = 1.0, opacity: Double = 1.0) -> CGColor {
        let (r, g, b) = rgb(fromKelvin: kelvin)
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        let components: [CGFloat] = [
            CGFloat(r * brightness),
            CGFloat(g * brightness),
            CGFloat(b * brightness),
            CGFloat(opacity)
        ]
        return CGColor(colorSpace: colorSpace, components: components) ?? CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(opacity))
    }
}
