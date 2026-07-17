import AppKit
import Combine
import LumaEdgeCore
import WindowManager

public struct KnownAppCutout: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var bundleID: String
    public var appName: String
    public var edge: ScreenEdge
    public var startFraction: Double
    public var endFraction: Double
    
    public init(
        id: String = UUID().uuidString,
        bundleID: String,
        appName: String,
        edge: ScreenEdge,
        startFraction: Double,
        endFraction: Double
    ) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.edge = edge
        self.startFraction = startFraction
        self.endFraction = endFraction
    }
    
    public static let builtInCutouts: [KnownAppCutout] = [
        // Zoom floating control bar at bottom center
        KnownAppCutout(
            bundleID: "us.zoom.xos",
            appName: "Zoom Control Bar",
            edge: .bottom,
            startFraction: 0.35,
            endFraction: 0.65
        ),
        // Google Meet floating control pills at bottom
        KnownAppCutout(
            bundleID: "com.google.Chrome",
            appName: "Google Meet Toolbar",
            edge: .bottom,
            startFraction: 0.38,
            endFraction: 0.62
        ),
        // FaceTime floating pill / controls at bottom center
        KnownAppCutout(
            bundleID: "com.apple.FaceTime",
            appName: "FaceTime Controls",
            edge: .bottom,
            startFraction: 0.40,
            endFraction: 0.60
        ),
        // Microsoft Teams control bar at top center
        KnownAppCutout(
            bundleID: "com.microsoft.teams2",
            appName: "Teams Meeting Bar",
            edge: .top,
            startFraction: 0.35,
            endFraction: 0.65
        ),
        // OBS Studio status bar at bottom right
        KnownAppCutout(
            bundleID: "com.obsproject.obs-studio",
            appName: "OBS Stats Panel",
            edge: .bottom,
            startFraction: 0.75,
            endFraction: 1.0
        )
    ]
}

public enum AvoidanceLayer: String, Codable, CaseIterable, Identifiable, Sendable {
    case accessibilityAPI = "1. Accessibility API Inspection (Preferred)"
    case knownLayouts = "2. Per-App Known Cutouts"
    case cursorFading = "3. Cursor Proximity Fading (Dynamic Proxy)"
    case safeWorkspace = "4. Safe Workspace Fallback (Window Insetting)"
    
    public var id: String { rawValue }
}

@MainActor
public final class RegionCarver: ObservableObject {
    public static let shared = RegionCarver()
    
