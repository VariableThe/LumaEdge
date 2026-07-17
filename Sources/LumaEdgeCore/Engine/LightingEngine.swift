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
    
    /// True only when the user has armed lighting *and* a camera is in use.
    public var isEffectivelyIlluminated: Bool {
        isMasterEnabled && isCameraActive
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
        
        loadMonitorConfigs()
    }
    
    public func toggleMaster() {
        isMasterEnabled.toggle()
    }
    
    public func applyPreset(_ preset: GlowPreset) {
        self.activePreset = preset
    }
    
    private func applyPresetToAllSegments(_ preset: GlowPreset) {
        for (screenID, var config) in monitorConfigs {
            for i in 0..<config.segments.count {
                config.segments[i].kelvinTemp = preset.kelvinTemp
                config.segments[i].brightness = preset.defaultBrightness
                config.segments[i].thickness = preset.defaultWidth
                config.segments[i].softness = preset.softness
                config.segments[i].bloom = preset.bloom
            }
            monitorConfigs[screenID] = config
        }
    }
    
    public func setVirtualRingMode(_ enabled: Bool, position: VirtualRingPosition = .webcamCenter, forMonitor screenID: String) {
        guard var config = monitorConfigs[screenID] else { return }
        config.isVirtualRingMode = enabled
        config.virtualRingPosition = position
        if enabled {
            var ringSeg = position.defaultSegment
            ringSeg.kelvinTemp = activePreset.kelvinTemp
            ringSeg.brightness = activePreset.defaultBrightness
            config.segments = [ringSeg]
        } else {
            config.segments = [
                .defaultTop,
                .defaultLeft,
                .defaultRight,
                .defaultBottom
            ]
            for i in 0..<config.segments.count {
                config.segments[i].kelvinTemp = activePreset.kelvinTemp
                config.segments[i].brightness = activePreset.defaultBrightness
            }
        }
        monitorConfigs[screenID] = config
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
