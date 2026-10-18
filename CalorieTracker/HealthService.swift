import Foundation
import Combine
import HealthKit

@MainActor final class HealthService: ObservableObject {
    @Published var steps: Double?
    @Published var activeEnergy: Double?
    @Published var height: Double?
    @Published var weight: Double?
    @Published var status = "Connect to see activity from Apple Health."
    @Published var busy = false
    private let store = HKHealthStore()
    func connect() async {
        guard !busy else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Apple Health is unavailable on this device."; return
        }
        busy = true
        defer { busy = false }
        do {
            let identifiers: [HKQuantityTypeIdentifier] = [.height, .bodyMass, .stepCount, .activeEnergyBurned]
            let types = Set(identifiers.map { HKObjectType.quantityType(forIdentifier: $0)! })
            try await store.requestAuthorization(toShare: [], read: types)
            steps = try await total(.stepCount, unit: .count())
            activeEnergy = try await total(.activeEnergyBurned, unit: .kilocalorie())
            height = try await latest(.height, unit: .meterUnit(with: .centi))
            weight = try await latest(.bodyMass, unit: .gramUnit(with: .kilo))
            status = "Updated from available Health data. Missing values may mean no records or read access. Manage access in Apple Health."
        } catch { status = "Could not refresh Health data: \(error.localizedDescription)" }
    }
    private func total(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let type = HKObjectType.quantityType(forIdentifier: identifier)!
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit)) }
            }
            store.execute(query)
        }
    }
    private func latest(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let type = HKObjectType.quantityType(forIdentifier: identifier)!
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: Date())
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, results, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: (results?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)) }
            }
            store.execute(query)
        }
    }
}
