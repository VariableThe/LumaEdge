import Foundation
import Combine
import IOKit

@MainActor
public final class AmbientLightSensor: ObservableObject {
    public static let shared = AmbientLightSensor()

    @Published public private(set) var lux: Double = -1
    @Published public private(set) var isAvailable: Bool = false

    private var timer: Timer?
    private var luxUpdateHandler: ((Double) -> Void)?
    private var bezelServicesHandle: UnsafeMutableRawPointer?
    private var alsServiceClient: CFTypeRef?
    private var copyEvent: CopyEventFunc?
    private var getFloatValue: EventGetFloatValueFunc?
    private var bezelServicesFailed: Bool = false

    private typealias CopyEventFunc = @convention(c) (CFTypeRef, Int64, Int32, Int64) -> Unmanaged<CFTypeRef>?
    private typealias EventGetFloatValueFunc = @convention(c) (CFTypeRef, Int32) -> Double

    private init() {}

    public func startMonitoring(onLuxUpdate: (@MainActor (Double) -> Void)? = nil) {
        luxUpdateHandler = onLuxUpdate
        readSensorValue()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.readSensorValue()
            }
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        if let handle = bezelServicesHandle {
            dlclose(handle)
            bezelServicesHandle = nil
        }
        alsServiceClient = nil
        copyEvent = nil
        getFloatValue = nil
        luxUpdateHandler = nil
    }

    public func readSensorValue() {
        if readSensorLegacy() || readSensorBezelServices() { return }
        isAvailable = false
        lux = -1
    }

    private func readSensorLegacy() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleLMUController"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(service, "LmuLux" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return false
        }

        if let dict = property as? [String: Any] {
            let left = dict["left"] as? Double ?? 0
            let right = dict["right"] as? Double ?? 0
            lux = (left + right) / 2.0
            isAvailable = true
        } else if let num = property as? NSNumber {
            lux = num.doubleValue
            isAvailable = true
        } else {
            return false
        }

        if isAvailable { luxUpdateHandler?(lux) }
        return true
    }

    private func readSensorBezelServices() -> Bool {
        guard ensureBezelServices() else { return false }
        guard let client = alsServiceClient, let copyEvent = copyEvent, let getFloatValue = getFloatValue else {
            return false
        }

        let kAmbientLightSensorEvent: Int64 = 12
        guard let event = copyEvent(client, kAmbientLightSensorEvent, 0, 0)?.takeUnretainedValue() else {
            return false
        }

        let field = Int32(kAmbientLightSensorEvent) << 16
        lux = getFloatValue(event, field)
        isAvailable = true

        luxUpdateHandler?(lux)
        return true
    }

    private func ensureBezelServices() -> Bool {
        if alsServiceClient != nil { return true }
        if bezelServicesFailed { return false }

        let path = "/System/Library/PrivateFrameworks/BezelServices.framework/Versions/Current/BezelServices"
        guard let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else {
            bezelServicesFailed = true
            return false
        }

        guard let copyALSSym = dlsym(handle, "ALCALSCopyALSServiceClient") else {
            dlclose(handle); bezelServicesFailed = true; return false
        }
        let copyALSClient = unsafeBitCast(copyALSSym, to: (@convention(c) () -> Unmanaged<CFTypeRef>?).self)
        guard let client = copyALSClient()?.takeUnretainedValue() else {
            dlclose(handle); bezelServicesFailed = true; return false
        }
        alsServiceClient = client

        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)
        guard let copyEventSym = dlsym(defaultHandle, "IOHIDServiceClientCopyEvent"),
              let getFloatSym = dlsym(defaultHandle, "IOHIDEventGetFloatValue") else {
            alsServiceClient = nil; dlclose(handle); bezelServicesFailed = true; return false
        }

        copyEvent = unsafeBitCast(copyEventSym, to: CopyEventFunc.self)
        getFloatValue = unsafeBitCast(getFloatSym, to: EventGetFloatValueFunc.self)
        bezelServicesHandle = handle
        return true
    }
}
