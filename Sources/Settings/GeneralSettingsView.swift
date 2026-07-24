import SwiftUI
import LumaEdgeCore

public struct GeneralSettingsView: View {
    @ObservedObject private var engine = LightingEngine.shared
    @AppStorage("LumaEdge_LaunchAtLogin") private var launchAtLogin = false
    @AppStorage("LumaEdge_GlobalShortcut") private var shortcutText = "⌃⌥L"
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("System & Startup") {
                Toggle("Launch LumaEdge at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { oldValue, newValue in
                        // SMAppService registration bridged in Phase 2
                    }
                
                HStack {
                    Text("Global Keyboard Shortcut")
                    Spacer()
                    Text(shortcutText)
                        .font(.system(size: 13, weight: .bold).monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            
            Section("Ambient Light Gating") {
                Toggle("Gate edge light on ambient brightness", isOn: $engine.isAmbientLightGatingEnabled)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Ambient Light Threshold")
                        Spacer()
                        if engine.ambientLightSensor.isAvailable {
                            Text("\(Int(engine.ambientLightThreshold)) lux")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Sensor unavailable")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Slider(value: $engine.ambientLightThreshold, in: 20...400, step: 10)
                        .disabled(!engine.isAmbientLightGatingEnabled)
                    Text("Edge light activates when ambient light falls below this level. Threshold calculation: at ~120 lux, the screen's white-area contribution (~20–50 lux from video call content) brings total face illumination past 150 lux, where the edge light's 30–50 lux boost becomes imperceptible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack {
                    Text("Current ambient")
                    Spacer()
                    if engine.ambientLightSensor.isAvailable {
                        Text("\(Int(engine.ambientLightSensor.lux)) lux")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No sensor detected")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Cursor-Aware Transparency (Phase 2 Preview)") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Fade Distance")
                        Spacer()
                        Text("\(Int(engine.cursorFadeDistance)) px")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $engine.cursorFadeDistance, in: 50...300, step: 10)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Minimum Opacity near Controls")
                        Spacer()
                        Text("\(Int(engine.cursorMinOpacity * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $engine.cursorMinOpacity, in: 0.05...0.50, step: 0.05)
                }
            }
            
            Section("Presets Configuration") {
                Picker("Active Preset", selection: $engine.activePreset.id) {
                    ForEach(GlowPreset.builtInPresets) { preset in
                        Text("\(preset.title) (\(Int(preset.kelvinTemp))K)").tag(preset.id)
                    }
                }
                .onChange(of: engine.activePreset.id) { oldValue, newID in
                    if let found = GlowPreset.builtInPresets.first(where: { $0.id == newID }) {
                        engine.applyPreset(found)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
