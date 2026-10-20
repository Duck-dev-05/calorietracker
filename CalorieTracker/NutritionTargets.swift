import Foundation

struct MacroAllocation: Codable, Equatable {
    let protein: Int
    let carbohydrate: Int
    let fat: Int
    func validate() throws {
        guard [protein, carbohydrate, fat].allSatisfy({ (0...100).contains($0) }), protein + carbohydrate + fat == 100 else { throw DiaryFailure.invalid("Macro percentages must be whole numbers from 0 to 100 and total 100%.") }
    }
    func grams(calories: Double) throws -> NutrientValues {
        try validate()
        let values = NutrientValues(calories: calories, protein: calories * Double(protein) / 400, carbohydrate: calories * Double(carbohydrate) / 400, fat: calories * Double(fat) / 900)
        try values.validated(); return values
    }
}
struct EnergyEstimate: Codable, Equatable {
    let age: Int
    let heightCM: Double
    let weightKG: Double
    let maleCoefficient: Bool
    let activityFactor: Double
    let applicable: Bool
    var resting: Double { 10 * weightKG + 6.25 * heightCM - 5 * Double(age) + (maleCoefficient ? 5 : -161) }
    var maintenance: Double { resting * activityFactor }
    func validate() throws {
        guard applicable, (19...78).contains(age), heightCM.isFinite, (80...250).contains(heightCM), weightKG.isFinite, (20...400).contains(weightKG), activityFactor.isFinite, (1...2.5).contains(activityFactor), resting.isFinite, resting > 0, maintenance.isFinite, (500...10000).contains(maintenance.rounded()) else { throw DiaryFailure.invalid("Check all estimate inputs. This estimate is limited to healthy adults aged 19–78 who are not pregnant or breastfeeding. Manual targets remain available.") }
    }
}
struct NutritionTarget: Codable, Identifiable, Equatable {
    var id = UUID()
    let effectiveDay: String
    let calories: Double?
    let allocation: MacroAllocation?
    let method: String
    var estimate: EnergyEstimate? = nil
    var createdAt = Date()
    static func dayKey(_ date: Date, timeZone: TimeZone = .current) -> String {
        guard date.timeIntervalSinceReferenceDate.isFinite else { return "" }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let fields = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = fields.year, let month = fields.month, let day = fields.day else { return "" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
    static func validDay(_ key: String) -> Bool {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard key.count == 10, let date = formatter.date(from: key), (1970...2099).contains(formatter.calendar.component(.year, from: date)) else { return false }
        return formatter.string(from: date) == key
    }
    func validate() throws {
        guard Self.validDay(effectiveDay), createdAt.timeIntervalSinceReferenceDate.isFinite,
              createdAt >= Date(timeIntervalSince1970: 0), createdAt < Date(timeIntervalSince1970: 4_102_444_800), ["manual-v1", "legacy-manual-v1", "mifflin-st-jeor-v1"].contains(method) else { throw DiaryFailure.invalid("Invalid target date or calculation method.") }
        if let calories { guard calories.isFinite, (500...10000).contains(calories) else { throw DiaryFailure.invalid("Calorie targets must be between 500 and 10,000 kcal.") } }
        if let allocation { guard let calories else { throw DiaryFailure.invalid("Set calories before macro targets.") }; _ = try allocation.grams(calories: calories) }
        if method == "mifflin-st-jeor-v1" {
            guard let estimate else { throw DiaryFailure.invalid("The estimate inputs are missing.") }
            try estimate.validate()
            guard calories == estimate.maintenance.rounded() else { throw DiaryFailure.invalid("The target does not match the reviewed estimate.") }
        } else if estimate != nil { throw DiaryFailure.invalid("Manual targets cannot claim estimated inputs.") }
    }
    static func effective(in records: [NutritionTarget], day: String) -> NutritionTarget? {
        guard validDay(day) else { return nil }
        return records.enumerated().filter { $0.element.effectiveDay <= day }.max {
            $0.element.effectiveDay == $1.element.effectiveDay ? $0.offset < $1.offset : $0.element.effectiveDay < $1.element.effectiveDay
        }?.element
    }
}
struct MacroCoverage {
    let known: Double
    let knownEntries: Int
    let totalEntries: Int
    var complete: Bool { totalEntries > 0 && knownEntries == totalEntries }
}
struct DailyNutrition {
    let calories: Int
    let protein: MacroCoverage
    let carbohydrate: MacroCoverage
    let fat: MacroCoverage
    init(foods: [Food]) throws {
        guard foods.count <= 100_000, foods.allSatisfy({ (1...10000).contains($0.calories) }) else { throw DiaryFailure.invalid("Invalid food entries for daily nutrition.") }
        for food in foods { try food.nutrition?.validate(calories: food.calories) }
        let totals = try foods.map { try $0.nutrition?.totals() }
        func coverage(_ key: KeyPath<NutrientValues, Double?>) -> MacroCoverage {
            let values = totals.compactMap { $0?[keyPath: key] }
            return MacroCoverage(known: values.reduce(0, +), knownEntries: values.count, totalEntries: foods.count)
        }
        calories = foods.reduce(0) { $0 + $1.calories }
        protein = coverage(\.protein); carbohydrate = coverage(\.carbohydrate); fat = coverage(\.fat)
    }
}
