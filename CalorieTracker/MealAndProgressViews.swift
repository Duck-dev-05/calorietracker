import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboardingComplete") private var complete = false
    @EnvironmentObject var diary: Diary
    @State private var step = 0
    @State private var draft = Profile()
    @State private var height = ""
    @State private var weight = ""
    @State private var target = ""
    @State private var loaded = false
    private var validSetup: Bool { (draft.name?.count ?? 0) <= 200 && (height.isEmpty || NumberDraftField.value(height, range: 80...250) != nil) && (weight.isEmpty || NumberDraftField.value(weight, range: 20...400) != nil) && (target.isEmpty || NumberDraftField.value(target, range: 500...10000) != nil) }
    var body: some View {
        AdaptiveNavigation {
            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in Capsule().fill(index <= step ? NourishStyle.accent : Color.secondary.opacity(0.15)).frame(height: 5) }
                }.padding(.horizontal, 24).padding(.top, 12)
                Text("STEP \(step + 1) OF 3").font(.caption2.bold()).tracking(2).foregroundStyle(.secondary)
                if step == 0 {
                    Spacer()
                    ZStack {
                        Circle().fill(NourishStyle.accent.opacity(0.08)).frame(width: 210, height: 210)
                        Circle().fill(NourishStyle.accent.opacity(0.08)).frame(width: 154, height: 154)
                        BrandMark(size: 126)
                    }.accessibilityHidden(true)
                    Text("Feel good.\nOne day at a time.").font(.system(.largeTitle, design: .rounded).weight(.bold)).multilineTextAlignment(.center)
                    Text("Know what you eat, explore meal ideas and keep your daily activity in view.").foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                    Spacer()
                } else if step == 1 {
                    Form {
                        Section("Make it yours") {
                            TextField("Your name (optional)", text: Binding(get: { draft.name ?? "" }, set: { draft.name = $0 }))
                            NumberDraftField(title: "Height (cm)", text: $height, range: 80...250, isOptional: true)
                            NumberDraftField(title: "Weight (kg)", text: $weight, range: 20...400, isOptional: true)
                            Picker("Goal", selection: $draft.goal) { Text("Not set").tag(""); ForEach(["Maintain", "Lose weight", "Gain weight"], id: \.self) { Text($0) } }
                        }
                        Section("Daily target") {
                            NumberDraftField(title: "Calories (kcal)", text: $target, range: 500...10000, isOptional: true)
                            Text("Enter your own measurements and manual target, or leave them blank and add them later. Nothing is prefilled.").font(.footnote)
                        }
                    }
                } else {
                    Form {
                        Section("Choose your food style") {
                            Picker("Preference", selection: $draft.preferences) { Text("Not set").tag(""); Text("Balanced").tag("Balanced"); Text("Vegetarian").tag("Vegetarian") }
                        }
                        Section("Your data, your choice") {
                            Label("Your diary stays on this device", systemImage: "lock.shield")
                            Label("Sign-in protects your personal journal", systemImage: "person.crop.circle.badge.checkmark")
                            Text("You can connect Apple Health from your profile whenever you're ready.")
                        }
                    }
                }
                HStack {
                    if step > 0 { Button("Back") { step -= 1 }.padding() }
                    Button(step == 2 ? "Save & start my day" : "Continue") {
                        if step == 2 {
                            guard validSetup else { return }; let h = NumberDraftField.value(height, range: 80...250), w = NumberDraftField.value(weight, range: 20...400), t = NumberDraftField.value(target, range: 500...10000)
                            draft.height = h; draft.weight = w; draft.target = t
                            if diary.transaction({ saved in
                                let previous = diary.currentTargetCalories; saved.profile = draft
                                if t != previous { var records = saved.targets ?? []; records.append(NutritionTarget(effectiveDay: NutritionTarget.dayKey(diary.now), calories: t, allocation: t == nil ? nil : diary.target(on: diary.now)?.allocation, method: "manual-v1")); saved.targets = records }
                            }) { complete = true }
                        } else { step += 1 }
                    }.buttonStyle(PrimaryAction()).disabled(step > 0 && !validSetup)
                }.padding()
                if let error = diary.storageError { Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal) }
            }.background(NourishStyle.canvas.ignoresSafeArea()).navigationTitle(step == 0 ? "Nourish" : "Your setup").navigationBarTitleDisplayMode(.inline)
            .toolbar { if step == 0 { Button("Set up later") { complete = true } } }
        }.onAppear {
            if !loaded { draft = diary.profile; height = draft.height?.formatted(.number.grouping(.never)) ?? ""; weight = draft.weight?.formatted(.number.grouping(.never)) ?? ""; target = diary.currentTargetCalories.map(NutritionDraft.text) ?? ""; loaded = true }
        }
    }
}
struct MealsView: View {
    @EnvironmentObject var diary: Diary
    @State private var search = ""
    @State private var onlyFits = false
    @State private var adding = false
    @State private var createdMeal: Meal?
    private var meals: [Meal] {
        diary.savedMeals.filter { meal in
            guard meal.matches(preference: diary.profile.preferences, excluding: diary.profile.excludedIngredients ?? []) else { return false }
            guard search.isEmpty || (meal.name + " " + meal.detail).localizedCaseInsensitiveContains(search) else { return false }
            if onlyFits, let remaining = diary.remaining { return meal.calories <= remaining }
            return true
        }
    }
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Your collection", title: "Saved meals", detail: "Choose a meal to log it, or create your own.")
            if let createdMeal {
                Surface {
                    Label("Meal saved", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(NourishStyle.accent)
                    Text("Your reusable serving is saved locally. It has not been added to your food diary.").font(.caption).foregroundStyle(.secondary)
                    NavigationLink(destination: MealDetailScreen(meal: createdMeal)) { RouteRow(title: createdMeal.name, subtitle: "Open to log a portion or add it to your plan", icon: "fork.knife") }.buttonStyle(.plain)
                    Button("Dismiss confirmation") { self.createdMeal = nil }.font(.caption)
                }
            }
            NavigationLink(destination: MealPlanScreen()) { Label("Open meal planner", systemImage: "calendar") }.font(.subheadline)
            if !diary.savedMeals.isEmpty {
                DisclosureGroup("Filter meals") {
                    Toggle("Fits my remaining calories", isOn: Binding(get: { onlyFits && diary.remaining != nil }, set: { onlyFits = $0 })).disabled(diary.remaining == nil)
                    Text(diary.remaining.map { "\(max(0, $0)) kcal remaining today" } ?? "Set a daily target to filter by remaining calories.").font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(meals) { meal in
                NavigationLink(destination: MealDetailScreen(meal: meal)) {
                    Surface {
                        HStack(alignment: .top, spacing: 16) {
                            IconTile(icon: meal.vegetarian ? "leaf.fill" : "fork.knife", color: meal.vegetarian ? NourishStyle.accent : NourishStyle.peach)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(meal.name).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                Text(meal.detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        Divider()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], alignment: .leading) { Pill(text: "\(meal.calories) kcal / serving"); if meal.vegetarian { Pill(text: "Vegetarian") } }
                    }
                }.buttonStyle(.plain)
            }
            if meals.isEmpty {
                Surface {
                    EmptyCard(title: diary.savedMeals.isEmpty ? "Create your first meal" : "No matching meals", message: diary.savedMeals.isEmpty ? "Give it a name, describe the ingredients and enter nutrition for your serving." : "Change your search or filters to see more of your saved meals.", icon: "fork.knife")
                }
            }
        }.navigationTitle("Meals").navigationBarTitleDisplayMode(.inline).searchable(text: $search, prompt: "Search your saved meals")
        .safeAreaInset(edge: .bottom, spacing: 0) { EditorActionBar(title: "Create meal", enabled: true, hint: "") { adding = true } }
        .sheet(isPresented: $adding) { MealEditorScreen(onSave: { meal in search = ""; onlyFits = false; createdMeal = meal }).adaptiveEntrySheet() }
    }
}

struct MealDetailScreen: View {
    @EnvironmentObject var diary: Diary
    let meal: Meal
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    private var current: Meal { diary.savedMeals.first { $0.id == meal.id } ?? meal }
    @State private var servingText = NutritionDraft.text(1)
    private var servings: Double? { NutritionDraft.number(servingText) }
    private var portion: NutritionSnapshot? { servings.flatMap { try? current.portion($0) } }
    private var portionCalories: Int? { guard let portion else { return nil }; return try? portion.roundedCalories() }
    @State private var category = "Lunch"
    @State private var date = Date()
    @State private var feedback: String?
    var body: some View {
        Form {
            Section {
                MealArtwork(meal: current).listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                Text(current.name).font(.system(.title2, design: .rounded).weight(.bold))
                Text(current.detail)
                ValueRow(title: "Your serving energy", value: portionCalories.map { "\($0) kcal" } ?? "Invalid portion")
                NutritionSnapshotRows(snapshot: portion)
                Text("Calories and ingredients were entered by you. Confirm the information for the portion you eat.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Your portion") {
                NumberDraftField(title: "Servings", text: $servingText, range: 0.000001...1_000_000)
                if portion == nil { Text("Choose a positive portion that rounds to 1–10,000 kcal and stays within supported nutrient limits.").font(.caption).foregroundStyle(.red) }
                Picker("Meal", selection: $category) { ForEach(mealCategories, id: \.self) { Text($0) } }
                Button("Log as eaten now") { if let servings, diary.logMeal(current.id, servings: servings, category: category) { feedback = "Added to today's diary." } }.disabled(portionCalories == nil)
            }
            Section("Plan ahead") {
                DatePicker("Planned day", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                Button("Add to meal plan") { if let servings, diary.logMeal(current.id, servings: servings, category: category, plannedDate: date) { feedback = "Added to your meal plan." } }.disabled(portionCalories == nil)
            }
        }.navigationTitle("Meal details").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing, onDismiss: {
            if !diary.savedMeals.contains(where: { $0.id == meal.id }) { dismiss() }
        }) { MealEditorScreen(existing: current).adaptiveEntrySheet() }
        .alert("Saved", isPresented: Binding(get: { feedback != nil }, set: { if !$0 { feedback = nil } })) { Button("OK") { feedback = nil } } message: { Text(feedback ?? "") }
    }
}
struct MealPlanScreen: View {
    @EnvironmentObject var diary: Diary
    @State private var date = Date()
    private var meals: [PlannedMeal] { diary.planned.filter { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    var body: some View {
        List {
            Section { DatePicker("Day", selection: $date, displayedComponents: .date); ValueRow(title: "Planned energy", value: "\(meals.reduce(0) { $0 + $1.calories }) kcal") }
            if meals.isEmpty { EmptyCard(title: "A day to plan", message: "Create a meal in the Meals tab, then add it to this day.", icon: "calendar") }
            ForEach(meals) { meal in
                VStack(alignment: .leading, spacing: 8) {
                    NavigationLink(destination: PlannedMealEditorScreen(existing: meal)) { Text(meal.name).font(.headline) }
                    Text("\(meal.category) · \(meal.calories) kcal").foregroundStyle(.secondary)
                    if !Calendar.current.startOfDay(for: date).isAfterToday {
                        Button("Mark as eaten") {
                            diary.consumePlan(meal.id)
                        }.buttonStyle(.bordered)
                    }
                }.swipeActions { Button(role: .destructive) { diary.deletePlan(meal.id) } label: { Label("Remove", systemImage: "trash") } }
            }
            Section { Text("Planned meals only count toward your diary after you mark them as eaten.").font(.footnote) }
        }.modifier(FollowCurrentDay(selection: $date)).navigationTitle("Meal planner").toolbar { NavigationLink(destination: PlannedMealEditorScreen(initialDate: date)) { Image(systemName: "plus") }.accessibilityLabel("Create planned meal") }
    }
}
private extension Date { var isAfterToday: Bool { self > Calendar.current.startOfDay(for: Date()) } }
struct WaterScreen: View {
    @EnvironmentObject var diary: Diary
    @State private var date = Date()
    @State private var adding = false
    @State private var editing: WaterEntry?
    private var entries: [WaterEntry] { diary.water.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.date > $1.date } }
    var body: some View {
        List {
            Section {
                DatePicker("Day", selection: $date, in: ...diary.now, displayedComponents: .date)
                Text("\(entries.reduce(0) { $0 + $1.milliliters }) mL").font(.system(.largeTitle, design: .rounded).weight(.bold))
                if Calendar.current.isDate(date, inSameDayAs: diary.now) {
                    HStack { ForEach([150, 250, 500], id: \.self) { amount in Button("+\(amount) mL") { diary.upsertWater(WaterEntry(date: diary.now, milliliters: amount)) }.buttonStyle(.bordered) } }
                }
                Button("Log a custom amount") { adding = true }
            }
            Section("Entries for this day") {
                if entries.isEmpty { EmptyCard(title: "No water logged", message: "Add your own amount for this day.", icon: "drop") }
                ForEach(entries) { entry in
                    Button { editing = entry } label: { HStack { Text(entry.date, style: .time); Spacer(); Text("\(entry.milliliters) mL"); Image(systemName: "chevron.right").font(.caption) } }.foregroundStyle(.primary)
                }
            }
        }.navigationTitle("Water history")
        .sheet(isPresented: $adding) { WaterEntryScreen(initialDate: date).adaptiveEntrySheet() }
        .sheet(item: $editing) { entry in WaterEntryScreen(existing: entry).adaptiveEntrySheet() }
        .modifier(FollowCurrentDay(selection: $date))
    }
}
struct ProgressScreen: View {
    @EnvironmentObject var diary: Diary
    @State private var logging = false
    private var days: [Date] { (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) } }
    private func total(_ date: Date) -> Int { diary.foods.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.calories } }
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Your progress", title: "See your rhythm.", detail: "A week of the meals and measurements you recorded.")
            Surface {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONSISTENCY").font(.caption2.bold()).tracking(1.5).foregroundStyle(NourishStyle.accent)
                        Text("\(days.filter { total($0) > 0 }.count) of 7 days").font(.system(.largeTitle, design: .rounded).weight(.bold))
                        Text("with food logged this week").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(); IconTile(icon: "calendar")
                }
            }
            SectionHeading(title: "Your last seven days", subtitle: "Calories from your logged servings")
            Surface {
                ForEach(days, id: \.self) { date in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(date.formatted(.dateTime.weekday(.abbreviated).day())).font(.subheadline.weight(.medium))
                            if Calendar.current.isDateInToday(date) { Pill(text: "Today") }
                            Spacer()
                            Text(total(date) > 0 ? "\(total(date)) kcal" : "No entries").font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let target = diary.targetCalories(on: date) { ProgressView(value: min(Double(total(date)) / max(1, target), 1)).tint(nourishGreen) }
                    }.padding(.vertical, 6)
                    if date != days.last { Divider() }
                }
                Text("Bars use the target recorded for that day. Undated historical targets are unknown. An empty day means no entries, not zero food eaten.").font(.caption).foregroundStyle(.secondary)
            }
            SectionHeading(title: "Beyond the numbers")
            NavigationLink(destination: WeightHistoryScreen()) {
                Surface { RouteRow(title: "Weight history", subtitle: "Review your recorded measurements", icon: "scalemass", color: NourishStyle.blue) }
            }.buttonStyle(.plain)
            Button { logging = true } label: { Label("Log a measurement", systemImage: "plus") }.buttonStyle(PrimaryAction())
        }.navigationTitle("Progress").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $logging) { WeightLogScreen().adaptiveEntrySheet() }
    }
}
struct WeightLogScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var date = Date()
    var body: some View {
        AdaptiveNavigation {
            Form {
                NumberDraftField(title: "Weight (kg)", text: $weight, range: 20...400)
                DatePicker("Measured", selection: $date, in: ...Date())
                Text("Your profile updates only when this is the latest logged measurement.").font(.footnote)
                if let error = diary.storageError { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Log weight").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard let weight = NumberDraftField.value(weight, range: 20...400) else { return }
                    if diary.logWeight(WeightEntry(date: date, kilograms: weight, source: "Manual weight log")) { dismiss() }
                }.disabled(NumberDraftField.value(weight, range: 20...400) == nil) }
            }
        }.onAppear { if weight.isEmpty { weight = diary.profile.weight?.formatted(.number.grouping(.never)) ?? "" } }
    }
}

