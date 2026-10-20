import SwiftUI

struct NutritionSnapshotRows: View {
    let snapshot: NutritionSnapshot?
    private func value(_ amount: Double?) -> String { amount.map { "\($0.formatted(.number.precision(.fractionLength(0...2)))) g" } ?? "Unknown" }
    var body: some View {
        if let snapshot, let totals = try? snapshot.totals() {
            ValueRow(title: "Reference", value: "\(snapshot.referenceQuantity.formatted()) \(snapshot.referenceUnit.title) · \(snapshot.referenceNutrients.calories.formatted()) kcal")
            ValueRow(title: "Portion", value: "\(snapshot.quantity.formatted()) \(snapshot.unit.title)")
            ValueRow(title: "Protein", value: value(totals.protein))
            ValueRow(title: "Carbohydrate", value: value(totals.carbohydrate))
            ValueRow(title: "Fat", value: value(totals.fat))
            Text("Source: \(snapshot.source)").font(.caption).foregroundStyle(.secondary)
        } else { Text("Portion and macros were not recorded for this entry.").font(.footnote).foregroundStyle(.secondary) }
    }
}

/// One reviewed draft reused by food, saved meals and planned meals. Cancel never changes the parent draft.
struct NutritionEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NutritionDraft
    let apply: (NutritionSnapshot) -> Void
    init(snapshot: NutritionSnapshot?, legacyCalories: Int?, apply: @escaping (NutritionSnapshot) -> Void) {
        _draft = State(initialValue: NutritionDraft(snapshot, legacyCalories: legacyCalories))
        self.apply = apply
    }
    private var preview: NutritionSnapshot? { try? draft.snapshot() }
    private var issue: String? {
        do { _ = try draft.snapshot(); return nil } catch { return error.localizedDescription }
    }
    var body: some View {
        AdaptiveNavigation {
            Form {
                Section("Nutrition reference") {
                    Text("Enter all nutrients from the same label or source, for the reference amount below.").font(.footnote).foregroundStyle(.secondary)
                    NumberDraftField(title: "Reference amount", text: $draft.referenceQuantity, range: 0.000001...1_000_000)
                    Picker("Reference unit", selection: $draft.referenceUnit) { ForEach(NutritionUnit.allCases, id: \.self) { Text($0.title).tag($0) } }
                    NumberDraftField(title: "Calories (kcal)", text: $draft.calories, range: 0...10000)
                    NumberDraftField(title: "Protein (g)", text: $draft.protein, range: 0...2500, isOptional: true)
                    NumberDraftField(title: "Carbohydrate (g)", text: $draft.carbohydrate, range: 0...2500, isOptional: true)
                    NumberDraftField(title: "Fat (g)", text: $draft.fat, range: 0...2500, isOptional: true)
                    Text("For per-100 g or per-100 mL labels, enter 100 and the matching unit. Blank macros mean unknown; zero means a known zero.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Your portion") {
                    NumberDraftField(title: "Quantity", text: $draft.quantity, range: 0.000001...1_000_000)
                    Picker("Portion unit", selection: $draft.unit) { ForEach(NutritionUnit.allCases, id: \.self) { Text($0.title).tag($0) } }
                    Text("Only g ↔ kg and mL ↔ L are converted. Serving weights and food density are never guessed. For a saved meal, this portion becomes one reusable serving.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Source") { TextField("Nutrition label or source", text: $draft.source); Text("Review all nutrients when changing reference calories or amounts. No macro is automatically deleted.").font(.caption).foregroundStyle(.secondary) }
                Section("Review before applying") {
                    if let preview {
                        ValueRow(title: "Portion energy", value: "\((try? preview.roundedCalories()) ?? 0) kcal")
                        NutritionSnapshotRows(snapshot: preview)
                    }
                    if let issue { Label(issue, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red) }
                    Text("Zero-calorie entries and portions rounding below 1 kcal are not supported yet. Nothing is rounded up to 1 automatically. Applying updates this draft; Save on the previous page commits it.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Nutrition & portion").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply") { if let preview { apply(preview); dismiss() } }.disabled(preview == nil) }
            }
        }
    }
}
struct NutritionSelectionSection: View {
    @Binding var snapshot: NutritionSnapshot?
    var legacyCalories: Int?
    @State private var editing = false
    var body: some View {
        Section("Nutrition & portion") {
            if let snapshot {
                ValueRow(title: "Energy", value: "\((try? snapshot.roundedCalories()) ?? 0) kcal")
                NutritionSnapshotRows(snapshot: snapshot)
            } else if let legacyCalories {
                ValueRow(title: "Recorded energy", value: "\(legacyCalories) kcal")
                Text("Legacy entry: portion and macros are unknown. Editing its name or date preserves this information.").font(.caption).foregroundStyle(.secondary)
            } else { Text("Add a reference amount, nutrients and the portion to record.").font(.subheadline).foregroundStyle(.secondary) }
            Button(snapshot == nil && legacyCalories == nil ? "Add nutrition & portion" : "Review / edit nutrition") { editing = true }
        }.sheet(isPresented: $editing) {
            NutritionEditorScreen(snapshot: snapshot, legacyCalories: legacyCalories) { snapshot = $0 }.adaptiveEntrySheet()
        }
    }
}
