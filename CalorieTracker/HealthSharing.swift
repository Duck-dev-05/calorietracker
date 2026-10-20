import Foundation
import Combine

struct HealthMeasurement: Equatable {
    let metric: HealthMetric
    let value: Double
    let date: Date
    func validate(now: Date = Date()) throws {
        let range: ClosedRange<Double>
        switch metric {
        case .height: range = 80...250
        case .weight: range = 20...400
        default: throw DiaryFailure.invalid("Only height and weight can be shared from this page.")
        }
        guard value.isFinite, range.contains(value), date.timeIntervalSinceReferenceDate.isFinite,
              date >= Date(timeIntervalSince1970: 0), date <= now else {
            throw DiaryFailure.invalid("Check the measurement, units and date. Future measurements cannot be shared.")
        }
    }
    // The same value/date/type from Nourish uses the same HealthKit identity on retries.
    var syncID: String { "nourish.measurement.\(metric.rawValue).\(String(date.timeIntervalSinceReferenceDate.bitPattern, radix: 16)).\(String(value.bitPattern, radix: 16))" }
}
@MainActor protocol HealthWritingProvider {
    var available: Bool { get }
    func requestWriteAccess(_ metric: HealthMetric) async throws
    func save(_ measurement: HealthMeasurement) async throws
}
@MainActor final class HealthSharingController: ObservableObject {
    @Published private(set) var busy = false
    private let provider: HealthWritingProvider
    private let authorized: () -> Bool
    init(provider: HealthWritingProvider, authorized: @escaping () -> Bool) { self.provider = provider; self.authorized = authorized }
    func share(_ measurement: HealthMeasurement) async throws {
        guard authorized() else { throw AccessDenied(permission: .shareHealth) }
        guard !busy else { throw DiaryFailure.invalid("A measurement is already being shared.") }
        try measurement.validate()
        guard provider.available else { throw DiaryFailure.invalid("Apple Health is unavailable on this device.") }
        busy = true; defer { busy = false }
        try await provider.requestWriteAccess(measurement.metric)
        guard authorized() else { throw AccessDenied(permission: .shareHealth) }
        try measurement.validate()
        try await provider.save(measurement)
    }
}
