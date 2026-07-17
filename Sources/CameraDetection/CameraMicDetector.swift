import Foundation
import Combine
import CoreMediaIO
import CoreAudio
import AppKit
import LumaEdgeCore

@MainActor
public final class CameraMicDetector: ObservableObject {
    public static let shared = CameraMicDetector()
    
    @Published public private(set) var isCameraActive: Bool = false
    @Published public private(set) var isMicrophoneActive: Bool = false
    
    /// Kept for settings compatibility. Camera gating of the edge light is always on;
    /// this flag no longer flips the master toggle (master = “armed for camera”).
    @Published public var isAutoToggleEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isAutoToggleEnabled, forKey: "LumaEdge_AutoToggleCamera")
        }
    }
    
    private var pollingTimer: Timer?
    
    public init() {
        // Default ON so edge light follows camera; migrate missing key to true.
        if UserDefaults.standard.object(forKey: "LumaEdge_AutoToggleCamera") == nil {
            self.isAutoToggleEnabled = true
            UserDefaults.standard.set(true, forKey: "LumaEdge_AutoToggleCamera")
        } else {
            self.isAutoToggleEnabled = UserDefaults.standard.bool(forKey: "LumaEdge_AutoToggleCamera")
        }
        startMonitoring()
    }
    
    public func startMonitoring() {
        stopMonitoring()
        checkStatus()
        // Poll frequently enough for call start/end without burning CPU
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkStatus()
            }
        }
        // Keep timer alive in common run loop modes (menu tracking, etc.)
        if let timer = pollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    public func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    public func checkStatus() {
        let camState = checkCameraActive()
        let micState = checkMicrophoneActive()
        
        var stateChanged = false
        if isCameraActive != camState {
            isCameraActive = camState
            stateChanged = true
        }
        if isMicrophoneActive != micState {
            isMicrophoneActive = micState
            stateChanged = true
        }
        
        // Drive LightingEngine camera gate (master toggle stays as user preference)
        LightingEngine.shared.setCameraActive(camState)
        
        if stateChanged {
            objectWillChange.send()
        }
    }
    
    private func checkCameraActive() -> Bool {
        var opa = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var status = CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, &dataSize)
        guard status == OSStatus(kCMIOHardwareNoError) && dataSize > 0 else { return false }
        
        let deviceCount = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: deviceCount)
        status = CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, dataSize, &dataUsed, &devices)
        guard status == OSStatus(kCMIOHardwareNoError) else { return false }
        
        for device in devices {
            // First check: kCMIODevicePropertyProcessIsRunningSomewhere ('prsn', 0x7072736e)
            // Inspects exact process PIDs streaming from this camera.
            var prsnAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(0x7072736e),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            
            if CMIOObjectHasProperty(device, &prsnAddress) {
                var pidSize: UInt32 = 0
                let errSize = CMIOObjectGetPropertyDataSize(device, &prsnAddress, 0, nil, &pidSize)
                if errSize == OSStatus(kCMIOHardwareNoError) && pidSize > 0 {
                    let pidCount = Int(pidSize) / MemoryLayout<pid_t>.size
                    var pids = [pid_t](repeating: 0, count: pidCount)
                    let errData = CMIOObjectGetPropertyData(device, &prsnAddress, 0, nil, pidSize, &dataUsed, &pids)
                    if errData == OSStatus(kCMIOHardwareNoError) {
                        let activeClientPids = pids.filter { pid in
                            guard pid > 0 && pid != getpid() else { return false }
                            if let app = NSRunningApplication(processIdentifier: pid) {
                                let bundleID = app.bundleIdentifier ?? ""
                                // Ignore system/background daemons merely probing or holding standby references
                                if bundleID.hasPrefix("com.apple.cmio") ||
                                   bundleID.hasPrefix("com.apple.audio") ||
                                   bundleID.hasPrefix("com.apple.ControlCenter") ||
                                   bundleID.hasPrefix("com.apple.SystemSettings") {
                                    return false
                                }
                                return true
                            }
                            return true
                        }
                        if !activeClientPids.isEmpty {
                            return true
                        }
                        // If 'prsn' is supported and returned empty or daemons only, this camera is idle
                        continue
                    }
                } else if errSize == OSStatus(kCMIOHardwareNoError) && pidSize == 0 {
                    continue
                }
            }
            
            // Fallback for devices where 'prsn' is not exposed: check 'runn'
            var propAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            
            var isRunning: UInt32 = 0
            let propSize = UInt32(MemoryLayout<UInt32>.size)
            if CMIOObjectHasProperty(device, &propAddress) {
                let err = CMIOObjectGetPropertyData(device, &propAddress, 0, nil, propSize, &dataUsed, &isRunning)
                if err == OSStatus(kCMIOHardwareNoError) && isRunning != 0 {
                    return true
                }
            }
        }
        return false
    }
    
    private func checkMicrophoneActive() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize)
        guard status == noErr && propSize > 0 else { return false }
        
        let deviceCount = Int(propSize) / MemoryLayout<AudioObjectID>.size
        var devices = [AudioObjectID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize, &devices)
        guard status == noErr else { return false }
        
        for device in devices {
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeWildcard,
                mElement: kAudioObjectPropertyElementWildcard
            )
            
            if AudioObjectHasProperty(device, &runningAddress) {
                var isRunning: UInt32 = 0
                var size = UInt32(MemoryLayout<UInt32>.size)
                let err = AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &size, &isRunning)
                if err == noErr && isRunning != 0 {
                    return true
                }
            }
        }
        return false
    }
}
