import SwiftUI

struct TargetHistoryScreen: View {
    @EnvironmentObject var diary: Diary
    private var records: [NutritionTarget] { diary.targetRecords.enumerated().sorted { $0.element.effectiveDay == $1.element.effectiveDay ? $0.offset > $1.offset : $0.element.effectiveDay > $1.element.effectiveDay }.map { $0.element } }
    var body: some View {
        List {
            Section {
                NavigationLink("Create a target change", destination: GoalsScreen())
                Text("New changes start today or later. If several revisions share a start date, the last saved revision applies. Earlier revisions stay here.").font(.footnote).foregroundStyle(.secondary)
            }
            if records.isEmpty { EmptyCard(title: "No dated targets yet", message: diary.currentTargetCalories == nil ? "Create a target in Goals to begin." : "Your existing manual target stays available for today. Its historical start date is unknown.", icon: "calendar") }
            ForEach(records) { record in
                Section("From " + record.effectiveDay) {
                    ValueRow(title: "Daily calories", value: record.calories.map { "\($0.formatted()) kcal" } ?? "Target disabled")
                    ValueRow(title: "Method", value: record.method == "mifflin-st-jeor-v1" ? "Reviewed maintenance estimate" : (record.method == "legacy-manual-v1" ? "Existing manual value first dated" : "Manual"))
                    if let allocation = record.allocation, let calories = record.calories, let grams = try? allocation.grams(calories: calories) {
                        ValueRow(title: "Protein / carbs / fat", value: "\(allocation.protein)% / \(allocation.carbohydrate)% / \(allocation.fat)%")
                        Text("Targets: \(grams.protein!.formatted()) g protein, \(grams.carbohydrate!.formatted()) g carbs, \(grams.fat!.formatted()) g fat").font(.caption)
                    }
                    if let estimate = record.estimate {
                        Text("Inputs: age \(estimate.age), \(estimate.heightCM.formatted()) cm, \(estimate.weightKG.formatted()) kg, \(estimate.maleCoefficient ? "male" : "female") coefficient, activity ×\(estimate.activityFactor.formatted()). Method: \(record.method).").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Saved \(record.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("Target history").navigationBarTitleDisplayMode(.inline)
    }
}
struct EstimateReviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var age: String
    @State private var height: String
    @State private var weight: String
    @State private var coefficient = ""
    @State private var factor = ""
    @State private var applicable = false
    let apply: (EnergyEstimate) -> Void
    init(profile: Profile, apply: @escaping (EnergyEstimate) -> Void) {
        _age = State(initialValue: profile.age.map(String.init) ?? "")
        _height = State(initialValue: profile.height.map(NutritionDraft.text) ?? "")
        _weight = State(initialValue: profile.weight.map(NutritionDraft.text) ?? "")
        self.apply = apply
    }
    private var estimate: EnergyEstimate? {
        guard let age = Int(age), let height = NutritionDraft.number(height), let weight = NutritionDraft.number(weight), let factor = NutritionDraft.number(factor), !coefficient.isEmpty else { return nil }
        let value = EnergyEstimate(age: age, heightCM: height, weightKG: weight, maleCoefficient: coefficient == "male", activityFactor: factor, applicable: applicable)
        return (try? value.validate()) == nil ? nil : value
    }
    var body: some View {
        AdaptiveNavigation {
            Form {
                Section("Your inputs") {
                    TextField("Age (19–78 years)", text: $age).keyboardType(.numberPad)
                    NumberDraftField(title: "Height (cm)", text: $height, range: 80...250)
                    NumberDraftField(title: "Weight (kg)", text: $weight, range: 20...400)
                    Picker("Equation coefficient", selection: $coefficient) { Text("Choose").tag(""); Text("Female coefficient").tag("female"); Text("Male coefficient").tag("male") }
                    NumberDraftField(title: "Activity multiplier", text: $factor, range: 1...2.5)
                    Text("Choose an overall activity multiplier you have reviewed. No default is selected. It includes your activity; Health calories will not be added again.").font(.caption).foregroundStyle(.secondary)
                    Toggle("I am a healthy adult, not pregnant or breastfeeding", isOn: $applicable)
                }
                Section("Review estimate") {
                    if let estimate {
                        ValueRow(title: "Resting energy", value: "\(Int(estimate.resting.rounded())) kcal/day")
                        ValueRow(title: "Estimated maintenance", value: "\(Int(estimate.maintenance.rounded())) kcal/day")
                        Text("Mifflin–St Jeor resting energy × your activity multiplier. This is an estimate, not a measured energy need or an automatic weight-loss target.").font(.footnote).foregroundStyle(.secondary)
                    } else { Text("Complete and check all inputs to preview. Manual entry remains available on Goals.").font(.footnote).foregroundStyle(.secondary) }
                    Link("Method and original study", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!)
                    Text("The study covered healthy adults aged 19–78. Input bounds are app limits, not recommended body measurements or activity values.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Calorie estimate").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                EditorActionBar(title: "Use estimate in draft", enabled: estimate != nil, hint: "Save Goals afterwards to apply the dated target.") {
                    if let estimate { apply(estimate); dismiss() }
                }
            }
        }
    }
}
struct MacroSummaryContent: View {
    let summary: DailyNutrition
    let target: NutrientValues?
    var body: some View {
        row("Protein", summary.protein, target?.protein)
        row("Carbs", summary.carbohydrate, target?.carbohydrate)
        row("Fat", summary.fat, target?.fat)
    }
    private func row(_ title: String, _ coverage: MacroCoverage, _ goal: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ValueRow(title: title, value: coverage.knownEntries == 0 ? "Not recorded" : "\(coverage.known.formatted(.number.precision(.fractionLength(0...2)))) g known")
            Text("Known for \(coverage.knownEntries) of \(coverage.totalEntries) food entries").font(.caption).foregroundStyle(.secondary)
            if let goal {
                Text("Target: \(goal.formatted(.number.precision(.fractionLength(0...1)))) g").font(.caption)
                if coverage.complete {
                    Text(coverage.known > goal ? "\((coverage.known - goal).formatted()) g above target" : "\((goal - coverage.known).formatted()) g remaining").font(.caption).foregroundStyle(.secondary)
                } else { Text("Remaining amount unknown: some intake is not recorded.").font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(.vertical, 5)
    }
}
struct DailyNutritionScreen: View {
    @EnvironmentObject var diary: Diary
    @State private var date = Date()
    private var foods: [Food] { diary.foods.filter { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    private var target: NutritionTarget? { diary.target(on: date) }
    private var macroTarget: NutrientValues? { guard let calories = target?.calories, let allocation = target?.allocation else { return nil }; return try? allocation.grams(calories: calories) }
    var body: some View {
        Form {
            Section { DatePicker("Day", selection: $date, in: ...diary.now, displayedComponents: .date) }
            if let summary = try? DailyNutrition(foods: foods) {
                Section("Logged nutrition") {
                    ValueRow(title: "Calories logged", value: "\(summary.calories) kcal")
                    ValueRow(title: "Food entries", value: "\(foods.count)")
                    ValueRow(title: "Calorie target", value: target != nil && target?.calories == nil ? "Target disabled" : (diary.targetCalories(on: date).map { "\($0.formatted()) kcal" } ?? "No target recorded"))
                    MacroSummaryContent(summary: summary, target: macroTarget)
                }
            } else { Section { Text("Nutrition could not be summarized. Check the recorded portions.") } }
            Section {
                if let target { Text("Target applies from \(target.effectiveDay). Method: \(target.method).").font(.footnote) }
                else { Text("Undated legacy targets are available for today only; past targets remain unknown.").font(.footnote) }
                Text("Diary entries only. Plans and dietary Health records are not counted as eaten. Missing macros are unknown, not zero. A day with no entries does not mean no food was eaten.").font(.footnote).foregroundStyle(.secondary)
                NavigationLink("Target history", destination: TargetHistoryScreen())
            }
        }.navigationTitle("Daily nutrition").navigationBarTitleDisplayMode(.inline).modifier(FollowCurrentDay(selection: $date))
    }
}
