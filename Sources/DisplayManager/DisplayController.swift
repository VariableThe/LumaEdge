import AppKit
import Combine
import LumaEdgeCore

@MainActor
public final class DisplayController: ObservableObject {
    public static let shared = DisplayController()
    
    @Published public private(set) var screens: [NSScreen] = NSScreen.screens
    
    public let onScreensChanged = PassthroughSubject<Void, Never>()
    private var screenObserver: NSObjectProtocol?
    
    public init() {
        refreshScreens()
        
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.refreshScreens()
            }
        }
    }
    
    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }
    
    public func refreshScreens() {
        self.screens = NSScreen.screens
        for screen in screens {
            let screenID = self.screenID(for: screen)
            let name = screen.localizedName
            _ = LightingEngine.shared.getOrCreateMonitorConfig(forScreenID: screenID, displayName: name)
        }
        onScreensChanged.send()
    }
    
    public func screenID(for screen: NSScreen) -> String {
        if let idNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return idNumber.stringValue
        }
        return UUID().uuidString
    }
    
    public func screen(forScreenID screenID: String) -> NSScreen? {
        screens.first { self.screenID(for: $0) == screenID }
    }
}
