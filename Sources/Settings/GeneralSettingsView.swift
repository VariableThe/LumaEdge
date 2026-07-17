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
