import SwiftUI

let nourishGreen = NourishStyle.accent
let mealCategories = ["Breakfast", "Lunch", "Dinner", "Snacks"]

struct ContentView: View {
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var health: HealthService
    @EnvironmentObject var account: AccountStore
    @Environment(\.scenePhase) private var scenePhase
    private let dayTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("onboardingComplete") private var onboarded = false
    @AppStorage("healthEnabled") private var healthEnabled = false
    var body: some View {
        Group {
            if account.isAuthenticated && diary.storageBlocked {
                AdaptiveNavigation { StorageRecoveryScreen() }
            } else if account.isAuthenticated && !onboarded {
                OnboardingView()
            } else {
                TabView {
                    AdaptiveNavigation {
                        if account.isAuthenticated { DashboardView() }
                        else { VisitorHomeScreen() }
                    }.tabItem { Label("Today", systemImage: "house.fill") }
                    AdaptiveNavigation { SignInRequired { DiaryView() } }.tabItem { Label("Diary", systemImage: "book.closed.fill") }
                    AdaptiveNavigation { SignInRequired { MealsView() } }.tabItem { Label("Meals", systemImage: "fork.knife") }
                    AdaptiveNavigation { SignInRequired { HealthScreen() } }.tabItem { Label("Health", systemImage: "heart.fill") }
                    AdaptiveNavigation { ProfileScreen() }.tabItem { Label("Profile", systemImage: "person.crop.circle") }
                }.modifier(AdaptiveTabs()).id(account.isAuthenticated)
            }
        }.tint(nourishGreen)
        .preferredColorScheme(appearance == "System" ? nil : (appearance == "Dark" ? .dark : .light))
        .alert("Storage issue", isPresented: Binding(get: { account.isAuthenticated && diary.storageError != nil }, set: { if !$0 { diary.storageError = nil } })) {
            Button("OK") { diary.storageError = nil }
        } message: { Text(diary.storageError ?? "") }
        .onReceive(dayTimer) { _ in updateDay(refresh: false) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in updateDay(refresh: true) }
        .onChange(of: scenePhase) { phase in
            if phase == .active { updateDay(refresh: true) }
        }
    }
    private func updateDay(refresh: Bool) {
        let changed = diary.updateClock()
        health.expireOldResults()
        if account.isAuthenticated && (refresh || changed) && healthEnabled && !health.busy { Task { await health.refresh() } }
    }
}
struct EmptyCard: View {
    let title: String
    let message: String
    var icon = "leaf"
    var body: some View {
        VStack(spacing: 12) {
            IconTile(icon: icon)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(24)
    }
}
struct ValueRow: View {
    let title: String
    let value: String
    var body: some View { HStack(alignment: .firstTextBaseline, spacing: 16) { Text(title).fixedSize(horizontal: false, vertical: true); Spacer(minLength: 8); Text(value).font(.system(.body, design: .rounded).weight(.medium)).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }.padding(.vertical, 3) }
}
struct DashboardView: View {
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var health: HealthService
    @EnvironmentObject var account: AccountStore
    @State private var adding = false
    private var water: Int { diary.water.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.milliliters } }
    private var plans: [PlannedMeal] { diary.planned.filter { Calendar.current.isDateInToday($0.date) } }
    var body: some View {
        PageCanvas {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(diary.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.caption).foregroundStyle(.secondary)
                    Text("Your daily overview").font(.title2.bold())
                }
                Spacer()
                NavigationLink(destination: ProfileScreen()) { BrandMark(size: 40) }.accessibilityLabel("Open profile")
            }
            Surface {
                Text(diary.remaining.map { $0 < 0 ? "Above your target" : "Calories remaining" } ?? "Calories logged").font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(diary.remaining.map { abs($0).formatted() } ?? diary.consumed.formatted()).font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("kcal").font(.subheadline).foregroundStyle(.secondary)
                }
                if let target = diary.profile.target {
                    ProgressView(value: min(Double(diary.consumed) / max(target, 1), 1)).tint(NourishStyle.accent)
                    HStack { Text("Eaten: \(diary.consumed) kcal"); Spacer(); Text("Target: \(Int(target)) kcal") }.font(.caption).foregroundStyle(.secondary)
                } else {
                    NavigationLink("Set a daily target", destination: GoalsScreen()).font(.subheadline.weight(.semibold))
                }
                Button { adding = true } label: { Label("Log food", systemImage: "plus") }.buttonStyle(PrimaryAction())
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                NavigationLink(destination: WaterScreen()) { QuickActionTile(title: "\(water) mL", subtitle: "Water today · add water", icon: "drop.fill", color: NourishStyle.blue) }.buttonStyle(.plain)
                NavigationLink(destination: ProgressScreen()) { QuickActionTile(title: "Progress", subtitle: "Review your week", icon: "chart.bar.fill") }.buttonStyle(.plain)
            }
            Surface {
                HStack { SectionHeading(title: "Activity today"); Spacer(); NavigationLink("Health", destination: HealthScreen()).font(.subheadline) }
                ValueRow(title: "Steps", value: health.steps.map { Int($0).formatted() } ?? "Not available")
                ValueRow(title: "Active energy", value: health.activeEnergy.map { "\(Int($0)) kcal" } ?? "Not available")
                Text("Activity does not change your food target.").font(.caption).foregroundStyle(.secondary)
            }
            Surface {
                HStack { SectionHeading(title: "Planned for today"); Spacer(); NavigationLink("Planner", destination: MealPlanScreen()).font(.subheadline) }
                if plans.isEmpty {
                    Text("No meals planned.").font(.subheadline).foregroundStyle(.secondary)
                    NavigationLink("Choose a saved meal", destination: MealsView()).font(.subheadline)
                }
                ForEach(plans) { meal in
                    NavigationLink(destination: PlannedMealEditorScreen(existing: meal)) { RouteRow(title: meal.name, subtitle: "\(meal.category) · \(meal.calories) kcal", icon: "fork.knife") }.buttonStyle(.plain)
                }
            }
        }.navigationTitle("Today").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $adding) { AddFoodView().adaptiveEntrySheet() }
    }
}
struct DiaryView: View {
    @EnvironmentObject var diary: Diary
    @State private var date = Date()
    @State private var adding = false
    @State private var categoryToAdd = "Breakfast"
    @State private var search = ""
    private var entries: [Food] { diary.foods.filter { Calendar.current.isDate($0.date, inSameDayAs: date) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }.sorted { $0.date < $1.date } }
    var body: some View {
        List {
            Section {
                DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text(search.isEmpty ? "DAILY INTAKE" : "MATCHING ENTRIES").font(.caption2.bold()).tracking(1.5).foregroundStyle(.secondary); Text("\(entries.reduce(0) { $0 + $1.calories }) kcal").font(.system(.title, design: .rounded).weight(.bold)) }
                    Spacer(); IconTile(icon: "fork.knife")
                }.padding(.vertical, 12)
            }
            if entries.isEmpty { EmptyCard(title: search.isEmpty ? "No food logged" : "No matching food", message: search.isEmpty ? "Log food below to start this day." : "Try a different food name.", icon: "book") }
            ForEach(mealCategories, id: \.self) { category in
                Section {

                    ForEach(entries.filter { ($0.category ?? "Snacks") == category }) { food in
                        NavigationLink(destination: FoodDetailScreen(food: food)) { HStack(spacing: 12) { IconTile(icon: "fork.knife"); VStack(alignment: .leading, spacing: 4) { Text(food.name).font(.headline); Text(food.date, style: .time).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(food.calories)").font(.system(.body, design: .rounded).weight(.semibold)) } .padding(.vertical, 4) }
                            .swipeActions { Button(role: .destructive) { diary.deleteFood(food.id) } label: { Label("Delete", systemImage: "trash") } }
                    }
                    if search.isEmpty { Button { categoryToAdd = category; adding = true } label: { Label("Add to " + category.lowercased(), systemImage: "plus") }.padding(.vertical, 4) }
                } header: {
                    HStack { Text(category); Spacer(); Text("\(entries.filter { ($0.category ?? "Snacks") == category }.reduce(0) { $0 + $1.calories }) kcal") }
                }
            }
        }.listStyle(.insetGrouped).navigationTitle("Diary").navigationBarTitleDisplayMode(.inline).searchable(text: $search, prompt: "Find logged food")
        .sheet(isPresented: $adding) { AddFoodView(initialDate: date, initialCategory: categoryToAdd).adaptiveEntrySheet() }
        .modifier(FollowCurrentDay(selection: $date))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorActionBar(title: "Log food", enabled: true, hint: "") { categoryToAdd = "Breakfast"; adding = true }
        }
    }
}
struct AddFoodView: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    var initialDate = Date()
    var existing: Food? = nil
    var initialCategory = "Breakfast"
    @State private var nutrition: NutritionSnapshot?
    @State private var loaded = false
    @State private var startingDate = Date()
    @State private var name = ""
    @State private var category = "Breakfast"
    @State private var date = Date()
    @FocusState private var fieldFocused: Bool
    private var dirty: Bool { loaded && (name != (existing?.name ?? "") || nutrition != existing?.nutrition || category != (existing?.category ?? initialCategory) || date != startingDate) }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 500 && validCalories != nil }
    private var validCalories: Int? { nutrition.flatMap { try? $0.roundedCalories() } ?? existing?.calories }
    var body: some View {
        AdaptiveNavigation {
            Form {
                Section("Your serving") {
                    TextField("Food or meal name", text: $name).focused($fieldFocused)
                    Picker("Meal", selection: $category) { ForEach(mealCategories, id: \.self) { Text($0) } }
                    DatePicker("When", selection: $date, in: ...Date())
                }
                NutritionSelectionSection(snapshot: $nutrition, legacyCalories: existing?.calories)
                if let error = diary.storageError { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) } }
            }.navigationTitle(existing == nil ? "Log food" : "Edit food").navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { fieldFocused = false } }
                ToolbarItem(placement: .cancellationAction) { DiscardDraftButton(hasChanges: dirty) { dismiss() } }

            }
        }.interactiveDismissDisabled(dirty).safeAreaInset(edge: .bottom, spacing: 0) {
            EditorActionBar(title: existing == nil ? "Log food" : "Save changes", enabled: valid, hint: valid ? "" : "Add a food name and valid calories.", action: save)
        }.onAppear {
            guard !loaded else { return }; loaded = true; nutrition = existing?.nutrition
            name = existing?.name ?? ""
            category = existing?.category ?? initialCategory; date = existing?.date ?? initialDate; startingDate = date
        }
    }
    private func save() {
        guard valid, let calories = validCalories else { return }
        var food = Food(name: name.trimmingCharacters(in: .whitespacesAndNewlines), calories: calories, date: date, category: category, nutrition: nutrition)
        if let existing { food.id = existing.id }
        if diary.upsertFood(food) { dismiss() }
    }

}
struct FoodDetailScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    let food: Food
    @State private var editing = false
    @State private var deleting = false
    private var current: Food { diary.foods.first { $0.id == food.id } ?? food }
    var body: some View {
        Form {
            Section("Logged serving") {
                ValueRow(title: "Food", value: current.name)
                ValueRow(title: "Energy", value: "\(current.calories) kcal")
                NutritionSnapshotRows(snapshot: current.nutrition)
                ValueRow(title: "Meal", value: current.category ?? "Snacks")
                Text(current.date.formatted(date: .abbreviated, time: .shortened))
            }
            Button("Edit entry") { editing = true }
            Button("Delete entry", role: .destructive) { deleting = true }
        }.navigationTitle("Food details").sheet(isPresented: $editing) { AddFoodView(existing: current).adaptiveEntrySheet() }
        .alert("Delete this entry?", isPresented: $deleting) {
            Button("Delete", role: .destructive) { if diary.deleteFood(food.id) { dismiss() } }
            Button("Cancel", role: .cancel) { }
        }
    }
}
