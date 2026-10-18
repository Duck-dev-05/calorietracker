import SwiftUI

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
@MainActor final class Diary: ObservableObject {
    @Published var profile: Profile { didSet { save() } }
    @Published var foods: [Food] { didSet { save() } }
    @Published var water: [WaterEntry] = [] { didSet { save() } }
    @Published var weights: [WeightEntry] = [] { didSet { save() } }
    @Published var planned: [PlannedMeal] = [] { didSet { save() } }
    @Published var storageError: String?
    private var canSave = true
    private let url: URL
    struct Saved: Codable { var profile: Profile; var foods: [Food]; var water: [WaterEntry]?; var weights: [WeightEntry]?; var planned: [PlannedMeal]? }
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = folder.appendingPathComponent("diary.json")
        profile = Profile(); foods = []
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let saved = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: url))
                profile = saved.profile; foods = saved.foods
                water = saved.water ?? []; weights = saved.weights ?? []; planned = saved.planned ?? []
            } catch { canSave = false; storageError = "Your saved diary could not be loaded. Close the app before adding data if you want to recover the original file." }
        }
    }
    func save() {
        guard canSave else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Saved(profile: profile, foods: foods, water: water, weights: weights, planned: planned))
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch { storageError = "Your changes could not be saved: \(error.localizedDescription)" }
    }
    var today: [Food] { foods.filter { Calendar.current.isDateInToday($0.date) } }
    var consumed: Int { today.reduce(0) { $0 + $1.calories } }
    var remaining: Int { Int(profile.target) - consumed }
}
@main struct CalorieTrackerApp: App {
    @StateObject private var diary = Diary()
    @StateObject private var health = HealthService()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(diary).environmentObject(health) }
    }
}
