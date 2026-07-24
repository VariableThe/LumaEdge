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
        luxUpdateHandler = nil
    }

    public func readSensorValue() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleLMUController"))
        guard service != 0 else {
            isAvailable = false
            lux = -1
            return
        }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(service, "LmuLux" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            isAvailable = false
            lux = -1
            return
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
            isAvailable = false
            lux = -1
        }

        if isAvailable {
            luxUpdateHandler?(lux)
        }
    }
}
