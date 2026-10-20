import Foundation
import HealthKit

/// Read-only catalogue; no sample sums are invented from overlapping sources.
@MainActor enum HealthCatalogueReader {
    static func definition(_ kind: HealthDataKind) -> (HKQuantityTypeIdentifier, HKUnit, String, Double)? {
        switch kind {
        case .steps: return (.stepCount, .count(), "steps", 1)
        case .activeEnergy: return (.activeEnergyBurned, .kilocalorie(), "kcal", 1)
        case .restingEnergy: return (.basalEnergyBurned, .kilocalorie(), "kcal", 1)
        case .walkingDistance: return (.distanceWalkingRunning, .meterUnit(with: .kilo), "km", 1)
        case .cyclingDistance: return (.distanceCycling, .meterUnit(with: .kilo), "km", 1)
        case .flights: return (.flightsClimbed, .count(), "flights", 1)
        case .exercise: return (.appleExerciseTime, .minute(), "min", 1)
        case .stand: return (.appleStandTime, .minute(), "min", 1)
        case .height: return (.height, .meterUnit(with: .centi), "cm", 1)
        case .weight: return (.bodyMass, .gramUnit(with: .kilo), "kg", 1)
        case .bmi: return (.bodyMassIndex, .count(), "BMI", 1)
        case .bodyFat: return (.bodyFatPercentage, .percent(), "%", 100)
        case .heartRate: return (.heartRate, .count().unitDivided(by: .minute()), "bpm", 1)
        case .restingHeartRate: return (.restingHeartRate, .count().unitDivided(by: .minute()), "bpm", 1)
        case .oxygen: return (.oxygenSaturation, .percent(), "%", 100)
        case .respiratoryRate: return (.respiratoryRate, .count().unitDivided(by: .minute()), "breaths/min", 1)
        case .temperature: return (.bodyTemperature, .degreeCelsius(), "°C", 1)
        case .foodEnergy: return (.dietaryEnergyConsumed, .kilocalorie(), "kcal", 1)
        case .protein: return (.dietaryProtein, .gram(), "g", 1)
        case .carbs: return (.dietaryCarbohydrates, .gram(), "g", 1)
        case .fat: return (.dietaryFatTotal, .gram(), "g", 1)
        case .water: return (.dietaryWater, .literUnit(with: .milli), "mL", 1)
        default: return nil
        }
    }
    static func type(_ kind: HealthDataKind) -> HKObjectType? {
        if let definition = definition(kind) { return HKObjectType.quantityType(forIdentifier: definition.0) }
        switch kind {
        case .sleep: return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .mindfulness: return HKObjectType.categoryType(forIdentifier: .mindfulSession)
        case .workouts: return HKObjectType.workoutType()
        case .rings: return HKObjectType.activitySummaryType()
        default: return nil
        }
    }
    static var readTypes: Set<HKObjectType> { Set(HealthDataKind.allCases.compactMap(type)) }
    static func read(_ kind: HealthDataKind, day: Date?, limit: Int, store: HKHealthStore) async throws -> [HealthDataRecord] {
        guard let objectType = type(kind) else { throw DiaryFailure.invalid("This data type is unavailable on this iOS version.") }
        if kind == .rings { return try await rings(day ?? Date(), store: store) }
        guard let sampleType = objectType as? HKSampleType else { return [] }
        let window = try HealthBrowseWindow(day: day)
        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: [])
        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }
        return samples.compactMap { sample in
            var value: String
            if let sample = sample as? HKQuantitySample, let definition = definition(kind) {
                let number = sample.quantity.doubleValue(for: definition.1) * definition.3
                guard number.isFinite else { return nil }
                value = "\(number.formatted(.number.precision(.fractionLength(0...2)))) \(definition.2)"
            } else if let workout = sample as? HKWorkout {
                let name: String
                switch workout.workoutActivityType { case .walking: name = "Walking"; case .running: name = "Running"; case .cycling: name = "Cycling"; case .swimming: name = "Swimming"; case .yoga: name = "Yoga"; case .traditionalStrengthTraining, .functionalStrengthTraining: name = "Strength training"; default: name = "Workout" }
                value = "\(name) · \((workout.duration / 60).formatted(.number.precision(.fractionLength(0...1)))) min"
                if let energy = workout.totalEnergyBurned { value += " · \(energy.doubleValue(for: .kilocalorie()).formatted()) kcal" }
                if let distance = workout.totalDistance { value += " · \(distance.doubleValue(for: .meterUnit(with: .kilo)).formatted()) km" }
            } else if let category = sample as? HKCategorySample {
                let stage: String
                if kind == .sleep {
                    if #available(iOS 16.0, *), category.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue { stage = "Core sleep" }
                    else if #available(iOS 16.0, *), category.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue { stage = "Deep sleep" }
                    else if #available(iOS 16.0, *), category.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue { stage = "REM sleep" }
                    else { stage = category.value == 0 ? "In bed" : (category.value == 2 ? "Awake" : "Asleep") }
                } else { stage = "Mindful session" }
                value = "\(stage) · \((sample.endDate.timeIntervalSince(sample.startDate) / 60).formatted(.number.precision(.fractionLength(0...1)))) min"
            } else { return nil }
            return HealthDataRecord(id: sample.uuid.uuidString, value: value, start: sample.startDate, end: sample.endDate, source: sample.sourceRevision.source.name)
        }
    }
    private static func rings(_ day: Date, store: HKHealthStore) async throws -> [HealthDataRecord] {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.era, .year, .month, .day], from: day); components.calendar = calendar
        let predicate = HKQuery.predicateForActivitySummary(with: components)
        let summaries: [HKActivitySummary] = try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, values, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: values ?? []) }
            }
            store.execute(query)
        }
        guard let summary = summaries.first else { return [] }
        let start = calendar.startOfDay(for: day)
        return [
            HealthDataRecord(id: "move", value: "Move: \(summary.activeEnergyBurned.doubleValue(for: .kilocalorie()).formatted()) / \(summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()).formatted()) kcal", start: start, end: start, source: "Apple Health activity summary"),
            HealthDataRecord(id: "exercise", value: "Exercise: \(summary.appleExerciseTime.doubleValue(for: .minute()).formatted()) / \(summary.appleExerciseTimeGoal.doubleValue(for: .minute()).formatted()) min", start: start, end: start, source: "Apple Health activity summary"),
            HealthDataRecord(id: "stand", value: "Stand: \(summary.appleStandHours.doubleValue(for: .count()).formatted()) / \(summary.appleStandHoursGoal.doubleValue(for: .count()).formatted()) hours", start: start, end: start, source: "Apple Health activity summary")
        ]
    }
}
