import Foundation

/// Editable text stays separate from exact stored values. Unchanged fields never round-trip through display formatting.
struct NutritionDraft {
    var referenceQuantity = "1"
    var referenceUnit: NutritionUnit = .serving
    var quantity = "1"
    var unit: NutritionUnit = .serving
    var calories = ""
    var protein = ""
    var carbohydrate = ""
    var fat = ""
    var source = "Manual entry"
    private var original: NutritionSnapshot?

    init(_ original: NutritionSnapshot? = nil, legacyCalories: Int? = nil) {
        self.original = original
        if let original {
            referenceQuantity = Self.text(original.referenceQuantity)
            referenceUnit = original.referenceUnit
            quantity = Self.text(original.quantity); unit = original.unit
            calories = Self.text(original.referenceNutrients.calories)
            protein = original.referenceNutrients.protein.map(Self.text) ?? ""
            carbohydrate = original.referenceNutrients.carbohydrate.map(Self.text) ?? ""
            fat = original.referenceNutrients.fat.map(Self.text) ?? ""
            source = original.source
        } else if let legacyCalories { calories = Self.text(Double(legacyCalories)) }
    }
    static func text(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...15)))
    }
    static func number(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = Locale.current.decimalSeparator ?? "."
        guard !value.isEmpty, value.components(separatedBy: separator).count <= 2,
              value.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.union(CharacterSet(charactersIn: separator)).contains($0) }) else { return nil }
        let formatter = NumberFormatter(); formatter.locale = .current; formatter.numberStyle = .decimal
        guard let result = formatter.number(from: value)?.doubleValue, result.isFinite else { return nil }
        return result
    }
    private func resolved(_ text: String, original: Double?) throws -> Double? {
        if let original, text == Self.text(original) { return original }
        if text.isEmpty { return nil }
        guard let number = Self.number(text) else { throw DiaryFailure.invalid("Enter valid numbers using your device's decimal separator.") }
        return number
    }
    func snapshot() throws -> NutritionSnapshot {
        guard let reference = try resolved(referenceQuantity, original: original?.referenceQuantity),
              let amount = try resolved(quantity, original: original?.quantity),
              let energy = try resolved(calories, original: original?.referenceNutrients.calories) else {
            throw DiaryFailure.invalid("Enter reference calories, reference amount and your portion.")
        }
        let nutrients = NutrientValues(calories: energy,
            protein: try resolved(protein, original: original?.referenceNutrients.protein),
            carbohydrate: try resolved(carbohydrate, original: original?.referenceNutrients.carbohydrate),
            fat: try resolved(fat, original: original?.referenceNutrients.fat))
        let result = NutritionSnapshot(referenceQuantity: reference, referenceUnit: referenceUnit, referenceNutrients: nutrients,
            quantity: amount, unit: unit, source: source.trimmingCharacters(in: .whitespacesAndNewlines), sourceMealID: original?.sourceMealID)
        _ = try result.roundedCalories()
        return result
    }
}
