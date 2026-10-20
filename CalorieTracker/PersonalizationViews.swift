import SwiftUI

/// Shared editor structure keeps the primary action reachable on long pages.
private struct PersonalEditor<Content: View>: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let valid: Bool
    let action: () -> Void
    let content: Content
    init(title: String, subtitle: String, actionTitle: String, valid: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.actionTitle = actionTitle; self.valid = valid; self.action = action; self.content = content()
    }
    var body: some View {
        PageCanvas { content }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    Button(actionTitle, action: action).buttonStyle(PrimaryAction()).disabled(!valid).opacity(valid ? 1 : 0.45)
                    Text(valid ? subtitle : "Check the highlighted fields before saving.").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
                    .frame(maxWidth: .infinity).background(.regularMaterial)
                    .overlay(alignment: .top) { Divider() }
            }
    }
}
private struct EditorHeading: View {
    let number: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.caption.weight(.bold)).foregroundStyle(NourishStyle.accent).frame(width: 30, height: 30).background(NourishStyle.accent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(.title3, design: .rounded).weight(.bold)); Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
private struct EditorNote: View {
    let text: String
    var icon = "info.circle"
    var body: some View { Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: icon) }.font(.footnote).foregroundStyle(.secondary) }
}
private struct EditorError: View {
    @EnvironmentObject var diary: Diary
    var body: some View { if let error = diary.storageError { Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.red).padding() } }
}
private struct MiniStat: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.secondary)
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct ChoiceTile: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Image(systemName: icon).font(.title2); Spacer(minLength: 0); if selected { Image(systemName: "checkmark.circle.fill").font(.caption) } }
                Text(title).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 100, alignment: .topLeading)
                .foregroundStyle(selected ? NourishStyle.accent : Color.primary)
                .background(selected ? NourishStyle.accent.opacity(0.12) : NourishStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? NourishStyle.accent : Color.primary.opacity(0.08), lineWidth: selected ? 1.5 : 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
struct PersonalDetailsScreen: View {
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var health: HealthService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var activity = "Not specified"
    @State private var loggingWeight = false
    @State private var weightBeforeLogging: Double?
    @State private var weightAtLoad: Double?
    @State private var heightAtLoad: Double?
    @State private var heightTextAtLoad = ""
    @State private var loaded = false
    @FocusState private var textFocused: Bool
    private let activities = ["Not specified", "Mostly seated", "Some daily movement", "Regular exercise", "Very active days"]
    private var ageValid: Bool { age.isEmpty || Int(age).map { (1...120).contains($0) } == true }
    private var valid: Bool { name.count <= 200 && ageValid && (height.isEmpty || NumberDraftField.value(height, range: 80...250) != nil) && (weight.isEmpty || NumberDraftField.value(weight, range: 20...400) != nil) }
    private var displayName: String { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your profile" : name }
    var body: some View {
        PersonalEditor(title: "Personal details", subtitle: "Edits apply only after a successful save.", actionTitle: "Save profile", valid: valid, action: save) {
            EditorHeading(number: "01", title: "The basics", detail: "A name for your journal. Age is optional.")
            Surface {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR NAME").font(.caption2.bold()).tracking(1.5).foregroundStyle(.secondary)
                    TextField("What should we call you?", text: $name).textContentType(.givenName).focused($textFocused).font(.title3)
                    if name.count > 200 { Text("Use no more than 200 characters.").font(.caption).foregroundStyle(.red) }
                }
                Divider()
                HStack { Text("Age"); Spacer(); TextField("Optional", text: $age).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 100).focused($textFocused); Text("years").font(.caption).foregroundStyle(.secondary) }
                if !ageValid { Text("Enter a whole number from 1 to 120, or leave this blank.").font(.caption).foregroundStyle(.red) }
            }
            EditorHeading(number: "02", title: "Body measurements", detail: "Your current measurements, in metric units.")
            Surface {
                NumberDraftField(title: "Height · cm", text: $height, range: 80...250, isOptional: true)
                Divider()
                NumberDraftField(title: "Weight · kg", text: $weight, range: 20...400, isOptional: true)
                Button { weightBeforeLogging = diary.profile.weight; loggingWeight = true } label: { Label("Add a dated weight to Progress", systemImage: "plus.circle").font(.subheadline.weight(.semibold)) }.padding(.top, 4)
                EditorNote(text: "Profile edits update your current measurement. Dated entries are tracked separately in Progress.")
            }
            EditorHeading(number: "03", title: "Your everyday rhythm", detail: "Optional context about your usual day.")
            Surface {
                HStack { IconTile(icon: "figure.walk"); Picker("Activity", selection: $activity) { ForEach(activities, id: \.self) { Text($0) } }.pickerStyle(.menu) }
                Text(activityDetail).font(.subheadline).foregroundStyle(.secondary)
            }
            healthPanel
            EditorNote(text: "Age and activity add context to your profile. Your daily calorie target is still set manually.")
            EditorError()
        }
        .sheet(isPresented: $loggingWeight, onDismiss: { if diary.profile.weight != weightBeforeLogging { weight = diary.profile.weight?.formatted(.number.grouping(.never)) ?? ""; weightAtLoad = diary.profile.weight } }) { WeightLogScreen().adaptiveEntrySheet() }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { if textFocused { Spacer(); Button("Done") { textFocused = false } } } }
        .onAppear(perform: load)
    }
    private var healthPanel: some View {
        Surface {
            HStack { IconTile(icon: "heart.fill", color: .pink); VStack(alignment: .leading, spacing: 4) { Text("Apple Health").font(.headline); Text("Import from Apple Health").font(.caption).foregroundStyle(.secondary) } }
            NavigationLink(destination: HealthMetricScreen(metric: .height)) { Text("Review Health height & measurement date") }.font(.subheadline)
            NavigationLink(destination: HealthMetricScreen(metric: .weight)) { Text("Review Health weight & measurement date") }.font(.subheadline)
            NavigationLink(destination: HealthScreen()) { Label("Open Health connection", systemImage: "arrow.up.right").font(.subheadline.weight(.semibold)) }
            Text("Health import updates your saved profile separately. Reopen this page afterwards to see imported values.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var activityDetail: String {
        switch activity {
        case "Mostly seated": return "Much of your day is spent sitting, with limited movement between tasks."
        case "Some daily movement": return "Your day includes walking, standing and everyday errands."
        case "Regular exercise": return "Planned exercise is part of your usual routine."
        case "Very active days": return "Substantial physical work or frequent exercise is part of your day."
        default: return "Leave this unspecified if your routine varies."
        }
    }
    private func load() {
        if loaded {
            if height == heightTextAtLoad && diary.profile.height != heightAtLoad {
                height = diary.profile.height.map(NutritionDraft.text) ?? ""
                heightAtLoad = diary.profile.height; heightTextAtLoad = height
            }
            if NumberDraftField.value(weight, range: 20...400) == weightAtLoad && diary.profile.weight != weightAtLoad {
                weight = diary.profile.weight?.formatted(.number.grouping(.never)) ?? ""; weightAtLoad = diary.profile.weight
            }
            return
        }
        weightAtLoad = diary.profile.weight
        let p = diary.profile; name = p.name ?? ""; age = p.age.map(String.init) ?? ""; height = p.height?.formatted(.number.grouping(.never)) ?? ""; weight = p.weight?.formatted(.number.grouping(.never)) ?? ""; activity = p.activityLevel.flatMap { activities.contains($0) ? $0 : nil } ?? "Not specified"; heightAtLoad = p.height; heightTextAtLoad = height; loaded = true
    }
    private func save() {
        guard valid else { return }
        let h = NumberDraftField.value(height, range: 80...250), w = NumberDraftField.value(weight, range: 20...400)
        if diary.transaction({ saved in
            saved.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines); saved.profile.age = Int(age)
            if height != heightTextAtLoad {
                guard saved.profile.height == heightAtLoad else { throw DiaryFailure.invalid("Height changed while this page was open. Reopen Personal details before editing height.") }
                saved.profile.height = h
            }
            if saved.profile.weight != w { saved.profile.weight = w; saved.profile.weightMeasuredAt = w == nil ? nil : diary.now; saved.profile.weightSource = w == nil ? nil : "Profile edit"; saved.profile.weightEntryID = nil }
            saved.profile.activityLevel = activity == "Not specified" ? nil : activity
        }) { dismiss() }
    }
}
struct GoalsScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sizeCategory) private var sizeCategory
    @State private var goal = ""
    @State private var target = ""
    @State private var hasGoalWeight = false
    @State private var goalWeight = ""
    @State private var note = ""
    @State private var loaded = false
    @State private var effectiveDate = Calendar.current.startOfDay(for: Date())
    @State private var macrosEnabled = false
    @State private var proteinPercent = ""
    @State private var carbsPercent = ""
    @State private var fatPercent = ""
    @State private var estimating = false
    @State private var estimate: EnergyEstimate?
    @State private var recordsAtLoad: [NutritionTarget] = []
    @State private var targetTextAtLoad = ""
    @State private var targetValueAtLoad: Double?
    @FocusState private var targetFocused: Bool
    private var calories: Double? { target == targetTextAtLoad ? targetValueAtLoad : NumberDraftField.value(target, range: 500...10000) }
    private var allocation: MacroAllocation? {
        guard macrosEnabled, let protein = Int(proteinPercent), let carbs = Int(carbsPercent), let fat = Int(fatPercent) else { return nil }
        let value = MacroAllocation(protein: protein, carbohydrate: carbs, fat: fat)
        return (try? value.validate()) != nil ? value : nil
    }
    private var valid: Bool { (target.isEmpty || calories != nil) && (!hasGoalWeight || NumberDraftField.value(goalWeight, range: 20...400) != nil) && note.count <= 500 && (!macrosEnabled || (calories != nil && allocation != nil)) }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 10), count: sizeCategory.isAccessibilityCategory ? 1 : 3) }
    var body: some View {
        PersonalEditor(title: "Goals & target", subtitle: "Save a target effective from your chosen date.", actionTitle: "Save my plan", valid: valid, action: save) {
            Text("Choose a goal and enter your daily calorie target.").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 10) {
                ChoiceTile(title: "Maintain", icon: "equal.circle", selected: goal == "Maintain") { goal = "Maintain" }
                ChoiceTile(title: "Lose weight", icon: "arrow.down.right", selected: goal == "Lose weight") { goal = "Lose weight" }
                ChoiceTile(title: "Gain weight", icon: "arrow.up.right", selected: goal == "Gain weight") { goal = "Gain weight" }
            }
            Button("Clear goal selection") { goal = "" }.font(.caption).disabled(goal.isEmpty)
            Text(goalDescription).font(.subheadline).foregroundStyle(.secondary)
            targetPanel
            Surface {
                DatePicker("Applies from", selection: $effectiveDate, in: Calendar.current.startOfDay(for: diary.now)..., displayedComponents: .date)
                Text("New targets start on this date. Earlier days keep their recorded targets.").font(.caption).foregroundStyle(.secondary)
                NavigationLink("View target history", destination: TargetHistoryScreen())
                Button("Estimate maintenance calories") { estimating = true }
            }
            Surface {
                Toggle("Set macro targets", isOn: $macrosEnabled)
                if macrosEnabled {
                    TextField("Protein %", text: $proteinPercent).keyboardType(.numberPad)
                    TextField("Carbohydrate %", text: $carbsPercent).keyboardType(.numberPad)
                    TextField("Fat %", text: $fatPercent).keyboardType(.numberPad)
                    Text("Choose your allocation. Percentages must total 100%. Grams use 4 kcal/g for protein and carbs, and 9 kcal/g for fat. No allocation is preselected.").font(.caption).foregroundStyle(.secondary)
                    if let allocation, let calories, let grams = try? allocation.grams(calories: calories) {
                        ValueRow(title: "Protein", value: "\(grams.protein!.formatted()) g/day")
                        ValueRow(title: "Carbs", value: "\(grams.carbohydrate!.formatted()) g/day")
                        ValueRow(title: "Fat", value: "\(grams.fat!.formatted()) g/day")
                    } else { Text("Enter valid whole percentages and calories to preview macro targets.").font(.caption).foregroundStyle(.red) }
                }
            }
            EditorHeading(number: "01", title: "A milestone, if you want one", detail: "Set a weight to work toward, without a deadline.")
            Surface {
                Toggle("Add a goal weight", isOn: $hasGoalWeight)
                if hasGoalWeight {
                    Divider()
                    NumberDraftField(title: "Goal weight · kg", text: $goalWeight, range: 20...400)
                }
                ValueRow(title: "Current profile weight", value: diary.profile.weight.map { String(format: "%.1f kg", $0) } ?? "Not set")
                NavigationLink(destination: ProgressScreen()) { Label("See your weight history", systemImage: "chart.line.uptrend.xyaxis").font(.subheadline) }
            }
            EditorHeading(number: "02", title: "Remember your why", detail: "An optional note, just for you.")
            Surface {
                TextEditor(text: $note).frame(minHeight: 84).accessibilityLabel("Personal goal note")
                HStack { Text("What would consistency look like for you?").font(.caption).foregroundStyle(.secondary); Spacer(); Text("\(note.count)/500").font(.caption).foregroundStyle(note.count > 500 ? Color.red : Color.secondary) }
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    EditorNote(text: "Enter a manual target or review a maintenance estimate. Choosing a goal does not automatically set a deficit or a completion date.")
                    EditorNote(text: "Apple Health activity stays separate. Dated targets preserve past comparisons. An undated legacy target is not copied into unknown past days.")
                    EditorNote(text: "Goal weight is a saved milestone. The input limits are validation limits, not recommendations.")
                }.padding(.top, 12)
            } label: { Label("How this plan works", systemImage: "info.circle").font(.subheadline.weight(.semibold)) }
            EditorError()
        }.toolbar { ToolbarItemGroup(placement: .keyboard) { if targetFocused { Spacer(); Button("Done") { targetFocused = false } } } }
        .onAppear(perform: load)
        .sheet(isPresented: $estimating) { EstimateReviewScreen(profile: diary.profile) { result in estimate = result; target = String(Int(result.maintenance.rounded())) }.adaptiveEntrySheet() }
    }
    private var targetPanel: some View {
        Surface {
            HStack { Label("DAILY ENERGY", systemImage: "flame").font(.caption.bold()); Spacer(); Pill(text: estimate != nil && estimate?.maintenance.rounded() == calories ? "ESTIMATE" : "MANUAL") }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("Not set", text: $target).keyboardType(.decimalPad).focused($targetFocused).font(.system(.largeTitle, design: .rounded).weight(.bold)).accessibilityLabel("Daily calorie target")
                Text("kcal / day").font(.subheadline).foregroundStyle(.secondary)
            }.padding(.vertical, 6)
            if !target.isEmpty && calories == nil { Text("Enter a number from 500 to 10,000.").font(.caption).foregroundStyle(.red) }
            HStack {
                Button { adjust(-50) } label: { Label("50", systemImage: "minus").frame(maxWidth: .infinity).padding(.vertical, 5) }.buttonStyle(.bordered).accessibilityLabel("Decrease target by 50 kilocalories")
                Button { adjust(50) } label: { Label("50", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 5) }.buttonStyle(.bordered).accessibilityLabel("Increase target by 50 kilocalories")
            }.disabled(calories == nil)
            Button("Turn off calorie target") { target = ""; macrosEnabled = false; estimate = nil }.font(.caption)
            Divider()
            if Calendar.current.isDate(effectiveDate, inSameDayAs: diary.now) {
            HStack(alignment: .top) { MiniStat(label: "Eaten today", value: "\(diary.consumed) kcal"); MiniStat(label: "Draft remaining", value: calories.map { "\(max(0, Int($0) - diary.consumed)) kcal" } ?? "—") }
            if let calories, Int(calories) < diary.consumed { Text("\(diary.consumed - Int(calories)) kcal above this draft target today.").font(.caption).foregroundStyle(.secondary) }
            } else { Text("This future target does not change today's balance.").font(.caption).foregroundStyle(.secondary) }
        }
    }
    private var goalDescription: String {
        switch goal { case "": return "Choose a direction when you're ready. No goal is selected yet."; case "Lose weight": return "Focus on a weight-loss goal while keeping your calorie target under your control."; case "Gain weight": return "Work toward a weight-gain goal and follow your consistency over time."; default: return "Build a steady routine and keep an eye on your everyday intake." }
    }
    private func adjust(_ delta: Double) { guard let calories else { return }; target = min(10000, max(500, calories + delta)).formatted(.number.grouping(.never)) }
    private func load() {
        guard !loaded else { return }; let p = diary.profile; goal = p.goal; target = diary.currentTargetCalories.map(NutritionDraft.text) ?? ""; hasGoalWeight = p.goalWeight != nil; goalWeight = (p.goalWeight ?? p.weight)?.formatted(.number.grouping(.never)) ?? ""; note = p.goalNote ?? ""; recordsAtLoad = diary.targetRecords; targetTextAtLoad = target; targetValueAtLoad = diary.currentTargetCalories
        effectiveDate = Calendar.current.startOfDay(for: diary.now)
        if let current = diary.target(on: diary.now) {
            estimate = current.estimate
            if let allocation = current.allocation { macrosEnabled = true; proteinPercent = String(allocation.protein); carbsPercent = String(allocation.carbohydrate); fatPercent = String(allocation.fat) }
        }
        loaded = true
    }
    private func save() {
        guard valid else { return }
        let acceptedEstimate = estimate.flatMap { $0.maintenance.rounded() == calories ? $0 : nil }
        let record = NutritionTarget(effectiveDay: NutritionTarget.dayKey(effectiveDate), calories: calories, allocation: allocation, method: acceptedEstimate == nil ? "manual-v1" : "mifflin-st-jeor-v1", estimate: acceptedEstimate)
        if diary.saveTarget(record, expectedRecords: recordsAtLoad, updateProfile: { profile in
            profile.goal = goal; profile.goalWeight = hasGoalWeight ? NumberDraftField.value(goalWeight, range: 20...400) : nil
            profile.goalNote = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines)
        }) { dismiss() }
    }
}
struct PreferencesScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sizeCategory) private var sizeCategory
    @State private var style = ""
    @State private var exclusions = ""
    @State private var loaded = false
    @FocusState private var focused: Bool
    private var terms: [String] { Meal.exclusionTerms(exclusions) }
    private var valid: Bool { terms.count <= 20 && terms.allSatisfy { $0.count <= 50 } }
    private var matches: [Meal] { diary.savedMeals.filter { $0.matches(preference: style, excluding: terms) } }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeCategory.isAccessibilityCategory ? 1 : 2) }
    var body: some View {
        PersonalEditor(title: "Food preferences", subtitle: "Changes apply to meal ideas after you save.", actionTitle: "Save my preferences", valid: valid, action: save) {
            VStack(alignment: .leading, spacing: 10) {
                                Text("Food preferences").font(.title2.bold())
                Text("A few choices to make your next meal easier.").font(.subheadline).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ChoiceTile(title: "Balanced", icon: "fork.knife", selected: style == "Balanced") { style = "Balanced" }
                ChoiceTile(title: "Vegetarian", icon: "leaf", selected: style == "Vegetarian") { style = "Vegetarian" }
            }
            Button("Clear food style") { style = "" }.font(.caption).disabled(style.isEmpty)
            Text(style.isEmpty ? "No food style selected. All of your saved meals are shown." : style == "Vegetarian" ? "Meat-free ideas, with dairy included. This filter is not vegan." : "All of your saved meals, without a vegetarian filter.").font(.subheadline).foregroundStyle(.secondary)
            ingredientPanel
            HStack(alignment: .firstTextBaseline) { SectionHeading(title: "Your menu preview", subtitle: "Based on the choices above"); Spacer(); Pill(text: "\(matches.count) ideas") }
            if matches.isEmpty { Surface { EmptyCard(title: diary.savedMeals.isEmpty ? "Your meal collection is empty" : "No meals match", message: diary.savedMeals.isEmpty ? "Add your own meals in the Meals tab to preview them here." : "Remove an ingredient filter or try another food style.", icon: "fork.knife") } }
            else if sizeCategory.isAccessibilityCategory { ForEach(matches) { meal in mealPreview(meal) } }
            else {
                ScrollView(.horizontal, showsIndicators: false) { HStack(alignment: .top, spacing: 14) { ForEach(matches) { meal in mealPreview(meal).frame(width: 245) } }.padding(.vertical, 2) }
            }
            EditorNote(text: "This is a preview of unsaved preferences. Your existing food diary and planned meals stay intact.", icon: "checkmark.circle")
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    EditorNote(text: "Exclusions hide matching words in meal names and descriptions. Spelling differences and unlisted ingredients can be missed.")
                    EditorNote(text: "These filters are not verified allergy or medical-diet checks. Review full ingredients and preparation before choosing food.")
                }.padding(.top, 12)
            } label: { Label("About ingredient filtering", systemImage: "info.circle").font(.subheadline.weight(.semibold)) }
            EditorError()
        }.toolbar { ToolbarItemGroup(placement: .keyboard) { if focused { Spacer(); Button("Done") { focused = false } } } }
        .onAppear { if !loaded { style = diary.profile.preferences; exclusions = (diary.profile.excludedIngredients ?? []).joined(separator: ", "); loaded = true } }
    }
    private var ingredientPanel: some View {
        Surface {
            HStack { SectionHeading(title: "Leave these off the plate", subtitle: "Optional ingredient-word exclusions"); Spacer(); if !terms.isEmpty { Button("Clear") { exclusions = "" }.font(.caption.weight(.semibold)) } }
            TextField("Type ingredients, separated by commas", text: $exclusions).focused($focused).textInputAutocapitalization(.never).disableAutocorrection(true).padding(14).background(NourishStyle.canvas, in: RoundedRectangle(cornerRadius: 14))
            if !terms.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(terms, id: \.self) { term in
                        Button { remove(term) } label: { HStack(spacing: 6) { Text(term).lineLimit(2); Image(systemName: "xmark").font(.caption2.bold()) }.font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 9).frame(maxWidth: .infinity).background(NourishStyle.accent.opacity(0.1), in: Capsule()) }.buttonStyle(.plain).foregroundStyle(NourishStyle.accent).accessibilityLabel("Remove exclusion: \(term)")
                    }
                }
            }
            Text(valid ? "\(terms.count) of 20 ingredient terms" : "Use up to 20 terms, with a maximum of 50 characters each.").font(.caption).foregroundStyle(valid ? Color.secondary : Color.red)
        }
    }
    private func mealPreview(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MealArtwork(meal: meal)
            Text(meal.name).font(.system(.headline, design: .rounded)).fixedSize(horizontal: false, vertical: true)
            Text(meal.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("\(meal.calories) kcal").font(.caption.weight(.semibold)).foregroundStyle(NourishStyle.accent)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(NourishStyle.surface, in: RoundedRectangle(cornerRadius: 22))
    }
    private func remove(_ term: String) { exclusions = terms.filter { $0 != term }.joined(separator: ", ") }
    private func toggle(_ term: String) { if terms.contains(term) { remove(term) } else { exclusions = (terms + [term]).joined(separator: ", ") } }
    private func save() { guard valid else { return }; if diary.transaction({ $0.profile.preferences = style; $0.profile.excludedIngredients = terms.isEmpty ? nil : terms }) { dismiss() } }
}
