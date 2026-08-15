import AppKit
import Combine
import Foundation
import LumaEdgeCore

@MainActor
public protocol LumaEdgePlugin: AnyObject, Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var isEnabled: Bool { get set }
    func start()
    func stop()
}

@MainActor
public final class PluginRegistry: ObservableObject {
    public static let shared = PluginRegistry()
    
    @Published public var plugins: [AnyLumaEdgePlugin] = []
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        registerBuiltInPlugins()
        setupIPCListener()
    }
    
    private func registerBuiltInPlugins() {
        let timePlugin = TimeOfDayPlugin()
        let brightnessPlugin = AdaptiveBrightnessPlugin()
        
        plugins = [
            AnyLumaEdgePlugin(timePlugin),
            AnyLumaEdgePlugin(brightnessPlugin)
        ]
        
        for plugin in plugins where plugin.isEnabled {
            plugin.start()
        }
    }
    
    public func togglePlugin(id: String, enabled: Bool) {
        if let idx = plugins.firstIndex(where: { $0.id == id }) {
            plugins[idx].isEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: "LumaEdge_Plugin_\(id)")
            if enabled {
                plugins[idx].start()
            } else {
                plugins[idx].stop()
            }
        }
    }
    
    private func setupIPCListener() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("LumaEdgeIPCCommand"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let jsonString = notification.object as? String else { return }
            Task { @MainActor [weak self] in
                self?.handleIPCCommand(jsonString: jsonString)
            }
        }
    }
    
    public func handleIPCCommand(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = dict["action"] as? String else {
            return
        }
        
        let engine = LightingEngine.shared
        switch action {
        case "toggle":
            engine.isMasterEnabled.toggle()
        case "on":
            engine.isMasterEnabled = true
        case "off":
            engine.isMasterEnabled = false
        case "preset":
            if let presetID = dict["presetID"] as? String {
                if let preset = GlowPreset.builtInPresets.first(where: { $0.id == presetID }) {
                    engine.applyPreset(preset)
                }
            }
        case "brightness":
            if let val = dict["value"] as? Double {
                for key in engine.monitorConfigs.keys {
                    guard var config = engine.monitorConfigs[key] else { continue }
                    for i in 0..<config.segments.count {
                        config.segments[i].brightness = Double(max(0.0, min(1.0, val)))
                    }
                    engine.monitorConfigs[key] = config
                }
            }
        case "kelvin":
            if let val = dict["value"] as? Double {
                for key in engine.monitorConfigs.keys {
                    guard var config = engine.monitorConfigs[key] else { continue }
                    for i in 0..<config.segments.count {
                        config.segments[i].kelvinTemp = Double(max(2000.0, min(10_000.0, val)))
                    }
                    engine.monitorConfigs[key] = config
                }
            }
        case "width":
            if let val = dict["value"] as? Double {
                for key in engine.monitorConfigs.keys {
                    guard var config = engine.monitorConfigs[key] else { continue }
                    for i in 0..<config.segments.count {
                        config.segments[i].thickness = Double(max(16.0, min(400.0, val)))
                    }
                    engine.monitorConfigs[key] = config
                }
            }
        default:
            break
        }
    }
}

public struct AnyLumaEdgePlugin: Identifiable, @unchecked Sendable {
    public let id: String
    public let name: String
    public let description: String
    private let _getEnabled: @MainActor @Sendable () -> Bool
    private let _setEnabled: @MainActor @Sendable (Bool) -> Void
    private let _start: @MainActor @Sendable () -> Void
    private let _stop: @MainActor @Sendable () -> Void
    
    @MainActor
    public var isEnabled: Bool {
        get { _getEnabled() }
        nonmutating set { _setEnabled(newValue) }
    }
    
    @MainActor
    public init<P: LumaEdgePlugin>(_ plugin: P) {
        self.id = plugin.id
        self.name = plugin.name
        self.description = plugin.description
        self._getEnabled = { plugin.isEnabled }
        self._setEnabled = { plugin.isEnabled = $0 }
        self._start = { plugin.start() }
        self._stop = { plugin.stop() }
    }
    
    @MainActor public func start() { _start() }
    @MainActor public func stop() { _stop() }
}
