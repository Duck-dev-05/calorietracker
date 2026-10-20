import SwiftUI

struct NutritionSnapshotRows: View {
    let snapshot: NutritionSnapshot?
    var showRecipe = true
    private func value(_ amount: Double?) -> String { amount.map { "\($0.formatted(.number.precision(.fractionLength(0...2)))) g" } ?? "Unknown" }
    var body: some View {
        if let snapshot, let totals = try? snapshot.totals() {
            ValueRow(title: "Reference", value: "\(snapshot.referenceQuantity.formatted()) \(snapshot.referenceUnit.title) · \(snapshot.referenceNutrients.calories.formatted()) kcal")
            ValueRow(title: "Portion", value: "\(snapshot.quantity.formatted()) \(snapshot.unit.title)")
            ValueRow(title: "Protein", value: value(totals.protein))
            ValueRow(title: "Carbohydrate", value: value(totals.carbohydrate))
            ValueRow(title: "Fat", value: value(totals.fat))
            Text("Source: \(snapshot.source)").font(.caption).foregroundStyle(.secondary)
            if let source = snapshot.provenance {
                Text("Attribution: \(source.kind.rawValue) · \(source.provider) · \(source.sourceID) · \(source.version)").font(.caption).fixedSize(horizontal: false, vertical: true)
                if let date = source.retrievedAt { Text("Retrieved \(date.formatted())").font(.caption) }
                if let url = URL(string: source.url), url.scheme == "https" { Link("Open source", destination: url).font(.caption) }
            }
            if let mapping = snapshot.mapping {
                if let grams = mapping.gramsPerServing { ValueRow(title: "Serving weight", value: "\(grams.formatted()) g") }
                if let ml = mapping.millilitersPerServing { ValueRow(title: "Serving volume", value: "\(ml.formatted()) mL") }
                if let density = mapping.gramsPerMilliliter { ValueRow(title: "Density", value: "\(density.formatted()) g/mL") }
            }
            if showRecipe, let recipe = snapshot.recipe {
                DisclosureGroup("Recipe · \(recipe.yieldServings.formatted()) servings") {
                    ForEach(recipe.ingredients) { ingredient in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(ingredient.name) · \(ingredient.nutrition.quantity.formatted()) \(ingredient.nutrition.unit.title)")
                            Text(ingredient.nutrition.source).font(.caption).foregroundStyle(.secondary)
                            if let source = ingredient.nutrition.provenance { Text("\(source.provider) · \(source.sourceID) · \(source.version)").font(.caption) }
                        }.fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else { Text("Portion and macros were not recorded for this entry.").font(.footnote).foregroundStyle(.secondary) }
    }
}

/// One reviewed draft reused by food, saved meals and planned meals. Cancel never changes the parent draft.
struct NutritionEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var metadata = false
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
                    Text("g ↔ kg and mL ↔ L convert directly. Other conversions require explicit source/portion mappings below. For a saved meal, this portion becomes one reusable serving.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Source details & portion conversions") { metadata = true }
                    if draft.recipe != nil {
                        Text("This nutrition is calculated from recipe ingredients. Edit the recipe to change its reference nutrition, or explicitly switch to manual values.").font(.footnote)
                        Button("Switch to manual nutrition", role: .destructive) { draft.recipe = nil }
                    }
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
            }.sheet(isPresented: $metadata) { NutritionMetadataScreen(draft: draft) { draft = $0 }.adaptiveEntrySheet() }
            .navigationTitle("Nutrition & portion").navigationBarTitleDisplayMode(.inline)
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
    var allowRecipe = true
    @State private var recipeEditing = false
    @State private var editing = false
    @State private var quickEntry = false
    @State private var loaded = false
    @State private var quick = NutritionDraft()
    var body: some View {
        Section("Calories & nutrition") {
            if quickEntry {
                NumberDraftField(title: "Calories (kcal)", text: $quick.calories, range: 1...10000)
                Text("Enter calories for the portion you want to save.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Add macros (optional)") {
                    NumberDraftField(title: "Protein (g)", text: $quick.protein, range: 0...2500, isOptional: true)
                    NumberDraftField(title: "Carbs (g)", text: $quick.carbohydrate, range: 0...2500, isOptional: true)
                    NumberDraftField(title: "Fat (g)", text: $quick.fat, range: 0...2500, isOptional: true)
                    Text("Leave values blank if you don't know them.").font(.caption).foregroundStyle(.secondary)
                }
                if !quick.calories.isEmpty && snapshot == nil { Text("Check calories and any macros you entered before saving.").font(.caption).foregroundStyle(.red) }
            } else if let snapshot {
                ValueRow(title: "Calories", value: "\((try? snapshot.roundedCalories()) ?? 0) kcal")
                Text("\(snapshot.quantity.formatted()) \(snapshot.unit.title)").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Nutrition details") { NutritionSnapshotRows(snapshot: snapshot) }
            } else if let legacyCalories {
                ValueRow(title: "Calories", value: "\(legacyCalories) kcal")
                Text("Portion and macros were not recorded.").font(.caption).foregroundStyle(.secondary)
            }
            Button(quickEntry ? "Use a label or change portion" : "Edit nutrition & portion") { editing = true }
            if allowRecipe {
                Button(snapshot?.recipe == nil ? "Build from recipe ingredients" : "Edit recipe ingredients") { recipeEditing = true }
            }
        }.onAppear {
            guard !loaded else { return }; loaded = true
            quickEntry = snapshot == nil && legacyCalories == nil
        }.onChange(of: quick) { value in snapshot = try? value.snapshot() }
        .sheet(isPresented: $recipeEditing) {
            RecipeEditorScreen(snapshot: snapshot) { snapshot = $0; quickEntry = false }.adaptiveEntrySheet()
        }
        .sheet(isPresented: $editing) {
            NutritionEditorScreen(snapshot: snapshot, legacyCalories: legacyCalories) { snapshot = $0; quickEntry = false }.adaptiveEntrySheet()
        }
    }
}
