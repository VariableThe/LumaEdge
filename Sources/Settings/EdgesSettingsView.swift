import SwiftUI
import LumaEdgeCore
import DisplayManager

public struct EdgesSettingsView: View {
    @ObservedObject private var engine = LightingEngine.shared
    @ObservedObject private var displayController = DisplayController.shared
    @State private var selectedScreenID: String = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Display Selector Header
            HStack {
                Text("Configure Display:")
                    .font(.headline)
                Picker("", selection: $selectedScreenID) {
                    ForEach(displayController.screens, id: \.self) { screen in
                        let id = displayController.screenID(for: screen)
                        Text(screen.localizedName).tag(id)
                    }
                }
                .frame(width: 220)
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            
            if let config = engine.monitorConfigs[selectedScreenID] {
                Form {
                    Section("Lighting Mode") {
                        Toggle("Virtual Ring Light Mode (Movable Single Segment)", isOn: Binding(
                            get: { config.isVirtualRingMode },
                            set: { newVal in
                                engine.setVirtualRingMode(newVal, position: config.virtualRingPosition, forMonitor: selectedScreenID)
                            }
                        ))
                        
                        if config.isVirtualRingMode {
                            Picker("Ring Light Position", selection: Binding(
                                get: { config.virtualRingPosition },
                                set: { newPos in
                                    engine.setVirtualRingMode(true, position: newPos, forMonitor: selectedScreenID)
                                }
                            )) {
                                ForEach(VirtualRingPosition.allCases) { pos in
                                    Text(pos.rawValue).tag(pos)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    Section("Segments & Parameters") {
                        ForEach(config.segments) { segment in
                            SegmentEditorRow(
                                segment: segment,
                                screenID: selectedScreenID,
                                onUpdate: { updated in
                                    engine.updateSegment(updated, forMonitor: selectedScreenID)
                                }
                            )
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                Text("Select a display to configure edges.")
                    .foregroundStyle(.secondary)
                    .padding(40)
            }
        }
        .onAppear {
            if selectedScreenID.isEmpty, let first = displayController.screens.first {
                selectedScreenID = displayController.screenID(for: first)
            }
        }
    }
}

private struct SegmentEditorRow: View {
    @State var segment: EdgeSegment
    let screenID: String
    let onUpdate: (EdgeSegment) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(segment.edge.rawValue + " Edge", isOn: $segment.isEnabled)
                    .font(.headline)
                    .onChange(of: segment.isEnabled) { oldValue, newValue in onUpdate(segment) }
                Spacer()
                Text("\(Int(segment.kelvinTemp))K")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            
            if segment.isEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Thickness: \(Int(segment.thickness))px")
                        Spacer()
                        Text("Softness: \(Int(segment.softness))px")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    HStack {
                        Slider(value: $segment.thickness, in: 16...2000, step: 8)
                            .onChange(of: segment.thickness) { oldValue, newValue in onUpdate(segment) }
                        Slider(value: $segment.softness, in: 4...120, step: 2)
                            .onChange(of: segment.softness) { oldValue, newValue in onUpdate(segment) }
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Segment Range along Border: \(Int(segment.startFraction * 100))% – \(Int(segment.endFraction * 100))%")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Start")
                        Slider(value: $segment.startFraction, in: 0.0...0.8, step: 0.05)
                            .onChange(of: segment.startFraction) { oldValue, newValue in
                                if segment.endFraction <= segment.startFraction {
                                    segment.endFraction = min(1.0, segment.startFraction + 0.1)
                                }
                                onUpdate(segment)
                            }
                        Text("End")
                        Slider(value: $segment.endFraction, in: 0.2...1.0, step: 0.05)
                            .onChange(of: segment.endFraction) { oldValue, newValue in
                                if segment.startFraction >= segment.endFraction {
                                    segment.startFraction = max(0.0, segment.endFraction - 0.1)
                                }
                                onUpdate(segment)
                            }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