struct MealEditorScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    var existing: Meal? = nil
    var onSave: ((Meal) -> Void)? = nil
    @State private var nutrition: NutritionSnapshot?
    @State private var name = ""
    @State private var ingredients = ""
    @State private var vegetarian = false
    @State private var loaded = false
    @State private var deleting = false
    @FocusState private var focused: Bool
    private var dirty: Bool { loaded && (name != (existing?.name ?? "") || ingredients != (existing?.detail ?? "") || nutrition != existing?.nutrition || vegetarian != (existing?.vegetarian ?? false)) }
    private var validCalories: Int? { nutrition.flatMap { try? $0.roundedCalories() } ?? existing?.calories }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 500 && !ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ingredients.count <= 2000 && validCalories != nil }
    var body: some View {
        AdaptiveNavigation {
            Form {
                Section("Meal name") {
                    TextField("Meal name", text: $name).focused($focused).textInputAutocapitalization(.words)
                    if name.count > 500 { Text("Keep the meal name under 500 characters.").font(.caption).foregroundStyle(.red) }
                }
                Section("Ingredients & serving") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $ingredients).frame(minHeight: 130).focused($focused).accessibilityLabel("Ingredients and serving description")
                        if ingredients.isEmpty { Text("Describe the ingredients, amounts and what one serving contains.").foregroundStyle(.secondary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false).accessibilityHidden(true) }
                    }
                    if ingredients.count > 2000 { Text("Keep ingredients and serving details under 2,000 characters.").font(.caption).foregroundStyle(.red) }
                    Toggle("This meal is vegetarian", isOn: $vegetarian)
                }
                NutritionSelectionSection(snapshot: $nutrition, legacyCalories: existing?.calories)
                if let existing { Section { Button("Delete saved meal", role: .destructive) { deleting = true }.accessibilityLabel("Delete \(existing.name)") } }
                if let error = diary.storageError { Text(error).foregroundStyle(.red) }
            }.navigationTitle(existing == nil ? "Create meal" : "Edit meal").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { DiscardDraftButton(hasChanges: dirty) { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
            }
            .alert("Delete saved meal?", isPresented: $deleting) {
                Button("Delete", role: .destructive) { if let existing, diary.transaction({ $0.savedMeals?.removeAll { $0.id == existing.id } }) { dismiss() } }
                Button("Cancel", role: .cancel) { }
            } message: { Text("Your logged food and planned meals are kept. Only this reusable meal is removed.") }
        }.interactiveDismissDisabled(dirty).safeAreaInset(edge: .bottom, spacing: 0) {
            EditorActionBar(title: existing == nil ? "Save meal" : "Save changes", enabled: valid,
                hint: valid ? "Saves to Meals. Log or plan it afterwards." : "Add a name, ingredients and valid calories.", action: save)
        }.onAppear { if !loaded { nutrition = existing?.nutrition; name = existing?.name ?? ""; ingredients = existing?.detail ?? ""; vegetarian = existing?.vegetarian ?? false; loaded = true } }
    }
    private func save() {
        guard valid, let calories = validCalories else { return }
        var meal = Meal(name: name.trimmingCharacters(in: .whitespacesAndNewlines), detail: ingredients.trimmingCharacters(in: .whitespacesAndNewlines), calories: calories, vegetarian: vegetarian, nutrition: nutrition)
        if let existing { meal.id = existing.id }
        if diary.transaction({ saved in
            var meals = saved.savedMeals ?? []
            if let index = meals.firstIndex(where: { $0.id == meal.id }) { meals[index] = meal } else { meals.append(meal) }
            saved.savedMeals = meals
        }) { onSave?(meal); dismiss() }
    }
}
