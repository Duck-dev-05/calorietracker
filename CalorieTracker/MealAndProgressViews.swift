import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboardingComplete") private var complete = false
    @EnvironmentObject var diary: Diary
    @State private var step = 0
    var body: some View {
        NavigationView {
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
                        Image(systemName: "leaf.fill").font(.system(size: 64, weight: .light)).foregroundStyle(NourishStyle.accent)
                    }.accessibilityHidden(true)
                    Text("Feel good.\nOne day at a time.").font(.system(.largeTitle, design: .rounded).weight(.bold)).multilineTextAlignment(.center)
                    Text("Know what you eat, explore meal ideas and keep your daily activity in view.").foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                    Spacer()
                } else if step == 1 {
                    Form {
                        Section("Make it yours") {
                            TextField("Your name (optional)", text: Binding(get: { diary.profile.name ?? "" }, set: { diary.profile.name = $0 }))
                            NumericRow(title: "Height (cm)", value: $diary.profile.height, range: 80...250)
                            NumericRow(title: "Weight (kg)", value: $diary.profile.weight, range: 20...400)
                            Picker("Goal", selection: $diary.profile.goal) { ForEach(["Maintain", "Lose weight", "Gain weight"], id: \.self) { Text($0) } }
                        }
                        Section("Daily target") {
                            NumericRow(title: "Calories (kcal)", value: $diary.profile.target, range: 500...10000)
                            Text("2,000 kcal is a starting placeholder. Choose your own target; measurements do not yet calculate it automatically.").font(.footnote)
                        }
                    }
                } else {
                    Form {
                        Section("Choose your food style") {
                            Picker("Preference", selection: $diary.profile.preferences) { Text("Balanced").tag("Balanced"); Text("Vegetarian").tag("Vegetarian") }
                        }
                        Section("Your data, your choice") {
                            Label("Your diary stays on this device", systemImage: "lock.shield")
                            Label("No account needed", systemImage: "person.crop.circle.badge.checkmark")
                            Text("You can connect Apple Health from your profile whenever you're ready.")
                        }
                    }
                }
                HStack {
                    if step > 0 { Button("Back") { step -= 1 }.padding() }
                    Button(step == 2 ? "Start my day" : "Continue") { if step == 2 { complete = true } else { step += 1 } }
                        .buttonStyle(PrimaryAction())
                }.padding()
            }.background(NourishStyle.canvas.ignoresSafeArea()).navigationTitle(step == 0 ? "Nourish" : "Your setup").navigationBarTitleDisplayMode(.inline)
        }.navigationViewStyle(.stack)
    }
}
struct MealsView: View {
    @EnvironmentObject var diary: Diary
    @State private var search = ""
    @State private var onlyFits = false
    private var meals: [Meal] {
        Meal.ideas.filter { (diary.profile.preferences != "Vegetarian" || $0.vegetarian) && (!onlyFits || $0.calories <= diary.remaining) && (search.isEmpty || ($0.name + $0.detail).localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Eat well", title: "Find your next favorite.", detail: "Simple ideas to bring a little variety to your plate.")
            NavigationLink(destination: MealPlanScreen()) {
                Surface { RouteRow(title: "Your meal planner", subtitle: "Make a little space for the week ahead", icon: "calendar") }
            }.buttonStyle(.plain)
            Surface { Toggle("Fits my remaining calories", isOn: $onlyFits).font(.subheadline); Text("\(max(0, diary.remaining)) kcal remaining today · \(diary.profile.preferences)").font(.caption).foregroundStyle(.secondary) }
            SectionHeading(title: "Made for your day", subtitle: "Illustrative servings · approximate calories")
            ForEach(meals) { meal in
                NavigationLink(destination: MealDetailScreen(meal: meal)) {
                    Surface {
                        MealArtwork(meal: meal)
                        HStack(alignment: .top) { Text(meal.name).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(.primary); Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(NourishStyle.accent).accessibilityHidden(true) }
                        Text(meal.detail).font(.subheadline).foregroundStyle(.secondary)
                        HStack { Pill(text: "≈ \(meal.calories) kcal"); if meal.vegetarian { Pill(text: "Vegetarian") } }
                    }
                }.buttonStyle(.plain)
            }
            if meals.isEmpty { Surface { EmptyCard(title: "Let's try another idea", message: "Change your search or switch off the calorie filter.", icon: "magnifyingglass") } }
            Text("Check ingredients for your dietary needs. Portions and preparation affect calories.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Meals").navigationBarTitleDisplayMode(.inline).searchable(text: $search, prompt: "Search meals or ingredients")
    }
}

struct MealDetailScreen: View {
    @EnvironmentObject var diary: Diary
    let meal: Meal
    @State private var servings = 1
    @State private var category = "Lunch"
    @State private var date = Date()
    @State private var feedback: String?
    var body: some View {
        Form {
            Section {
                MealArtwork(meal: meal).listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                Text(meal.name).font(.system(.title2, design: .rounded).weight(.bold))
                Text(meal.detail)
                ValueRow(title: "Estimated energy", value: "\(meal.calories * servings) kcal")
                Text("These are meal ideas, not measured recipes. Portions and preparation affect calories.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Your portion") {
                Stepper("\(servings) serving(s)", value: $servings, in: 1...10)
                Picker("Meal", selection: $category) { ForEach(mealCategories, id: \.self) { Text($0) } }
                Button("Log as eaten now") { diary.foods.append(Food(name: "\(meal.name) (\(servings) serving(s))", calories: meal.calories * servings, category: category)); feedback = "Added to today's diary." }
            }
            Section("Plan ahead") {
                DatePicker("Planned day", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                Button("Add to meal plan") { diary.planned.append(PlannedMeal(date: date, name: "\(meal.name) (\(servings) serving(s))", calories: meal.calories * servings, category: category)); feedback = "Added to your meal plan." }
            }
        }.navigationTitle("Meal details").navigationBarTitleDisplayMode(.inline)
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
            if meals.isEmpty { EmptyCard(title: "A day to plan", message: "Open a meal from Meal inspiration to add it to this day.", icon: "calendar") }
            ForEach(meals) { meal in
                VStack(alignment: .leading, spacing: 8) {
                    Text(meal.name).font(.headline)
                    Text("\(meal.category) · \(meal.calories) kcal").foregroundStyle(.secondary)
                    if !Calendar.current.startOfDay(for: date).isAfterToday {
                        Button("Mark as eaten") {
                            let loggedDate = Calendar.current.isDateInToday(date) ? Date() : Calendar.current.startOfDay(for: date)
                            diary.foods.append(Food(name: meal.name, calories: meal.calories, date: loggedDate, category: meal.category))
                            diary.planned.removeAll { $0.id == meal.id }
                        }.buttonStyle(.bordered)
                    }
                }.swipeActions { Button(role: .destructive) { diary.planned.removeAll { $0.id == meal.id } } label: { Label("Remove", systemImage: "trash") } }
            }
            Section { Text("Planned meals only count toward your diary after you mark them as eaten.").font(.footnote) }
        }.navigationTitle("Meal planner")
    }
}
private extension Date { var isAfterToday: Bool { self > Calendar.current.startOfDay(for: Date()) } }
struct WaterScreen: View {
    @EnvironmentObject var diary: Diary
    private var entries: [WaterEntry] { diary.water.filter { Calendar.current.isDateInToday($0.date) }.sorted { $0.date > $1.date } }
    var body: some View {
        List {
            Section {
                HStack { IconTile(icon: "drop.fill", color: NourishStyle.blue); Spacer(); Pill(text: "TODAY", color: NourishStyle.blue) }
                Text("\(entries.reduce(0) { $0 + $1.milliliters }) mL").font(.system(size: 44, weight: .semibold, design: .rounded)).foregroundStyle(NourishStyle.accent)
                Text("Water logged today").foregroundStyle(.secondary)
                HStack { ForEach([150, 250, 500], id: \.self) { amount in Button("+\(amount) mL") { diary.water.append(WaterEntry(milliliters: amount)) }.buttonStyle(.bordered) } }
            }
            Section("Today's drinks") {
                if entries.isEmpty { Text("No water logged yet.").foregroundStyle(.secondary) }
                ForEach(entries) { entry in HStack { Text(entry.date, style: .time); Spacer(); Text("\(entry.milliliters) mL") }.swipeActions { Button("Delete", role: .destructive) { diary.water.removeAll { $0.id == entry.id } } } }
            }
        }.navigationTitle("Water")
    }
}
struct ProgressScreen: View {
    @EnvironmentObject var diary: Diary
    @State private var logging = false
    private var days: [Date] { (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) } }
    private func total(_ date: Date) -> Int { diary.foods.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.calories } }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ONE DAY AT A TIME").font(.caption2.bold()).tracking(2).foregroundStyle(NourishStyle.accent)
                    Text("Look how far you've come.").font(.system(.title2, design: .rounded).weight(.bold))
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(days.filter { total($0) > 0 }.count)").font(.system(size: 44, weight: .semibold, design: .rounded))
                        Text("of 7 days with food logged").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 12)
            }
            Section("Last 7 days · calories logged") {
                ForEach(days, id: \.self) { date in
                    VStack(alignment: .leading, spacing: 6) {
                        ValueRow(title: date.formatted(.dateTime.weekday(.abbreviated).day()), value: "\(total(date)) kcal")
                        ProgressView(value: min(Double(total(date)) / max(1, diary.profile.target), 1)).tint(nourishGreen)
                    }.padding(.vertical, 4)
                }
                Text("Bars compare logged food to your current target. An empty day means no entries, not zero food eaten.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Weight history") {
                Button("Log weight") { logging = true }
                if diary.weights.isEmpty { EmptyCard(title: "See your journey", message: "Log a measurement to begin your weight history.", icon: "chart.line.uptrend.xyaxis") }
                ForEach(diary.weights.sorted { $0.date > $1.date }) { entry in
                    ValueRow(title: entry.date.formatted(date: .abbreviated, time: .omitted), value: String(format: "%.1f kg", entry.kilograms))
                        .swipeActions { Button("Delete", role: .destructive) { diary.weights.removeAll { $0.id == entry.id } } }
                }
            }
        }.navigationTitle("Your progress").sheet(isPresented: $logging) { WeightLogScreen() }
    }
}
struct WeightLogScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    @State private var weight = 70.0
    @State private var date = Date()
    var body: some View {
        NavigationView {
            Form { NumericRow(title: "Weight (kg)", value: $weight, range: 20...400); DatePicker("Measured", selection: $date, in: ...Date()); Text("Logging updates your profile only when this is your latest measurement.").font(.footnote) }
                .navigationTitle("Log weight").toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { if date >= (diary.weights.map(\.date).max() ?? .distantPast) { diary.profile.weight = weight }; diary.weights.append(WeightEntry(date: date, kilograms: weight)); dismiss() } }
                }
        }.navigationViewStyle(.stack).onAppear { weight = diary.profile.weight }
    }
}
