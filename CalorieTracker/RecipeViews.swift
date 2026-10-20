import SwiftUI

struct RecipeEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ingredients: [RecipeIngredient]
    @State private var yieldText: String
    @State private var adding = false
    @State private var editing: RecipeIngredient?
    let apply: (NutritionSnapshot) -> Void
    init(snapshot: NutritionSnapshot?, apply: @escaping (NutritionSnapshot) -> Void) {
        _ingredients = State(initialValue: snapshot?.recipe?.ingredients ?? [])
        _yieldText = State(initialValue: snapshot?.recipe.map { NutritionDraft.text($0.yieldServings) } ?? "")
        self.apply = apply
    }
    private var preview: NutritionSnapshot? {
        guard let yield = NutritionDraft.number(yieldText) else { return nil }
        return try? RecipeSnapshot(ingredients: ingredients, yieldServings: yield).snapshot()
    }
    private var issue: String {
        guard let yield = NutritionDraft.number(yieldText) else { return "Enter the number of servings this recipe makes." }
        do { _ = try RecipeSnapshot(ingredients: ingredients, yieldServings: yield).snapshot(); return "" }
        catch { return error.localizedDescription }
    }
    var body: some View {
        AdaptiveNavigation {
            Form {
                Section {
                    Text("Build one reusable serving from measured ingredients and the number of servings your whole recipe makes. Each ingredient keeps its own nutrition source and portion.")
                        .font(.footnote).fixedSize(horizontal: false, vertical: true)
                    NumberDraftField(title: "Recipe yield (servings)", text: $yieldText, range: 0.000001...1_000_000, placeholder: "Required")
                }
                Section("Ingredients") {
                    ForEach(ingredients) { ingredient in
                        Button { editing = ingredient } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ingredient.name).foregroundStyle(.primary)
                                Text("\(ingredient.nutrition.quantity.formatted()) \(ingredient.nutrition.unit.title) · \(ingredient.nutrition.source)")
                                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }.onDelete { ingredients.remove(atOffsets: $0) }
                    Button("Add ingredient") { adding = true }.disabled(ingredients.count >= 100)
                }
                Section("One serving preview") {
                    if let preview {
                        ValueRow(title: "Calories", value: "\((try? preview.roundedCalories()) ?? 0) kcal")
                        NutritionSnapshotRows(snapshot: preview, showRecipe: false)
                    } else { Text(issue).font(.footnote).foregroundStyle(.secondary) }
                    Text("A macro stays unknown if any ingredient is missing it. Batch totals are limited to 10,000 kcal and 2,500 g per macro. No cooking-loss, density or yield is guessed. Apply changes this draft; save the meal on the previous page.")
                        .font(.footnote).fixedSize(horizontal: false, vertical: true)
                }
            }.navigationTitle("Recipe ingredients").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") { if let preview { apply(preview); dismiss() } }.disabled(preview == nil)
                    }
                }
                .sheet(isPresented: $adding) {
                    RecipeIngredientEditor { ingredients.append($0) }.adaptiveEntrySheet()
                }
                .sheet(item: $editing) { ingredient in
                    RecipeIngredientEditor(existing: ingredient) { changed in
                        if let index = ingredients.firstIndex(where: { $0.id == changed.id }) { ingredients[index] = changed }
                    }.adaptiveEntrySheet()
                }
        }
    }
}
private struct RecipeIngredientEditor: View {
    @Environment(\.dismiss) private var dismiss
    let existing: RecipeIngredient?
    let apply: (RecipeIngredient) -> Void
    @State private var name: String
    @State private var nutrition: NutritionSnapshot?
    init(existing: RecipeIngredient? = nil, apply: @escaping (RecipeIngredient) -> Void) {
        self.existing = existing; self.apply = apply
        _name = State(initialValue: existing?.name ?? "")
        _nutrition = State(initialValue: existing?.nutrition.snapshot)
    }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 500 && nutrition != nil }
    var body: some View {
        AdaptiveNavigation {
            Form {
                Section("Ingredient") { TextField("Name", text: $name) }
                NutritionSelectionSection(snapshot: $nutrition, allowRecipe: false)
            }.navigationTitle(existing == nil ? "Add ingredient" : "Edit ingredient").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            guard let nutrition, valid else { return }
                            var ingredient = RecipeIngredient(name: name.trimmingCharacters(in: .whitespacesAndNewlines), nutrition: IngredientNutrition(nutrition))
                            if let existing { ingredient.id = existing.id }
                            apply(ingredient); dismiss()
                        }.disabled(!valid)
                    }
                }
        }
    }
}

