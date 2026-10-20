import Foundation
import Combine
import HealthKit

@MainActor final class HealthKitProvider: HealthReadingProvider, HealthWritingProvider {
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
    func requestAccess() async throws { guard authorized() else { throw AccessDenied(permission: .readHealth) }; try await store.requestAuthorization(toShare: [], read: HealthCatalogueReader.readTypes) }
    func browse(_ kind: HealthDataKind, day: Date?, limit: Int) async throws -> [HealthDataRecord] {
        guard authorized() else { throw AccessDenied(permission: .readHealth) }
        guard available else { throw DiaryFailure.invalid("Apple Health is unavailable on this device.") }
        let records = try await HealthCatalogueReader.read(kind, day: day, limit: limit, store: store)
        guard authorized() else { throw AccessDenied(permission: .readHealth) }
        return records
    }
    func requestWriteAccess(_ metric: HealthMetric) async throws {
        guard authorized() else { throw AccessDenied(permission: .shareHealth) }
        guard metric == .height || metric == .weight else { throw DiaryFailure.invalid("Only body measurements can be shared.") }
        try await store.requestAuthorization(toShare: [type(metric)], read: [])
        guard store.authorizationStatus(for: type(metric)) == .sharingAuthorized else {
            throw DiaryFailure.invalid("Allow Nourish to write this measurement in Apple Health permissions, then try again.")
        }
    }
    func save(_ measurement: HealthMeasurement) async throws {
        guard authorized() else { throw AccessDenied(permission: .shareHealth) }
        try measurement.validate()
        let quantityType = type(measurement.metric)
        guard store.authorizationStatus(for: quantityType) == .sharingAuthorized else {
            throw DiaryFailure.invalid("Write access is off for this measurement. Nothing was saved to Apple Health.")
        }
        let sample = HKQuantitySample(type: quantityType, quantity: HKQuantity(unit: unit(measurement.metric), doubleValue: measurement.value),
            start: measurement.date, end: measurement.date,
            metadata: [HKMetadataKeySyncIdentifier: measurement.syncID, HKMetadataKeySyncVersion: 1])
        try await store.save(sample)
    }
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
    private let provider: HealthKitProvider
    @Published private(set) var browseRevision = 0
    private let monitor: HealthMonitor
    private let sharing: HealthSharingController
    private var subscription: AnyCancellable?
    private let authorized: () -> Bool
    init(authorized: @escaping () -> Bool) {
        self.authorized = authorized
        let healthProvider = HealthKitProvider(authorized: authorized)
        provider = healthProvider
        monitor = HealthMonitor(provider: healthProvider)
        sharing = HealthSharingController(provider: healthProvider, authorized: authorized)
        subscription = Publishers.Merge(monitor.objectWillChange, sharing.objectWillChange).sink { [weak self] _ in self?.objectWillChange.send() }
    }
    var sharingBusy: Bool { sharing.busy }
    func share(_ measurement: HealthMeasurement) async throws { try await sharing.share(measurement) }
    var steps: Double? { value(.steps) }
    var activeEnergy: Double? { value(.activeEnergy) }
    var height: Double? { value(.height) }
    var weight: Double? { value(.weight) }
    var busy: Bool { monitor.busy }
    var status: String { authorized() ? monitor.status : "Sign in to access Apple Health." }
    func value(_ metric: HealthMetric) -> Double? { authorized() ? monitor.value(metric) : nil }
    func result(_ metric: HealthMetric) -> MetricResult { authorized() ? monitor.result(metric) : MetricResult() }
    func expireOldResults() { monitor.expireOldResults() }
    func browse(_ kind: HealthDataKind, day: Date? = nil, limit: Int = 200) async throws -> [HealthDataRecord] { try await provider.browse(kind, day: day, limit: min(max(limit, 1), 200)) }
    func connect() async { await monitor.connect(); browseRevision += 1 }
    func refresh(_ metric: HealthMetric? = nil) async { await monitor.refresh(metric); if metric == nil { browseRevision += 1 } }
}
