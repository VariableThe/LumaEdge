import SwiftUI
import PluginAPI

public struct PluginSettingsView: View {
    @StateObject private var registry = PluginRegistry.shared
    @State private var copiedCLI = false
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Intelligent Lighting Plugins")
                        .font(.headline)
                    Text("Progressively enhance edge lighting with automated adaptation plugins that run locally with zero network overhead.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    ForEach(registry.plugins) { plugin in
                        HStack(alignment: .top, spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { plugin.isEnabled },
                                set: { newValue in
                                    registry.togglePlugin(id: plugin.id, enabled: newValue)
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plugin.name)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(plugin.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Command Line Interface (`lumaedge`)")
                        .font(.headline)
                    Text("Automate LumaEdge from scripts, Raycast, Alfred, or terminal shortcuts using the native IPC command utility.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Example Commands:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        codeSnippet("lumaedge toggle")
                        codeSnippet("lumaedge preset sunset")
                        codeSnippet("lumaedge brightness 0.85")
                        codeSnippet("lumaedge kelvin 3200")
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("macOS Deep Links & App Intents")
                        .font(.headline)
                    Text("Trigger LumaEdge actions directly via URL scheme or Shortcuts:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("lumaedge://toggle")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.blue)
                        Spacer()
                        Text("URL Scheme")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    @ViewBuilder
    private func codeSnippet(_ command: String) -> some View {
        HStack {
            Text(command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copiedCLI = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copiedCLI = false
                }
            }) {
                Image(systemName: copiedCLI ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(copiedCLI ? .green : .secondary)
        }
    }
}
