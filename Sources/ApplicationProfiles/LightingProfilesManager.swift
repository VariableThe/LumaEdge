import AppKit
import Combine
import LumaEdgeCore

public struct AppProfile: Identifiable, Codable, Equatable {
    public var id: UUID
    public var bundleID: String
    public var appName: String
    public var presetID: String
    public var isEnabled: Bool
    public var activatesVirtualRingMode: Bool
    public var virtualRingPosition: VirtualRingPosition
    
    public init(
        id: UUID = UUID(),
        bundleID: String,
        appName: String,
        presetID: String,
        isEnabled: Bool = true,
        activatesVirtualRingMode: Bool = true,
        virtualRingPosition: VirtualRingPosition = .webcamCenter
    ) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.presetID = presetID
        self.isEnabled = isEnabled
        self.activatesVirtualRingMode = activatesVirtualRingMode
        self.virtualRingPosition = virtualRingPosition
    }
    
    public static let defaultProfiles: [AppProfile] = [
        AppProfile(
            bundleID: "us.zoom.xos",
            appName: "Zoom",
            presetID: "daylight",
            isEnabled: true,
            activatesVirtualRingMode: true,
            virtualRingPosition: .webcamCenter
        ),
        AppProfile(
            bundleID: "com.apple.FaceTime",
            appName: "FaceTime",
            presetID: "daylight",
            isEnabled: true,
            activatesVirtualRingMode: true,
            virtualRingPosition: .webcamCenter
        ),
        AppProfile(
            bundleID: "com.microsoft.teams2",
            appName: "Microsoft Teams",
            presetID: "daylight",
            isEnabled: true,
            activatesVirtualRingMode: true,
            virtualRingPosition: .webcamCenter
        ),
        AppProfile(
            bundleID: "com.google.Chrome",
            appName: "Google Chrome (Meet)",
            presetID: "studio_white",
            isEnabled: false,
            activatesVirtualRingMode: true,
            virtualRingPosition: .webcamCenter
        )
    ]
}

@MainActor
public final class LightingProfilesManager: ObservableObject {
    public static let shared = LightingProfilesManager()
    
    @Published public var profiles: [AppProfile] = [] {
        didSet {
            saveProfiles()
        }
    }
    
    @Published public var isProfilesAutomationEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isProfilesAutomationEnabled, forKey: "LumaEdge_IsProfilesAutomationEnabled")
            if isProfilesAutomationEnabled {
                evaluateCurrentRunningApps()
            }
        }
    }
    
    @Published public private(set) var activeTriggeredProfile: AppProfile?
    
    private var cancellables = Set<AnyCancellable>()
    private var previousPresetIDBeforeTrigger: String?
    private var previousMonitorConfigsBeforeTrigger: [String: MonitorConfig]?
    private let engine = LightingEngine.shared
    
    public init() {
        self.isProfilesAutomationEnabled = UserDefaults.standard.bool(forKey: "LumaEdge_IsProfilesAutomationEnabled")
        loadProfiles()
        setupObservers()
    }
    
    private func setupObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        
        ws.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.evaluateCurrentRunningApps()
                }
            }
            .store(in: &cancellables)
            
        ws.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.evaluateCurrentRunningApps()
                }
            }
            .store(in: &cancellables)
            
        ws.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.evaluateCurrentRunningApps()
                }
            }
            .store(in: &cancellables)
    }
    
    public func evaluateCurrentRunningApps() {
        guard isProfilesAutomationEnabled else { return }
        
        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // Profiles should follow the app someone is actually using, not a meeting app
        // that happens to be open in the background.
        if let matchingProfile = profiles.first(where: { $0.isEnabled && $0.bundleID == frontmostBundleID }) {
            if activeTriggeredProfile?.id != matchingProfile.id {
                applyProfile(matchingProfile)
            }
        } else if activeTriggeredProfile != nil {
            revertProfile()
        }
    }
    
    public func applyProfile(_ profile: AppProfile) {
        if activeTriggeredProfile == nil {
            previousPresetIDBeforeTrigger = engine.activePreset.id
            previousMonitorConfigsBeforeTrigger = engine.monitorConfigs
        }
        activeTriggeredProfile = profile
        
        if let preset = GlowPreset.builtInPresets.first(where: { $0.id == profile.presetID }) {
            engine.applyPreset(preset)
        }
        
        if profile.activatesVirtualRingMode {
            for key in engine.monitorConfigs.keys {
                engine.setVirtualRingMode(true, position: profile.virtualRingPosition, forMonitor: key)
            }
        }
        
        // Auto-turn on master light when profile triggered
        if !engine.isMasterEnabled {
            engine.isMasterEnabled = true
        }
    }
    
    public func revertProfile() {
        activeTriggeredProfile = nil
        if let prevID = previousPresetIDBeforeTrigger,
           let preset = GlowPreset.builtInPresets.first(where: { $0.id == prevID }) {
            engine.applyPreset(preset)
        }
        if let previousMonitorConfigsBeforeTrigger {
            engine.monitorConfigs = previousMonitorConfigsBeforeTrigger
        }
        previousPresetIDBeforeTrigger = nil
        previousMonitorConfigsBeforeTrigger = nil
    }
    
    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: "LumaEdge_UserProfiles"),
           let decoded = try? JSONDecoder().decode([AppProfile].self, from: data) {
            self.profiles = decoded
        } else {
            self.profiles = AppProfile.defaultProfiles
        }
    }
    
    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "LumaEdge_UserProfiles")
        }
    }
}
