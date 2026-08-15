import Foundation
import Combine

@MainActor
public final class LightingEngine: ObservableObject {
    public static let shared = LightingEngine()
    
    private enum DefaultsKeys {
        static let isMasterEnabled = "LumaEdge_IsMasterEnabled"
        static let activePresetID = "LumaEdge_ActivePresetID"
        static let monitorConfigs = "LumaEdge_MonitorConfigs"
        static let cursorFadeDistance = "LumaEdge_CursorFadeDistance"
        static let cursorMinOpacity = "LumaEdge_CursorMinOpacity"
        static let isCursorFadingEnabled = "LumaEdge_IsCursorFadingEnabled"
        static let safeWorkspaceMode = "LumaEdge_SafeWorkspaceMode"
        static let ambientLightThreshold = "LumaEdge_AmbientLightThreshold"
        static let isAmbientLightGatingEnabled = "LumaEdge_IsAmbientLightGatingEnabled"
    }
    
    private let defaults = UserDefaults.standard
    
    /// User preference: when on, show edge light *only while the camera is active*.
    @Published public var isMasterEnabled: Bool = true {
        didSet {
            defaults.set(isMasterEnabled, forKey: DefaultsKeys.isMasterEnabled)
            notifyOverlayUpdate()
        }
    }
    
    /// Live camera activity from CameraMicDetector. Light is hidden when false.
    @Published public private(set) var isCameraActive: Bool = false {
        didSet {
            if oldValue != isCameraActive {
                notifyOverlayUpdate()
            }
        }
    }

    /// System ambient light sensor
    public let ambientLightSensor = AmbientLightSensor.shared

    /// Minimum ambient lux level below which the edge light will activate.
    /// Calculation: at 120 lux ambient, the screen's white-area contribution (~20–50 lux
    /// at typical brightness) brings total face illumination to ~150 lux, above which
    /// the edge light's ~30–50 lux boost becomes imperceptible.
    @Published public var ambientLightThreshold: Double = 120.0 {
        didSet {
            defaults.set(ambientLightThreshold, forKey: DefaultsKeys.ambientLightThreshold)
            notifyOverlayUpdate()
        }
    }

    /// When enabled, the edge light is gated on ambient light level (below threshold).
    /// When disabled, ambient condition is ignored (light always shows if other gates pass).
    @Published public var isAmbientLightGatingEnabled: Bool = true {
        didSet {
            defaults.set(isAmbientLightGatingEnabled, forKey: DefaultsKeys.isAmbientLightGatingEnabled)
            notifyOverlayUpdate()
        }
    }

    private var isAmbientLightLowEnough: Bool {
        guard isAmbientLightGatingEnabled else { return true }
        guard ambientLightSensor.isAvailable else { return true }
        guard ambientLightSensor.lux >= 0 else { return true }
        return ambientLightSensor.lux < ambientLightThreshold
    }

    /// True only when the master switch is armed, another application is actively
    /// using a camera, and the ambient-light gate permits illumination.
    public var isEffectivelyIlluminated: Bool {
        isMasterEnabled
            && isCameraActive
            && isAmbientLightLowEnough
    }
    
    public func setCameraActive(_ active: Bool) {
        guard isCameraActive != active else { return }
        isCameraActive = active
    }
    
    @Published public var activePreset: GlowPreset = GlowPreset.builtInPresets.first! {
        didSet {
            defaults.set(activePreset.id, forKey: DefaultsKeys.activePresetID)
            applyPresetToAllSegments(activePreset)
            notifyOverlayUpdate()
        }
    }
    
    @Published public var monitorConfigs: [String: MonitorConfig] = [:] {
        didSet {
            saveMonitorConfigs()
            notifyOverlayUpdate()
        }
    }
    
    @Published public var cursorFadeDistance: Double = 120.0 {
        didSet {
            defaults.set(cursorFadeDistance, forKey: DefaultsKeys.cursorFadeDistance)
        }
    }
    
    @Published public var cursorMinOpacity: Double = 0.18 {
        didSet {
            defaults.set(cursorMinOpacity, forKey: DefaultsKeys.cursorMinOpacity)
        }
    }
    
    @Published public var isCursorFadingEnabled: Bool = true {
        didSet {
            defaults.set(isCursorFadingEnabled, forKey: DefaultsKeys.isCursorFadingEnabled)
        }
    }
    
    @Published public var cursorOpacityMultipliers: [String: Double] = [:] {
        didSet {
            notifyOverlayUpdate()
        }
    }
    
    @Published public var safeWorkspaceMode: SafeWorkspaceMode = .off {
        didSet {
            defaults.set(safeWorkspaceMode.rawValue, forKey: DefaultsKeys.safeWorkspaceMode)
            for key in monitorConfigs.keys {
                monitorConfigs[key]?.safeWorkspaceMode = safeWorkspaceMode
            }
        }
    }
    
    /// When menu bar popover or settings are open, dim the overlay so controls stay readable.
    @Published public var isControlsUIVisible: Bool = false {
        didSet {
            notifyOverlayUpdate()
        }
    }
    
    /// Multiplier applied to edge glow while LumaEdge chrome (menu/settings) is open.
    public var controlsUIOpacityMultiplier: Double {
        isControlsUIVisible ? 0.12 : 1.0
    }
    
