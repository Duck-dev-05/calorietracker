import SwiftUI

let nourishGreen = Color(red: 0.13, green: 0.37, blue: 0.29)
let mealCategories = ["Breakfast", "Lunch", "Dinner", "Snacks"]

struct ContentView: View {
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var health: HealthService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("onboardingComplete") private var onboarded = false
    @AppStorage("healthEnabled") private var healthEnabled = false
    var body: some View {
        Group {
            if onboarded {
                TabView {
                    NavigationView { DashboardView() }.navigationViewStyle(.stack).tabItem { Label("Today", systemImage: "house.fill") }
                    NavigationView { DiaryView() }.navigationViewStyle(.stack).tabItem { Label("Diary", systemImage: "book.closed.fill") }
                    NavigationView { MealsView() }.navigationViewStyle(.stack).tabItem { Label("Meals", systemImage: "fork.knife") }
                    NavigationView { ProgressScreen() }.navigationViewStyle(.stack).tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                    NavigationView { ProfileScreen() }.navigationViewStyle(.stack).tabItem { Label("You", systemImage: "person.crop.circle") }
                }
            } else { OnboardingView() }
        }.tint(nourishGreen)
        .preferredColorScheme(appearance == "System" ? nil : (appearance == "Dark" ? .dark : .light))
        .alert("Storage issue", isPresented: Binding(get: { diary.storageError != nil }, set: { if !$0 { diary.storageError = nil } })) {
            Button("OK") { diary.storageError = nil }
        } message: { Text(diary.storageError ?? "") }
        .onChange(of: scenePhase) { phase in
            if phase == .active && healthEnabled && !health.busy { Task { await health.connect() } }
        }
    }
}
struct EmptyCard: View {
    let title: String
    let message: String
    var icon = "leaf"
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(nourishGreen)
            Text(title).font(.headline)
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(24)
    }
}
struct ValueRow: View {
    let title: String
    let value: String
    var body: some View { HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary) } }
}
struct NumericRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 1...10000
    var body: some View {
        HStack {
            Text(title); Spacer()
            TextField(title, value: Binding(get: { value }, set: { if $0.isFinite { value = min(max($0, range.lowerBound), range.upperBound) } }), format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
        }
    }
}
struct DashboardView: View {
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var health: HealthService
    @State private var adding = false
    @State private var clock = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(clock.formatted(date: .complete, time: .omitted)).font(.subheadline).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 14) {
                    Label("YOUR DAILY BALANCE", systemImage: "leaf.fill").font(.caption.bold())
                    Text("\(max(0, diary.remaining))").font(.system(size: 64, weight: .semibold, design: .rounded))
                    Text(diary.remaining >= 0 ? "kcal remaining today" : "\(-diary.remaining) kcal above your target")
                    ProgressView(value: min(Double(diary.consumed) / max(1, diary.profile.target), 1)).tint(.white)
                    HStack { Text("Eaten \(diary.consumed)"); Spacer(); Text("Target \(Int(diary.profile.target))") }.font(.subheadline)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(nourishGreen, in: RoundedRectangle(cornerRadius: 28)).foregroundStyle(.white)
                Button { adding = true } label: { Label("Log a meal", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(10) }.buttonStyle(.borderedProminent)
                HStack {
                    stat("Steps", health.steps.map { Int($0).formatted() } ?? "—", "figure.walk")
                    stat("Active kcal", health.activeEnergy.map { Int($0).formatted() } ?? "—", "flame.fill")
                }
                NavigationLink(destination: HealthScreen()) { Label("Your activity & Apple Health", systemImage: "heart.fill") }
                NavigationLink(destination: WaterScreen()) {
                    ValueRow(title: "Water today", value: "\(diary.water.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.milliliters }) mL")
                }.padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                Text("On your plate").font(.title2.bold())
                let plan = diary.planned.filter { Calendar.current.isDateInToday($0.date) }
                if plan.isEmpty { EmptyCard(title: "Make room for a good meal", message: "Explore meal ideas and plan your day.", icon: "fork.knife") }
                ForEach(plan) { meal in NavigationLink(destination: MealPlanScreen()) { ValueRow(title: meal.name, value: "\(meal.calories) kcal") } }
                NavigationLink("Open meal planner", destination: MealPlanScreen())
                Text("Activity calories are shown separately. Your food target stays under your control.").font(.footnote).foregroundStyle(.secondary)
            }.padding(20)
        }.background(Color(.systemGroupedBackground)).navigationTitle(diary.profile.name.flatMap { $0.isEmpty ? nil : "Hi, \($0)" } ?? "Nourish")
        .sheet(isPresented: $adding) { AddFoodView() }
        .onReceive(timer) { clock = $0 }
    }
    private func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2.bold()) }
            .padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
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
                ValueRow(title: "Total eaten", value: "\(entries.reduce(0) { $0 + $1.calories }) kcal")
            }
            if entries.isEmpty { EmptyCard(title: "Your diary is ready", message: "Add a food or a meal for this day.", icon: "book") }
            ForEach(mealCategories, id: \.self) { category in
                Section(category) {
                    ForEach(entries.filter { ($0.category ?? "Snacks") == category }) { food in
                        NavigationLink(destination: FoodDetailScreen(food: food)) { ValueRow(title: food.name, value: "\(food.calories) kcal") }
                            .swipeActions { Button(role: .destructive) { diary.foods.removeAll { $0.id == food.id } } label: { Label("Delete", systemImage: "trash") } }
                    }
                }
            }
        }.navigationTitle("Food diary").toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add food") }
        .sheet(isPresented: $adding) { AddFoodView(initialDate: date) }
    }
}
struct AddFoodView: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    var initialDate = Date()
    var existing: Food? = nil
    @State private var name = ""
    @State private var calories = ""
    @State private var category = "Breakfast"
    @State private var date = Date()
    private var validCalories: Int? { guard let value = Int(calories), (1...10000).contains(value) else { return nil }; return value }
    var body: some View {
        NavigationView {
            Form {
                Section("Your serving") {
                    TextField("Food or meal name", text: $name)
                    TextField("Calories (kcal)", text: $calories).keyboardType(.numberPad)
                    Picker("Meal", selection: $category) { ForEach(mealCategories, id: \.self) { Text($0) } }
                    DatePicker("When", selection: $date, in: ...Date())
                }
                Section { Text("Enter calories for the portion you ate. Use its nutrition label or a trusted food reference.") }
            }.navigationTitle(existing == nil ? "Log food" : "Edit food").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = validCalories else { return }
                        var food = Food(name: name.trimmingCharacters(in: .whitespacesAndNewlines), calories: value, date: date, category: category)
                        if let existing, let index = diary.foods.firstIndex(where: { $0.id == existing.id }) { food.id = existing.id; diary.foods[index] = food }
                        else { diary.foods.append(food) }
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || validCalories == nil)
                }
            }
        }.navigationViewStyle(.stack).onAppear {
            name = existing?.name ?? ""; calories = existing.map { String($0.calories) } ?? ""
            category = existing?.category ?? "Breakfast"; date = existing?.date ?? initialDate
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
                ValueRow(title: "Meal", value: current.category ?? "Snacks")
                Text(current.date.formatted(date: .abbreviated, time: .shortened))
            }
            Button("Edit entry") { editing = true }
            Button("Delete entry", role: .destructive) { deleting = true }
        }.navigationTitle("Food details").sheet(isPresented: $editing) { AddFoodView(existing: current) }
        .alert("Delete this entry?", isPresented: $deleting) {
            Button("Delete", role: .destructive) { diary.foods.removeAll { $0.id == food.id }; dismiss() }
            Button("Cancel", role: .cancel) { }
        }
    }
}
