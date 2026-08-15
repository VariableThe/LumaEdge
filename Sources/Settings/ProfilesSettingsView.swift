import SwiftUI
import LumaEdgeCore
import ApplicationProfiles
import CameraDetection
import AnimationEngine

public struct ProfilesSettingsView: View {
    @ObservedObject var profilesManager = LightingProfilesManager.shared
    @ObservedObject var camDetector = CameraMicDetector.shared
    @ObservedObject var engine = LightingEngine.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Camera-Gated Lighting") {
                Text("Edge light appears only when the menu bar switch is on and another application is using a camera. Ambient-light gating can further pause it in a bright room.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    Label(
                        "Webcam: \(camDetector.isCameraActive ? "Active" : "Idle")",
                        systemImage: camDetector.isCameraActive ? "video.fill" : "video.slash"
                    )
                    .foregroundStyle(camDetector.isCameraActive ? .green : .secondary)
                    .font(.subheadline.bold())
                    
                    Label(
                        "Light: \(engine.isEffectivelyIlluminated ? "On" : (engine.isMasterEnabled ? "Armed" : "Off"))",
                        systemImage: engine.isEffectivelyIlluminated ? "sun.max.fill" : "sun.max"
                    )
                    .foregroundStyle(engine.isEffectivelyIlluminated ? .yellow : .secondary)
                    .font(.subheadline.bold())
                    
                    Label(
                        "Mic: \(camDetector.isMicrophoneActive ? "Active" : "Idle")",
                        systemImage: camDetector.isMicrophoneActive ? "mic.fill" : "mic.slash"
                    )
                    .foregroundStyle(camDetector.isMicrophoneActive ? .green : .secondary)
                    .font(.subheadline.bold())
                }
                .padding(.top, 4)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Section("Intelligent Cursor-Aware Fading (120Hz/60Hz)") {
                Toggle("Enable Cursor Proximity Fading", isOn: $engine.isCursorFadingEnabled)
                    .font(.headline)
                
                Text("Smoothly dims edge lighting when your mouse pointer moves near screen borders. This prevents bright glow from interfering with menu bar buttons, window traffic lights, or dock icons.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if engine.isCursorFadingEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Fade Distance Threshold")
                            Spacer()
                            Text("\(Int(engine.cursorFadeDistance)) px")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $engine.cursorFadeDistance, in: 40...300, step: 10)
                        
                        HStack {
                            Text("Minimum Proximity Opacity")
                            Spacer()
                            Text("\(Int(engine.cursorMinOpacity * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $engine.cursorMinOpacity, in: 0.05...0.60, step: 0.05)
                    }
                    .padding(.top, 4)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Section("Application Triggers & Profiles") {
                HStack {
                    Toggle("Enable App-Based Triggers", isOn: $profilesManager.isProfilesAutomationEnabled)
                        .font(.headline)
                    Spacer()
                    if let active = profilesManager.activeTriggeredProfile {
                        Text("Active: \(active.appName)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
                
                Text("Automatically apply specific lighting presets and Virtual Ring Light modes when targeted applications are launched or brought to the foreground.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if profilesManager.isProfilesAutomationEnabled {
                    VStack(spacing: 8) {
                        ForEach($profilesManager.profiles) { $profile in
                            ProfileRowView(profile: $profile)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ProfileRowView: View {
    @Binding var profile: AppProfile
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $profile.isEnabled)
                .labelsHidden()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.appName)
                    .font(.subheadline.bold())
                Text(profile.bundleID)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 160, alignment: .leading)
            
            Spacer()
            
            Picker("Preset", selection: $profile.presetID) {
                ForEach(GlowPreset.builtInPresets) { preset in
                    Text(preset.title).tag(preset.id)
                }
            }
            .frame(width: 140)
            
            Toggle("Ring Mode", isOn: $profile.activatesVirtualRingMode)
                .font(.caption)
                .toggleStyle(.checkbox)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
