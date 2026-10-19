import Foundation

struct Profile: Codable {
    var name: String?
    var age: Int?
    var activityLevel: String?
    var goalWeight: Double?
    var goalNote: String?
    var excludedIngredients: [String]?
    var height: Double?
    var weight: Double?
    var target: Double?
    var goal = ""
    var preferences = ""
    var weightMeasuredAt: Date?
    var weightSource: String?
    var weightEntryID: UUID?
}
struct Food: Identifiable, Codable {
    var id = UUID()
    var name: String
    var calories: Int
    var date = Date()
    var category: String?
}
struct Meal: Identifiable, Codable {
    var id = UUID()
    let name: String
    let detail: String
    let calories: Int
    let vegetarian: Bool
    func matches(preference: String, excluding ingredients: [String] = []) -> Bool {
        guard preference != "Vegetarian" || vegetarian else { return false }
        let searchable = name + " " + detail
        return !ingredients.contains { searchable.localizedCaseInsensitiveContains($0) }
    }
    static func exclusionTerms(_ text: String) -> [String] {
        var result: [String] = []
        for part in text.split(separator: ",") {
            let term = part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !term.isEmpty && !result.contains(term) { result.append(term) }
        }
        return result
    }

}
struct WaterEntry: Identifiable, Codable { var id = UUID(); var date = Date(); var milliliters: Int }
struct WeightEntry: Identifiable, Codable { var id = UUID(); var date = Date(); var kilograms: Double; var source: String? }
struct PlannedMeal: Identifiable, Codable { var id = UUID(); var date: Date; var name: String; var calories: Int; var category: String }
