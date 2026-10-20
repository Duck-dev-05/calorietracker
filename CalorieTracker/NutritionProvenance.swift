import Foundation

struct NutritionProvenance: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable { case manual, label, external, recipe }
    var kind: Kind = .manual
    var provider = ""
    var sourceID = ""
    var version = ""
    var retrievedAt: Date? = nil
    var url = ""
    func validate() throws {
        guard provider.count <= 200, sourceID.count <= 300, version.count <= 100, url.count <= 2000 else { throw DiaryFailure.invalid("Nutrition source details are too long.") }
        if kind == .external {
            guard !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, retrievedAt != nil else {
                throw DiaryFailure.invalid("External sources require provider, source ID, version and retrieval date.")
            }
        }
        if let date = retrievedAt {
            guard date >= Date(timeIntervalSince1970: 0), date < Date(timeIntervalSince1970: 4_102_444_800) else { throw DiaryFailure.invalid("Invalid source retrieval date.") }
        }
        if !url.isEmpty {
            guard let address = URL(string: url), address.scheme == "https", address.host != nil, address.user == nil, address.password == nil else { throw DiaryFailure.invalid("Use an HTTPS source URL without credentials.") }
        }
    }
}

/// Explicit values supplied by the user/source, never inferred from a food name.
struct PortionMapping: Codable, Equatable {
    var gramsPerServing: Double? = nil
    var millilitersPerServing: Double? = nil
    var gramsPerMilliliter: Double? = nil
    func validate() throws {
        for value in [gramsPerServing, millilitersPerServing, gramsPerMilliliter].compactMap({ $0 }) {
            guard value.isFinite, (0.000001...1_000_000).contains(value) else { throw DiaryFailure.invalid("Mappings must be positive, finite and within supported limits.") }
        }
        if let gramsPerServing, let millilitersPerServing, let gramsPerMilliliter {
            guard abs(gramsPerServing - millilitersPerServing * gramsPerMilliliter) <= max(0.000001, gramsPerServing * 0.000001) else {
                throw DiaryFailure.invalid("Serving weight, volume and density disagree. Review the mapping.")
            }
        }
    }
    func converted(_ quantity: Double, from: NutritionUnit, to: NutritionUnit) throws -> Double {
        try validate()
        if let direct = try? from.converted(quantity, to: to) { return direct }
        guard quantity.isFinite, quantity > 0 else { throw DiaryFailure.invalid("Enter a positive portion.") }
        let density = gramsPerMilliliter ?? gramsPerServing.flatMap { grams in millilitersPerServing.map { grams / $0 } }
        let servingGrams = gramsPerServing ?? millilitersPerServing.flatMap { volume in density.map { volume * $0 } }
        let servingML = millilitersPerServing ?? gramsPerServing.flatMap { grams in density.map { grams / $0 } }
        func grams(_ unit: NutritionUnit) -> Double? {
            switch unit {
            case .gram: return 1
            case .kilogram: return 1000
            case .milliliter: return density
            case .liter: return density.map { $0 * 1000 }
            case .serving: return servingGrams
            }
        }
        func ml(_ unit: NutritionUnit) -> Double? {
            switch unit {
            case .gram: return density.map { 1 / $0 }
            case .kilogram: return density.map { 1000 / $0 }
            case .milliliter: return 1
            case .liter: return 1000
            case .serving: return servingML
            }
        }
        let result: Double
        if let start = grams(from), let end = grams(to) { result = quantity * start / end }
        else if let start = ml(from), let end = ml(to) { result = quantity * start / end }
        else { throw DiaryFailure.invalid("Supply an explicit serving weight, volume or density for this conversion.") }
        guard result.isFinite, result > 0 else { throw DiaryFailure.invalid("This mapping cannot convert the portion safely.") }
        return result
    }
}

struct RecipeIngredient: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var nutrition: IngredientNutrition
}
/// Non-recursive ingredient snapshot prevents nested recipe decoding.
struct IngredientNutrition: Codable, Equatable {
    var referenceQuantity: Double
    var referenceUnit: NutritionUnit
    var referenceNutrients: NutrientValues
    var quantity: Double
    var unit: NutritionUnit
    var source: String
    var provenance: NutritionProvenance?
    var mapping: PortionMapping?
    init(_ snapshot: NutritionSnapshot) {
        referenceQuantity = snapshot.referenceQuantity; referenceUnit = snapshot.referenceUnit
        referenceNutrients = snapshot.referenceNutrients; quantity = snapshot.quantity; unit = snapshot.unit
        source = snapshot.source; provenance = snapshot.provenance; mapping = snapshot.mapping
    }
    var snapshot: NutritionSnapshot {
        NutritionSnapshot(referenceQuantity: referenceQuantity, referenceUnit: referenceUnit,
            referenceNutrients: referenceNutrients, quantity: quantity, unit: unit, source: source,
            provenance: provenance, mapping: mapping)
    }
}
struct RecipeSnapshot: Codable, Equatable {
    var ingredients: [RecipeIngredient]
    var yieldServings: Double
    func totals() throws -> NutrientValues {
        guard (1...100).contains(ingredients.count), Set(ingredients.map(\.id)).count == ingredients.count,
              yieldServings.isFinite, (0.000001...1_000_000).contains(yieldServings) else { throw DiaryFailure.invalid("Add 1–100 ingredients and a positive recipe yield.") }
        var values: [NutrientValues] = []
        for ingredient in ingredients {
            guard !ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, ingredient.name.count <= 500 else { throw DiaryFailure.invalid("Each recipe ingredient needs a name.") }
            values.append(try ingredient.nutrition.snapshot.totals())
        }
        func sum(_ key: KeyPath<NutrientValues, Double?>) -> Double? {
            let known = values.compactMap { $0[keyPath: key] }
            return known.count == values.count ? known.reduce(0, +) : nil
        }
        let total = NutrientValues(calories: values.reduce(0) { $0 + $1.calories }, protein: sum(\.protein), carbohydrate: sum(\.carbohydrate), fat: sum(\.fat))
        try total.validated()
        return total
    }
    func snapshot() throws -> NutritionSnapshot {
        let total = try totals()
        let result = NutritionSnapshot(referenceQuantity: yieldServings, referenceUnit: .serving,
            referenceNutrients: total, quantity: 1, unit: .serving, source: "Calculated from recipe ingredients",
            provenance: NutritionProvenance(kind: .recipe), recipe: self)
        _ = try result.roundedCalories()
        return result
    }
}

/// Phase 1 policy: targets already include chosen activity assumptions.
/// Health active energy and workouts are informative and never added again.
enum ActivityBudgetPolicy {
    static func target(baseline: Double?, activeEnergy: Double?, workoutEnergy: Double?) throws -> Double? {
        if let baseline { guard baseline.isFinite, (500...10000).contains(baseline) else { throw DiaryFailure.invalid("Invalid baseline target.") } }
        return baseline
    }
}
