import SwiftUI
import LumaEdgeCore
import DisplayManager

public struct MenuBarView: View {
    @ObservedObject private var engine = LightingEngine.shared
    @ObservedObject private var displayController = DisplayController.shared
    @State private var selectedScreenID: String
    @State private var brightness: Double = 0.82
    @State private var thickness: Double = 62.0
    
    public let onOpenSettings: () -> Void
    public let onQuit: () -> Void
    
    public init(onOpenSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        
        let initialID = DisplayController.shared.screens.first.map { DisplayController.shared.screenID(for: $0) } ?? ""
        _selectedScreenID = State(initialValue: initialID)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: arm lighting for when camera is on
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: engine.isEffectivelyIlluminated ? "sun.max.fill" : "sun.max")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(engine.isEffectivelyIlluminated ? .yellow : (engine.isMasterEnabled ? .orange : .secondary))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("LumaEdge")
                            .font(.system(size: 15, weight: .bold))
                        Text(statusCaption)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("", isOn: $engine.isMasterEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .help("When on, edge light appears only while your camera is in use")
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Brightness Slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Brightness")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(Int(brightness * 100))%")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $brightness, in: 0.05...1.0)
                    .onChange(of: brightness) { oldValue, newValue in
                        updateBrightness(newValue)
                    }
            }
            
            // Width (Thickness) Slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Width")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(Int(thickness))px")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $thickness, in: 16.0...160.0, step: 2.0)
                    .onChange(of: thickness) { oldValue, newValue in
                        updateThickness(newValue)
                    }
            }
            
            // Presets Picker
            HStack {
                Text("Preset")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: $engine.activePreset.id) {
                    ForEach(GlowPreset.builtInPresets) { preset in
                        Text(preset.title).tag(preset.id)
                    }
                }
                .frame(width: 150)
                .onChange(of: engine.activePreset.id) { oldValue, newID in
                    if let found = GlowPreset.builtInPresets.first(where: { $0.id == newID }) {
                        engine.applyPreset(found)
                        self.brightness = found.defaultBrightness
                        self.thickness = found.defaultWidth
                    }
                }
            }
            
            // Smart Workspace Mode (Opt-In with Guardrails)
            HStack {
                Text("Workspace")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: $engine.safeWorkspaceMode) {
                    ForEach(SafeWorkspaceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 150)
            }
            
            // Display Selector
            HStack {
                Text("Display")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: $selectedScreenID) {
                    ForEach(displayController.screens, id: \.self) { screen in
                        let id = displayController.screenID(for: screen)
                        Text(screen.localizedName).tag(id)
                    }
                }
                .frame(width: 150)
                .onChange(of: selectedScreenID) { oldValue, newID in
                    if let config = engine.monitorConfigs[newID], let firstSeg = config.segments.first {
                        self.brightness = firstSeg.brightness
                        self.thickness = firstSeg.thickness
                    }
                }
            }
            
            // Virtual Ring Light Mode Quick Toggle
            HStack {
                Text("Ring Light")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                let isRing = engine.monitorConfigs[selectedScreenID]?.isVirtualRingMode ?? false
                Toggle("Center 50%", isOn: Binding(
                    get: { isRing },
                    set: { newVal in
                        engine.setVirtualRingMode(newVal, position: .webcamCenter, forMonitor: selectedScreenID)
                    }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
            }
            
            Divider()
            
            // Footer Buttons
            HStack {
                Button(action: onOpenSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text("Settings…")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                
                Spacer()
                
                Button(action: onQuit) {
                    Text("Quit LumaEdge")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .font(.system(size: 12.5, weight: .medium))
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            if let config = engine.monitorConfigs[selectedScreenID], let firstSeg = config.segments.first {
                self.brightness = firstSeg.brightness
                self.thickness = firstSeg.thickness
            }
        }
    }
    
    private var statusCaption: String {
        if !engine.isMasterEnabled {
            return "Off — won’t light during calls"
        }
        if engine.isCameraActive {
            return "Camera on — edge light active"
        }
        return "Armed — waits for camera"
    }
    
    private func updateBrightness(_ val: Double) {
        guard var config = engine.monitorConfigs[selectedScreenID] else { return }
        for i in 0..<config.segments.count {
            config.segments[i].brightness = val
        }
        engine.monitorConfigs[selectedScreenID] = config
    }
    
    private func updateThickness(_ val: Double) {
        guard var config = engine.monitorConfigs[selectedScreenID] else { return }
        for i in 0..<config.segments.count {
            config.segments[i].thickness = val
        }
        engine.monitorConfigs[selectedScreenID] = config
    }
}
