import Foundation
import Combine
import CoreAudio
import CoreMediaIO
import AppKit
import AVFoundation
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
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        if discoverySession.devices.contains(where: { device in
            device.isInUseByAnotherApplication
        }) {
            return true
        }

        // Some Chromium/Electron capture paths do not surface through
        // AVCaptureDevice's per-app flag. CoreMediaIO's documented system-wide
        // running flag reports whether a video device is actually performing I/O.
        return isAnyVideoDeviceRunningSomewhere()
    }

    private func isAnyVideoDeviceRunningSomewhere() -> Bool {
        var systemAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        let systemObject = CMIOObjectID(kCMIOObjectSystemObject)

        guard CMIOObjectGetPropertyDataSize(systemObject, &systemAddress, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return false
        }

        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: count)
        guard CMIOObjectGetPropertyData(systemObject, &systemAddress, 0, nil, dataSize, &dataUsed, &devices) == noErr else {
            return false
        }

        for device in devices {
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            guard CMIOObjectHasProperty(device, &runningAddress) else { continue }

            var isRunning: UInt32 = 0
            let runningDataSize = UInt32(MemoryLayout<UInt32>.size)
            let status = CMIOObjectGetPropertyData(
                device,
                &runningAddress,
                0,
                nil,
                runningDataSize,
                &dataUsed,
                &isRunning
            )
            if status == noErr && isRunning != 0 {
                return true
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