    public let onOverlayUpdateNeeded = PassthroughSubject<Void, Never>()
    
    public init() {
        self.isMasterEnabled = defaults.object(forKey: DefaultsKeys.isMasterEnabled) as? Bool ?? true

        let presetID = defaults.string(forKey: DefaultsKeys.activePresetID) ?? "studio_white"
        if let found = GlowPreset.builtInPresets.first(where: { $0.id == presetID }) {
            self.activePreset = found
        }

        if let dist = defaults.object(forKey: DefaultsKeys.cursorFadeDistance) as? Double {
            self.cursorFadeDistance = dist
        }
        if let minOp = defaults.object(forKey: DefaultsKeys.cursorMinOpacity) as? Double {
            self.cursorMinOpacity = minOp
        }
        if let fading = defaults.object(forKey: DefaultsKeys.isCursorFadingEnabled) as? Bool {
            self.isCursorFadingEnabled = fading
        }
        if let modeRaw = defaults.string(forKey: DefaultsKeys.safeWorkspaceMode),
           let mode = SafeWorkspaceMode(rawValue: modeRaw) {
            self.safeWorkspaceMode = mode
        }
        if let threshold = defaults.object(forKey: DefaultsKeys.ambientLightThreshold) as? Double {
            self.ambientLightThreshold = threshold
        }
        if let gating = defaults.object(forKey: DefaultsKeys.isAmbientLightGatingEnabled) as? Bool {
            self.isAmbientLightGatingEnabled = gating
        }

        loadMonitorConfigs()
        startAmbientLightMonitoring()
    }

    private func startAmbientLightMonitoring() {
        ambientLightSensor.startMonitoring { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.notifyOverlayUpdate()
            }
        }
    }
    
    public func toggleMaster() {
        isMasterEnabled.toggle()
    }
    
    public func applyPreset(_ preset: GlowPreset) {
        self.activePreset = preset
    }
    
    private func applyPresetToAllSegments(_ preset: GlowPreset) {
        for (screenID, var config) in monitorConfigs {
            config.segments = applying(preset, to: config.segments)
            if let savedEdgeSegments = config.savedEdgeSegments {
                config.savedEdgeSegments = applying(preset, to: savedEdgeSegments)
            }
            monitorConfigs[screenID] = config
        }
    }

    private func applying(_ preset: GlowPreset, to segments: [EdgeSegment]) -> [EdgeSegment] {
        segments.map { segment in
            var updated = segment
            updated.kelvinTemp = preset.kelvinTemp
            updated.colorHex = preset.colorHex
            updated.brightness = preset.defaultBrightness
            updated.thickness = preset.defaultWidth
            updated.softness = preset.softness
            updated.bloom = preset.bloom
            return updated
        }
    }
    
    public func setVirtualRingMode(_ enabled: Bool, position: VirtualRingPosition = .webcamCenter, forMonitor screenID: String) {
        guard var config = monitorConfigs[screenID] else { return }
        if enabled {
            if !config.isVirtualRingMode {
                config.savedEdgeSegments = config.segments
            }
            config.isVirtualRingMode = true
            config.virtualRingPosition = position
            var ringSeg = position.defaultSegment
            ringSeg.kelvinTemp = activePreset.kelvinTemp
            ringSeg.colorHex = activePreset.colorHex
            ringSeg.brightness = activePreset.defaultBrightness
            ringSeg.thickness = activePreset.defaultWidth
            ringSeg.softness = activePreset.softness
            ringSeg.bloom = activePreset.bloom
            config.segments = [ringSeg]
        } else {
            config.isVirtualRingMode = false
            config.segments = config.savedEdgeSegments ?? applying(activePreset, to: Self.defaultEdgeSegments)
            config.savedEdgeSegments = nil
        }
        monitorConfigs[screenID] = config
    }

    private static var defaultEdgeSegments: [EdgeSegment] {
        [.defaultTop, .defaultLeft, .defaultRight, .defaultBottom]
    }
    
    public func updateSegment(_ segment: EdgeSegment, forMonitor screenID: String) {
        guard var config = monitorConfigs[screenID] else { return }
        if let idx = config.segments.firstIndex(where: { $0.id == segment.id || $0.edge == segment.edge }) {
            config.segments[idx] = segment
        } else {
            config.segments.append(segment)
        }
        monitorConfigs[screenID] = config
    }
    
    public func getOrCreateMonitorConfig(forScreenID screenID: String, displayName: String) -> MonitorConfig {
        if let existing = monitorConfigs[screenID] {
            return existing
        }
        let newConfig = MonitorConfig.default(forScreenID: screenID, name: displayName)
        monitorConfigs[screenID] = newConfig
        return newConfig
    }
    
    private func notifyOverlayUpdate() {
        onOverlayUpdateNeeded.send()
    }
    
    private func saveMonitorConfigs() {
        guard let data = try? JSONEncoder().encode(monitorConfigs) else { return }
        defaults.set(data, forKey: DefaultsKeys.monitorConfigs)
    }
    
    private func loadMonitorConfigs() {
        guard let data = defaults.data(forKey: DefaultsKeys.monitorConfigs),
              let decoded = try? JSONDecoder().decode([String: MonitorConfig].self, from: data) else {
            return
        }
        self.monitorConfigs = decoded
    }
}
