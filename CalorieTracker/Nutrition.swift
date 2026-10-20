import Foundation

/// Quantities convert only within the same dimension. No density/serving weight is inferred.
enum NutritionUnit: String, Codable, CaseIterable {
    case serving, gram, kilogram, milliliter, liter
    var title: String { switch self { case .serving: return "serving"; case .gram: return "g"; case .kilogram: return "kg"; case .milliliter: return "mL"; case .liter: return "L" } }
    private var dimension: Int { switch self { case .serving: return 0; case .gram, .kilogram: return 1; case .milliliter, .liter: return 2 } }
    private var scale: Double { self == .kilogram || self == .liter ? 1000 : 1 }
    func converted(_ quantity: Double, to unit: NutritionUnit) throws -> Double {
        guard dimension == unit.dimension, quantity.isFinite, quantity > 0 else { throw DiaryFailure.invalid("Choose compatible units and a positive, finite portion.") }
        let value = quantity * scale / unit.scale
        guard value.isFinite, value > 0 else { throw DiaryFailure.invalid("This portion cannot be converted safely.") }
        return value
    }
}

struct NutrientValues: Codable, Equatable {
    let calories: Double
    var protein: Double? = nil
    var carbohydrate: Double? = nil
    var fat: Double? = nil
    func validated() throws {
        guard calories.isFinite, (0...10000).contains(calories) else { throw DiaryFailure.invalid("Calories must be finite and between 0 and 10,000 kcal.") }
        for value in [protein, carbohydrate, fat].compactMap({ $0 }) {
            guard value.isFinite, (0...2500).contains(value) else { throw DiaryFailure.invalid("Known macros must be finite and between 0 and 2,500 grams. Leave unknown macros blank.") }
        }
    }
    func multiplied(by factor: Double) throws -> NutrientValues {
        try validated()
        guard factor.isFinite, factor > 0 else { throw DiaryFailure.invalid("Enter a positive, finite portion.") }
        let result = NutrientValues(calories: calories * factor, protein: protein.map { $0 * factor }, carbohydrate: carbohydrate.map { $0 * factor }, fat: fat.map { $0 * factor })
        try result.validated()
        return result
    }
}

/// Value-type snapshot: historical nutrition never depends on a live saved meal.
struct NutritionSnapshot: Codable, Equatable {
    let referenceQuantity: Double
    let referenceUnit: NutritionUnit
    let referenceNutrients: NutrientValues
    let quantity: Double
    let unit: NutritionUnit
    let source: String
    var sourceMealID: UUID? = nil
    var provenance: NutritionProvenance? = nil
    var mapping: PortionMapping? = nil
    var recipe: RecipeSnapshot? = nil

    func totals() throws -> NutrientValues {
        guard referenceQuantity.isFinite, referenceQuantity > 0, referenceQuantity <= 1_000_000,
              quantity.isFinite, quantity > 0, quantity <= 1_000_000,
              !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, source.count <= 300 else { throw DiaryFailure.invalid("Nutrition needs a valid reference portion, consumed quantity and source.") }
        try provenance?.validate()
        try mapping?.validate()
        if let recipe {
            let batch = try recipe.totals()
            guard referenceUnit == .serving, referenceQuantity == recipe.yieldServings, referenceNutrients == batch else {
                throw DiaryFailure.invalid("Recipe reference no longer matches its ingredients. Rebuild the recipe or explicitly switch to manual nutrition.")
            }
        }
        let converted = try mapping?.converted(quantity, from: unit, to: referenceUnit) ?? unit.converted(quantity, to: referenceUnit)
        return try referenceNutrients.multiplied(by: converted / referenceQuantity)
    }
    func roundedCalories() throws -> Int {
        let energy = try totals().calories.rounded()
        guard (1...10000).contains(energy) else { throw DiaryFailure.invalid("This portion must round to between 1 and 10,000 kcal.") }
        return Int(energy)
    }
    func validate(calories: Int) throws {
        guard try roundedCalories() == calories else { throw DiaryFailure.invalid("Entry calories do not match its nutrition snapshot. Review the portion before saving.") }
    }
    static func manual(calories: Int, protein: Double? = nil, carbohydrate: Double? = nil, fat: Double? = nil) -> NutritionSnapshot {
        NutritionSnapshot(referenceQuantity: 1, referenceUnit: .serving, referenceNutrients: NutrientValues(calories: Double(calories), protein: protein, carbohydrate: carbohydrate, fat: fat), quantity: 1, unit: .serving, source: "Manual entry")
    }
}

extension Meal {
    func portion(_ servings: Double) throws -> NutritionSnapshot {
        if var snapshot = nutrition {
            snapshot = NutritionSnapshot(referenceQuantity: snapshot.referenceQuantity, referenceUnit: snapshot.referenceUnit,
                referenceNutrients: snapshot.referenceNutrients, quantity: snapshot.quantity * servings,
                unit: snapshot.unit, source: snapshot.source, sourceMealID: id,
                provenance: snapshot.provenance, mapping: snapshot.mapping, recipe: snapshot.recipe)
            _ = try snapshot.roundedCalories()
            return snapshot
        }
        // Legacy saved meals have user-entered calories per serving, but unknown macros.
        let reference = try nutrition?.totals() ?? NutrientValues(calories: Double(calories))
        let result = NutritionSnapshot(referenceQuantity: 1, referenceUnit: .serving, referenceNutrients: reference, quantity: servings, unit: .serving, source: nutrition?.source ?? "User-entered saved meal", sourceMealID: id)
        _ = try result.roundedCalories()
        return result
    }
}
