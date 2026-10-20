import Foundation

enum HealthDataKind: String, CaseIterable, Identifiable {
    case steps, activeEnergy, restingEnergy, walkingDistance, cyclingDistance, flights, exercise, stand, rings, workouts
    case height, weight, bmi, bodyFat, heartRate, restingHeartRate, oxygen, respiratoryRate, temperature
    case sleep, mindfulness, foodEnergy, protein, carbs, fat, water
    var id: String { rawValue }
    var title: String {
        switch self {
        case .steps: return "Steps"; case .activeEnergy: return "Active energy"; case .restingEnergy: return "Resting energy"
        case .walkingDistance: return "Walking + running distance"; case .cyclingDistance: return "Cycling distance"; case .flights: return "Flights climbed"
        case .exercise: return "Exercise minutes"; case .stand: return "Stand minutes"; case .rings: return "Activity rings"; case .workouts: return "Workouts"
        case .height: return "Height"; case .weight: return "Weight"; case .bmi: return "Body mass index"; case .bodyFat: return "Body fat"
        case .heartRate: return "Heart rate"; case .restingHeartRate: return "Resting heart rate"; case .oxygen: return "Blood oxygen"
        case .respiratoryRate: return "Respiratory rate"; case .temperature: return "Body temperature"
        case .sleep: return "Sleep"; case .mindfulness: return "Mindful sessions"; case .foodEnergy: return "Food energy"
        case .protein: return "Dietary protein"; case .carbs: return "Dietary carbs"; case .fat: return "Dietary fat"; case .water: return "Dietary water"
        }
    }
    var group: String {
        switch self {
        case .steps, .activeEnergy, .restingEnergy, .walkingDistance, .cyclingDistance, .flights, .exercise, .stand, .rings, .workouts: return "Activity & Fitness"
        case .height, .weight, .bmi, .bodyFat: return "Body measurements"
        case .heartRate, .restingHeartRate, .oxygen, .respiratoryRate, .temperature: return "Heart & respiratory"
        case .sleep, .mindfulness: return "Sleep & mindfulness"
        default: return "Nutrition in Apple Health"
        }
    }
    static let groups = ["Activity & Fitness", "Body measurements", "Heart & respiratory", "Sleep & mindfulness", "Nutrition in Apple Health"]
}
struct HealthDataRecord: Identifiable {
    let id: String
    let value: String
    let start: Date
    let end: Date
    let source: String
}
struct HealthBrowseResult {
    var records: [HealthDataRecord] = []
    var error: String?
}

/// Local calendar days can be shorter or longer than 24 hours. Never query beyond now.
struct HealthBrowseWindow {
    let start: Date?
    let end: Date
    init(day: Date?, now: Date = Date(), calendar: Calendar = .current) throws {
        guard now.timeIntervalSinceReferenceDate.isFinite else { throw DiaryFailure.invalid("Invalid query date.") }
        guard let day else { start = nil; end = now; return }
        guard day.timeIntervalSinceReferenceDate.isFinite else { throw DiaryFailure.invalid("Invalid selected day.") }
        let beginning = calendar.startOfDay(for: day)
        guard beginning <= now, let following = calendar.date(byAdding: .day, value: 1, to: beginning) else { throw DiaryFailure.invalid("Choose today or an earlier day.") }
        start = beginning; end = min(following, now)
    }
}