struct NutritionMetadataScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NutritionDraft
    @State private var sourceEnabled: Bool
    @State private var source: NutritionProvenance
    @State private var dated: Bool
    @State private var date: Date
    @State private var mappingEnabled: Bool
    @State private var grams: String
    @State private var ml: String
    @State private var density: String
    let apply: (NutritionDraft) -> Void
    init(draft: NutritionDraft, apply: @escaping (NutritionDraft) -> Void) {
        _draft = State(initialValue: draft); self.apply = apply
        _sourceEnabled = State(initialValue: draft.provenance != nil)
        _source = State(initialValue: draft.provenance ?? NutritionProvenance())
        _dated = State(initialValue: draft.provenance?.retrievedAt != nil)
        _date = State(initialValue: draft.provenance?.retrievedAt ?? Date())
        _mappingEnabled = State(initialValue: draft.mapping != nil)
        _grams = State(initialValue: draft.mapping?.gramsPerServing.map(NutritionDraft.text) ?? "")
        _ml = State(initialValue: draft.mapping?.millilitersPerServing.map(NutritionDraft.text) ?? "")
        _density = State(initialValue: draft.mapping?.gramsPerMilliliter.map(NutritionDraft.text) ?? "")
    }
    private func result() throws -> NutritionDraft {
        var result = draft
        if sourceEnabled {
            var record = source; record.retrievedAt = dated ? date : nil
            try record.validate(); result.provenance = record
        } else { result.provenance = nil }
        if mappingEnabled {
            func number(_ text: String, original: Double?) throws -> Double? {
                if text.isEmpty { return nil }
                if let original, text == NutritionDraft.text(original) { return original }
                guard let value = NutritionDraft.number(text) else { throw DiaryFailure.invalid("Enter valid mapping numbers or leave unused fields blank.") }
                return value
            }
            let mapping = PortionMapping(gramsPerServing: try number(grams, original: draft.mapping?.gramsPerServing),
                millilitersPerServing: try number(ml, original: draft.mapping?.millilitersPerServing),
                gramsPerMilliliter: try number(density, original: draft.mapping?.gramsPerMilliliter))
            try mapping.validate()
            guard mapping.gramsPerServing != nil || mapping.millilitersPerServing != nil || mapping.gramsPerMilliliter != nil else { throw DiaryFailure.invalid("Enter at least one known mapping, or turn mappings off.") }
            result.mapping = mapping
        } else { result.mapping = nil }
        return result
    }
    private var issue: String? { do { _ = try result(); return nil } catch { return error.localizedDescription } }
    var body: some View {
        AdaptiveNavigation {
            Form {
                Section("Structured source") {
                    Toggle("Record source details", isOn: $sourceEnabled)
                    if sourceEnabled {
                        Picker("Source type", selection: $source.kind) {
                            ForEach(NutritionProvenance.Kind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        TextField("Provider / manufacturer", text: $source.provider)
                        TextField("Source record ID", text: $source.sourceID)
                        TextField("Data version / label version", text: $source.version)
                        TextField("HTTPS source URL (optional)", text: $source.url).keyboardType(.URL).textInputAutocapitalization(.never).disableAutocorrection(true)
                        Toggle("Record retrieval date", isOn: $dated)
                        if dated { DatePicker("Retrieved", selection: $date, displayedComponents: [.date, .hourAndMinute]) }
                        Text("External data requires provider, ID, version and retrieval date. This records attribution; it does not verify a source or fetch nutrition.").font(.footnote)
                    }
                }
                Section("Explicit portion conversions") {
                    Toggle("Use known portion mappings", isOn: $mappingEnabled)
                    if mappingEnabled {
                        NumberDraftField(title: "Grams per serving", text: $grams, range: 0.000001...1_000_000, isOptional: true)
                        NumberDraftField(title: "mL per serving", text: $ml, range: 0.000001...1_000_000, isOptional: true)
                        NumberDraftField(title: "Density (g/mL)", text: $density, range: 0.000001...1_000_000, isOptional: true)
                    }
                    Text("Use measured or source-provided values only. Leave unknown mappings blank. These apply to this exact food/reference; a serving size is never inferred.").font(.footnote)
                }
                if let issue { Section { Text(issue).foregroundStyle(.red).font(.footnote) } }
            }.navigationTitle("Source & conversions").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") { if let result = try? result() { apply(result); dismiss() } }.disabled(issue != nil)
                    }
                }
        }
    }
}
