import Foundation
import Combine
import HealthKit

@MainActor final class HealthKitProvider: HealthReadingProvider {
    private let store = HKHealthStore()
    private let authorized: () -> Bool
    init(authorized: @escaping () -> Bool) { self.authorized = authorized }
    var available: Bool { HKHealthStore.isHealthDataAvailable() }
    private func type(_ metric: HealthMetric) -> HKQuantityType {
        let id: HKQuantityTypeIdentifier
        switch metric { case .steps: id = .stepCount; case .activeEnergy: id = .activeEnergyBurned; case .height: id = .height; case .weight: id = .bodyMass }
        return HKObjectType.quantityType(forIdentifier: id)!
    }
    private func unit(_ metric: HealthMetric) -> HKUnit {
        switch metric { case .steps: return .count(); case .activeEnergy: return .kilocalorie(); case .height: return .meterUnit(with: .centi); case .weight: return .gramUnit(with: .kilo) }
    }
    func requestAccess() async throws { guard authorized() else { throw AccessDenied(permission: .readHealth) }; try await store.requestAuthorization(toShare: [], read: Set(HealthMetric.allCases.map { type($0) })) }
    func read(_ metric: HealthMetric, now: Date) async throws -> HealthReading? {
        guard authorized() else { throw AccessDenied(permission: .readHealth) }
        let quantityType = type(metric), quantityUnit = unit(metric)
        if metric.isDaily {
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: now), end: now, options: .strictStartDate)
            return try await withCheckedThrowingContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: result?.sumQuantity().map { HealthReading(value: $0.doubleValue(for: quantityUnit)) }) }
                }
                store.execute(query)
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: now)
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, results, error in
                if let error { continuation.resume(throwing: error) }
                else {
                    let sample = results?.first as? HKQuantitySample
                    continuation.resume(returning: sample.map { HealthReading(value: $0.quantity.doubleValue(for: quantityUnit), sampleDate: $0.endDate, source: $0.sourceRevision.source.name) })
                }
            }
            store.execute(query)
        }
    }
}
@MainActor final class HealthService: ObservableObject {
    private let monitor: HealthMonitor
    private var subscription: AnyCancellable?
    private let authorized: () -> Bool
    init(authorized: @escaping () -> Bool = { true }) {
        self.authorized = authorized
        monitor = HealthMonitor(provider: HealthKitProvider(authorized: authorized))
        subscription = monitor.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
    var steps: Double? { value(.steps) }
    var activeEnergy: Double? { value(.activeEnergy) }
    var height: Double? { value(.height) }
    var weight: Double? { value(.weight) }
    var busy: Bool { monitor.busy }
    var status: String { authorized() ? monitor.status : "Your role does not allow Apple Health access." }
    func value(_ metric: HealthMetric) -> Double? { authorized() ? monitor.value(metric) : nil }
    func result(_ metric: HealthMetric) -> MetricResult { authorized() ? monitor.result(metric) : MetricResult() }
    func expireOldResults() { monitor.expireOldResults() }
    func connect() async { await monitor.connect() }
    func refresh(_ metric: HealthMetric? = nil) async { await monitor.refresh(metric) }
}
