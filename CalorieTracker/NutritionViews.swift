import SwiftUI

struct MacroDraft {
    var protein = ""
    var carbohydrate = ""
    var fat = ""
    init(_ snapshot: NutritionSnapshot? = nil) {
        if let snapshot, let totals = try? snapshot.totals() {
            protein = totals.protein.map { $0.formatted(.number.grouping(.never)) } ?? ""
            carbohydrate = totals.carbohydrate.map { $0.formatted(.number.grouping(.never)) } ?? ""
            fat = totals.fat.map { $0.formatted(.number.grouping(.never)) } ?? ""
        }
    }
    var valid: Bool { [protein, carbohydrate, fat].allSatisfy { $0.isEmpty || NumberDraftField.value($0, range: 0...2500) != nil } }
    func snapshot(calories: Int, preserving original: NutritionSnapshot? = nil) -> NutritionSnapshot? {
        guard valid else { return nil }
        let values = NutritionSnapshot.manual(calories: calories, protein: NumberDraftField.value(protein, range: 0...2500), carbohydrate: NumberDraftField.value(carbohydrate, range: 0...2500), fat: NumberDraftField.value(fat, range: 0...2500))
        // Keep portion/source provenance when only a name, date or category changes.
        if let original, (try? original.roundedCalories()) == calories {
            let initial = MacroDraft(original)
            if protein == initial.protein && carbohydrate == initial.carbohydrate && fat == initial.fat { return original }
        }
        return values
    }
}
struct MacroEntryFields: View {
    @Binding var draft: MacroDraft
    var body: some View {
        Section("Macros for this portion · optional") {
            NumberDraftField(title: "Protein (g)", text: $draft.protein, range: 0...2500, isOptional: true)
            NumberDraftField(title: "Carbohydrate (g)", text: $draft.carbohydrate, range: 0...2500, isOptional: true)
            NumberDraftField(title: "Fat (g)", text: $draft.fat, range: 0...2500, isOptional: true)
            Text("Leave unknown values blank. Zero means a known zero. Enter values from the same label and portion as the calories; macros are not inferred from calories.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
struct NutritionSnapshotRows: View {
    let snapshot: NutritionSnapshot?
    private func value(_ amount: Double?) -> String { amount.map { "\($0.formatted(.number.precision(.fractionLength(0...2)))) g" } ?? "Unknown" }
    var body: some View {
        if let snapshot, let totals = try? snapshot.totals() {
            ValueRow(title: "Portion", value: "\(snapshot.quantity.formatted()) \(snapshot.unit.rawValue)")
            ValueRow(title: "Protein", value: value(totals.protein))
            ValueRow(title: "Carbohydrate", value: value(totals.carbohydrate))
            ValueRow(title: "Fat", value: value(totals.fat))
            Text("Source: \(snapshot.source)").font(.caption).foregroundStyle(.secondary)
        } else { Text("Portion and macros were not recorded for this entry.").font(.footnote).foregroundStyle(.secondary) }
    }
}
