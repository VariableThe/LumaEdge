import SwiftUI
import LumaEdgeCore
import WindowManager

public struct WorkspaceSettingsView: View {
    @ObservedObject var workspaceManager = SmartWorkspaceManager.shared
    @ObservedObject var engine = LightingEngine.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Smart Workspace Mode (Opt-In Window Management)") {
                Picker("Safe Workspace Behavior", selection: $workspaceManager.globalSafeWorkspaceMode) {
                    ForEach(SafeWorkspaceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .font(.headline)
                .pickerStyle(.radioGroup)
                
                Text("Smart Workspace dynamically adjusts and constrains application windows so they sit inside the illuminated edge boundaries, preventing bright borders from overlapping important scrollbars, toolbars, or window traffic lights.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if workspaceManager.globalSafeWorkspaceMode != .off {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("Strict Safety Guardrails Active: Fullscreen spaces, Stage Manager, Mission Control, Launchpad, modal dialogs, floating utility palettes, and picture-in-picture windows are strictly excluded from manipulation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Inset Edges")
                            .font(.subheadline.bold())
                        
                        Text("Select which illuminated screen borders should push application windows inward:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 20) {
                            Toggle("Top Edge", isOn: $workspaceManager.isInsetTop)
                            Toggle("Bottom Edge", isOn: $workspaceManager.isInsetBottom)
                            Toggle("Left Edge", isOn: $workspaceManager.isInsetLeft)
                            Toggle("Right Edge", isOn: $workspaceManager.isInsetRight)
                        }
                        .toggleStyle(.checkbox)
                        .padding(.top, 4)
                    }
                    
                    HStack {
                        Spacer()
                        Button("Revert All Windows to Original Snapshot") {
                            workspaceManager.revertAllSnapshots()
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.blue)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