    @Published public var isAvoidanceEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isAvoidanceEnabled, forKey: "LumaEdge_IsAvoidanceEnabled")
            applyLayeredAvoidance()
        }
    }
    
    @Published public var activeCutouts: [KnownAppCutout] = KnownAppCutout.builtInCutouts
    @Published public private(set) var activeTriggeredCutouts: [KnownAppCutout] = []
    
    private let engine = LightingEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.isAvoidanceEnabled = UserDefaults.standard.bool(forKey: "LumaEdge_IsAvoidanceEnabled")
        setupObservers()
    }
    
    private func setupObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.applyLayeredAvoidance()
                }
            }
            .store(in: &cancellables)
            
        ws.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.applyLayeredAvoidance()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Executes the 4-layer UI avoidance strategy with graceful fallback across every running application.
    public func applyLayeredAvoidance() {
        guard isAvoidanceEnabled && engine.isEffectivelyIlluminated else {
            activeTriggeredCutouts.removeAll()
            return
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundles = Set(runningApps.compactMap { $0.bundleIdentifier })
        
        // Layer 1 & Layer 2 check: inspect active applications matching known cutouts or discovered AX floating windows
        var triggered: [KnownAppCutout] = []
        for cutout in activeCutouts {
            if runningBundles.contains(cutout.bundleID) {
                if let app = runningApps.first(where: { $0.bundleIdentifier == cutout.bundleID }),
                   app.isActive || app.activationPolicy == .regular {
                    triggered.append(cutout)
                }
            }
        }
        
        // Layer 1 check: discover live floating windows near borders
        if let mainScreen = NSScreen.main {
            let discovered = AXUIInspector.shared.discoverFloatingCutouts(on: mainScreen.frame)
            triggered.append(contentsOf: discovered)
        }
        
        self.activeTriggeredCutouts = triggered
        
        // If cutouts triggered, we carve out segments by modifying active segment fractions or splitting them
        // Note: Layer 3 (Cursor Fading) and Layer 4 (Safe Workspace) are automatically handled by CursorMonitor & SmartWorkspaceManager
        carveMonitorSegments(with: triggered)
    }
    
    public func carveMonitorSegments(with cutouts: [KnownAppCutout]) {
        for screen in NSScreen.screens {
            let screenID = screenIDFor(screen)
            guard var config = engine.monitorConfigs[screenID], !config.isVirtualRingMode else { continue }
            
            // Re-initialize base segments to standard edges before applying cutouts
            var newSegments: [EdgeSegment] = []
            
            for baseEdge in ScreenEdge.allCases {
                let matchingCutouts = cutouts.filter { $0.edge == baseEdge }
                if matchingCutouts.isEmpty {
                    switch baseEdge {
                    case .top: newSegments.append(.defaultTop)
                    case .bottom: newSegments.append(.defaultBottom)
                    case .left: newSegments.append(.defaultLeft)
                    case .right: newSegments.append(.defaultRight)
                    }
                } else {
                    // Carve segment around each cutout on this edge
                    let carved = Self.carveSegment(edge: baseEdge, cutouts: matchingCutouts, preset: engine.activePreset)
                    newSegments.append(contentsOf: carved)
                }
            }
            
            // Apply current preset properties onto carved segments
            for i in 0..<newSegments.count {
                newSegments[i].kelvinTemp = engine.activePreset.kelvinTemp
                newSegments[i].brightness = engine.activePreset.defaultBrightness
            }
            
            config.segments = newSegments
            engine.monitorConfigs[screenID] = config
        }
    }
    
    /// Pure helper function calculating non-overlapping border segments after removing cutout intervals (`[startFraction...endFraction]`).
    public static func carveSegment(edge: ScreenEdge, cutouts: [KnownAppCutout], preset: GlowPreset) -> [EdgeSegment] {
        var intervals = [(Double, Double)]()
        for cutout in cutouts where cutout.edge == edge {
            let s = max(0.0, min(1.0, cutout.startFraction))
            let e = max(0.0, min(1.0, cutout.endFraction))
            if s < e {
                intervals.append((s, e))
            }
        }
        
        guard !intervals.isEmpty else {
            switch edge {
            case .top: return [.defaultTop]
            case .bottom: return [.defaultBottom]
            case .left: return [.defaultLeft]
            case .right: return [.defaultRight]
            }
        }
        
        // Sort intervals by start fraction
        intervals.sort { $0.0 < $1.0 }
        
        // Merge overlapping or adjacent intervals
        var merged: [(Double, Double)] = []
        for interval in intervals {
            if let last = merged.last, interval.0 <= last.1 {
                merged[merged.count - 1] = (last.0, max(last.1, interval.1))
            } else {
                merged.append(interval)
            }
        }
        
        // Create remaining illuminated segments between cutouts
        var segments: [EdgeSegment] = []
        var current: Double = 0.0
        
        for cut in merged {
            if cut.0 > current + 0.02 {
                segments.append(EdgeSegment(
                    id: UUID().uuidString,
                    edge: edge,
                    startFraction: current,
                    endFraction: cut.0,
                    thickness: preset.defaultWidth,
                    kelvinTemp: preset.kelvinTemp,
                    brightness: preset.defaultBrightness,
                    softness: preset.softness,
                    bloom: preset.bloom,
                    isEnabled: true
                ))
            }
            current = cut.1
        }
        
        if current < 0.98 {
            segments.append(EdgeSegment(
                id: UUID().uuidString,
                edge: edge,
                startFraction: current,
                endFraction: 1.0,
                thickness: preset.defaultWidth,
                kelvinTemp: preset.kelvinTemp,
                brightness: preset.defaultBrightness,
                softness: preset.softness,
                bloom: preset.bloom,
                isEnabled: true
            ))
        }
        
        return segments
    }
    
    private func screenIDFor(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return "unknown"
        }
        return "\(number.uint32Value)"
    }
}
