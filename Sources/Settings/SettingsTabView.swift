import SwiftUI
import LumaEdgeCore

public struct SettingsTabView: View {
    public init() {}
    
    public var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            EdgesSettingsView()
                .tabItem {
                    Label("Edges & Ring Light", systemImage: "slider.horizontal.3")
                }
            
            ProfilesSettingsView()
                .tabItem {
                    Label("Profiles & Automation", systemImage: "person.2")
                }
            
            WorkspaceSettingsView()
                .tabItem {
                    Label("Smart Workspace", systemImage: "macwindow")
                }
            
            PluginSettingsView()
                .tabItem {
                    Label("Plugins & CLI", systemImage: "cpu")
                }
        }
        .frame(minWidth: 640, minHeight: 460)
    }
}
