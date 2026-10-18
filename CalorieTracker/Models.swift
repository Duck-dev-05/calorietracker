import Foundation

struct Profile: Codable {
    var name: String?
    var age: Int?
    var height = 170.0
    var weight = 70.0
    var target = 2000.0
    var goal = "Maintain"
    var preferences = "Balanced"
}
struct Food: Identifiable, Codable {
    var id = UUID()
    var name: String
    var calories: Int
    var date = Date()
    var category: String?
}
struct Meal: Identifiable {
    let name: String
    let detail: String
    let calories: Int
    let vegetarian: Bool
    var id: String { name }
    static let ideas = [
        Meal(name: "Greek yogurt bowl", detail: "Plain yogurt, oats, berries and almonds", calories: 350, vegetarian: true),
        Meal(name: "Chicken rice bowl", detail: "Grilled chicken, brown rice and vegetables", calories: 550, vegetarian: false),
        Meal(name: "Tofu rainbow bowl", detail: "Tofu, quinoa, broccoli and sesame dressing", calories: 480, vegetarian: true),
        Meal(name: "Salmon & sweet potato", detail: "Baked salmon, sweet potato and leafy greens", calories: 620, vegetarian: false),
        Meal(name: "Hummus toast", detail: "Wholegrain toast, hummus, tomato and cucumber", calories: 300, vegetarian: true)
    ]
}
struct WaterEntry: Identifiable, Codable { var id = UUID(); var date = Date(); var milliliters: Int }
struct WeightEntry: Identifiable, Codable { var id = UUID(); var date = Date(); var kilograms: Double }
struct PlannedMeal: Identifiable, Codable { var id = UUID(); var date: Date; var name: String; var calories: Int; var category: String }
