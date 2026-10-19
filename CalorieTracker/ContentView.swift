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
    @AppStorage("accountChoiceMade") private var accountChoiceMade = false
    @AppStorage("onboardingComplete") private var onboarded = false
    @AppStorage("healthEnabled") private var healthEnabled = false
    var body: some View {
        Group {
            if !diary.canReadJournal {
                AdaptiveNavigation { JournalAccessDeniedScreen() }
            } else if diary.storageBlocked {
                AdaptiveNavigation { StorageRecoveryScreen() }
            } else if !accountChoiceMade && account.session == nil {
                AdaptiveNavigation { AccountWelcomeScreen() }
            } else if onboarded {
                TabView {
                    AdaptiveNavigation { DashboardView() }.tabItem { Label("Today", systemImage: "house.fill") }
                    AdaptiveNavigation { DiaryView() }.tabItem { Label("Diary", systemImage: "book.closed.fill") }
                    AdaptiveNavigation { MealsView() }.tabItem { Label("Meals", systemImage: "fork.knife") }
                    AdaptiveNavigation { ProgressScreen() }.tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                    AdaptiveNavigation { ProfileScreen() }.tabItem { Label("You", systemImage: "person.crop.circle") }
                }.modifier(AdaptiveTabs())
            } else { OnboardingView() }
        }.tint(nourishGreen)
        .preferredColorScheme(appearance == "System" ? nil : (appearance == "Dark" ? .dark : .light))
        .alert("Storage issue", isPresented: Binding(get: { diary.storageError != nil }, set: { if !$0 { diary.storageError = nil } })) {
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
        if (refresh || changed) && healthEnabled && !health.busy { Task { await health.refresh() } }
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
    @State private var adding = false
    private var water: Int { diary.water.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.milliliters } }
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: diary.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), title: diary.profile.name.flatMap { $0.isEmpty ? nil : "Hello, \($0)." } ?? "A little more balance.", detail: "Small choices. A healthier everyday.")
            VStack(spacing: 20) {
                HStack { Label("Daily nourishment", systemImage: "sparkles").font(.subheadline.weight(.semibold)); Spacer(); Text("TODAY").font(.caption2.bold()).tracking(1.5).foregroundStyle(.white.opacity(0.7)) }
                CalorieRing(eaten: diary.consumed, target: diary.profile.target).frame(maxWidth: .infinity)
                HStack {
                    balance("EATEN", "\(diary.consumed)")
                    Spacer(); Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 36); Spacer()
                    balance("DAILY TARGET", diary.profile.target.map { "\(Int($0))" } ?? "—")
                }
                if let remaining = diary.remaining, remaining < 0 { Text("\(-remaining) kcal above today's target").font(.footnote).foregroundStyle(.white.opacity(0.85)) }
            }.padding(24).foregroundStyle(.white).background(LinearGradient(colors: [Color(red: 0.19, green: 0.36, blue: 0.27), Color(red: 0.09, green: 0.22, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 30))
            if diary.profile.target == nil { NavigationLink(destination: GoalsScreen()) { Label("Set your calorie target", systemImage: "target") } }
            Button { adding = true } label: { Label("Log a meal", systemImage: "plus") }.buttonStyle(PrimaryAction())
            SectionHeading(title: "Your daily rhythm", subtitle: "Movement and hydration, at a glance")
            HStack(alignment: .top, spacing: 12) {
                NavigationLink(destination: HealthMetricScreen(metric: .steps)) { stat("Steps", health.steps.map { Int($0).formatted() } ?? "—", "figure.walk", NourishStyle.accent) }.buttonStyle(.plain)
                NavigationLink(destination: HealthMetricScreen(metric: .activeEnergy)) { stat("Active kcal", health.activeEnergy.map { Int($0).formatted() } ?? "—", "flame.fill", NourishStyle.peach) }.buttonStyle(.plain)
            }
            Surface {
                NavigationLink(destination: WaterScreen()) { RouteRow(title: "Stay refreshed", subtitle: "\(water) mL of water logged today", icon: "drop.fill", color: NourishStyle.blue) }.buttonStyle(.plain)
                Divider()
                NavigationLink(destination: HealthScreen()) { RouteRow(title: "Apple Health", subtitle: "View your activity and measurements", icon: "heart.fill", color: .pink) }.buttonStyle(.plain)
            }
            HStack { SectionHeading(title: "On your plate"); Spacer(); NavigationLink("Planner", destination: MealPlanScreen()).font(.subheadline.weight(.semibold)) }
            Surface {
                let plan = diary.planned.filter { Calendar.current.isDateInToday($0.date) }
                if plan.isEmpty { EmptyCard(title: "Something good is ahead", message: "Add your own meals to build a plan.", icon: "fork.knife") }
                ForEach(plan) { meal in
                    NavigationLink(destination: MealPlanScreen()) { RouteRow(title: meal.name, subtitle: "\(meal.category) · \(meal.calories) kcal", icon: "fork.knife") }.buttonStyle(.plain)
                }
                NavigationLink(destination: MealsView()) { Text("Open your meal collection").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8) }
            }
            Text("Activity is shown separately from your food target.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Nourish").navigationBarTitleDisplayMode(.inline)
        .toolbar { NavigationLink(destination: ProfileScreen()) { Image(systemName: "person.crop.circle").font(.title3) }.accessibilityLabel("Your profile") }
        .sheet(isPresented: $adding) { AddFoodView().adaptiveEntrySheet() }
    }
    private func balance(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption2.bold()).tracking(1.5).foregroundStyle(.white.opacity(0.65)); Text(value).font(.system(.title2, design: .rounded).weight(.semibold)) + Text(" kcal").font(.caption) }
    }
    private func stat(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        Surface { IconTile(icon: icon, color: color); Text(value).font(.system(.title, design: .rounded).weight(.semibold)); Text(title).font(.caption).foregroundStyle(.secondary) }
    }
}
struct DiaryView: View {
    @EnvironmentObject var diary: Diary
    @State private var date = Date()
    @State private var adding = false
    private var entries: [Food] { diary.foods.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.date < $1.date } }
    var body: some View {
        List {
            Section {
                DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text("DAILY INTAKE").font(.caption2.bold()).tracking(1.5).foregroundStyle(.secondary); Text("\(entries.reduce(0) { $0 + $1.calories }) kcal").font(.system(.title, design: .rounded).weight(.bold)) }
                    Spacer(); IconTile(icon: "fork.knife")
                }.padding(.vertical, 12)
            }
            if entries.isEmpty { EmptyCard(title: "Your diary is ready", message: "Add a food or a meal for this day.", icon: "book") }
            ForEach(mealCategories, id: \.self) { category in
                Section(category) {
                    ForEach(entries.filter { ($0.category ?? "Snacks") == category }) { food in
                        NavigationLink(destination: FoodDetailScreen(food: food)) { HStack(spacing: 12) { IconTile(icon: "fork.knife"); VStack(alignment: .leading, spacing: 4) { Text(food.name).font(.headline); Text(food.date, style: .time).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(food.calories)").font(.system(.body, design: .rounded).weight(.semibold)) } .padding(.vertical, 4) }
                            .swipeActions { Button(role: .destructive) { diary.deleteFood(food.id) } label: { Label("Delete", systemImage: "trash") } }
                    }
                }
            }
        }.listStyle(.insetGrouped).navigationTitle("Food diary").toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add food") }
        .sheet(isPresented: $adding) { AddFoodView(initialDate: date).adaptiveEntrySheet() }
        .modifier(FollowCurrentDay(selection: $date))
    }
}
struct AddFoodView: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    var initialDate = Date()
    var existing: Food? = nil
    @State private var macros = MacroDraft()
    @State private var loaded = false
    @State private var name = ""
    @State private var calories = ""
    @State private var category = "Breakfast"
    @State private var date = Date()
    @FocusState private var fieldFocused: Bool
    private var validCalories: Int? { guard let value = Int(calories), (1...10000).contains(value) else { return nil }; return value }
    var body: some View {
        AdaptiveNavigation {
            Form {
                Section("Your serving") {
                    TextField("Food or meal name", text: $name).focused($fieldFocused)
                    TextField("Calories (kcal)", text: $calories).keyboardType(.numberPad).focused($fieldFocused)
                    Picker("Meal", selection: $category) { ForEach(mealCategories, id: \.self) { Text($0) } }
                    DatePicker("When", selection: $date, in: ...Date())
                }
                MacroEntryFields(draft: $macros)
                Section { Text("Changing calories clears previously recorded macros; enter them again for the new portion. Editing nutrition replaces the reference with this manual portion. Enter calories for the portion you ate. Use its nutrition label or a trusted food reference.") }
                if let error = diary.storageError { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) } }
            }.navigationTitle(existing == nil ? "Log food" : "Edit food").navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { fieldFocused = false } }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = validCalories, let nutrition = macros.snapshot(calories: value, preserving: existing?.nutrition) else { return }
                        var food = Food(name: name.trimmingCharacters(in: .whitespacesAndNewlines), calories: value, date: date, category: category, nutrition: nutrition)
                        if let existing { food.id = existing.id }
                        if diary.upsertFood(food) { dismiss() }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || validCalories == nil || !macros.valid)
                }
            }
        }.onAppear {
            guard !loaded else { return }; loaded = true; macros = MacroDraft(existing?.nutrition)
            name = existing?.name ?? ""; calories = existing.map { String($0.calories) } ?? ""
            category = existing?.category ?? "Breakfast"; date = existing?.date ?? initialDate
        }.onChange(of: calories) { value in
            if let existing, value != String(existing.calories) { macros = MacroDraft() }
        }
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
