import Foundation

public enum SafeWorkspaceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case off = "Off (Overlay Only)"
    case currentAppOnly = "Current App Only"
    case allSupportedApps = "All Supported Apps"
    case alwaysOn = "Always On (Inset Workspace)"
    
    public var id: String { rawValue }
}

public struct MonitorConfig: Codable, Identifiable, Equatable, Sendable {
    public var id: String // NSScreenNumber or Display UUID string
    public var displayName: String
    public var isEnabled: Bool
    public var brightnessScale: Double // Per-display multiplier (0.0 to 1.0)
    public var segments: [EdgeSegment]
    public var isVirtualRingMode: Bool
    public var virtualRingPosition: VirtualRingPosition
    public var safeWorkspaceMode: SafeWorkspaceMode
    
    public init(
        id: String,
        displayName: String = "Display",
        isEnabled: Bool = true,
        brightnessScale: Double = 1.0,
        segments: [EdgeSegment] = [
            .defaultTop,
            .defaultLeft,
            .defaultRight,
            .defaultBottom
        ],
        isVirtualRingMode: Bool = false,
        virtualRingPosition: VirtualRingPosition = .webcamCenter,
        safeWorkspaceMode: SafeWorkspaceMode = .off
    ) {
        self.id = id
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.brightnessScale = brightnessScale
        self.segments = segments
        self.isVirtualRingMode = isVirtualRingMode
        self.virtualRingPosition = virtualRingPosition
        self.safeWorkspaceMode = safeWorkspaceMode
    }
    
    public static func `default`(forScreenID screenID: String, name: String = "Main Display") -> MonitorConfig {
        MonitorConfig(id: screenID, displayName: name)
    }
}
