import SwiftUI

private struct DetailNote: View {
    let icon: String
    let text: String
    var body: some View {
        Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: icon) }
            .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct SelectionCard: View {
    let title: String
    let detail: String
    let icon: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                IconTile(icon: icon)
                VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline).foregroundStyle(.primary); Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(selected ? NourishStyle.accent : Color.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? NourishStyle.accent.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? NourishStyle.accent.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: 1))
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
    @State private var weightBeforeLogging = 0.0
    @State private var loaded = false
    @FocusState private var textFocused: Bool
    private let activities = ["Not specified", "Mostly seated", "Some daily movement", "Regular exercise", "Very active days"]
    private var ageValid: Bool { age.isEmpty || Int(age).map { (1...120).contains($0) } == true }
    private var valid: Bool { name.count <= 200 && ageValid && NumberDraftField.value(height, range: 80...250) != nil && NumberDraftField.value(weight, range: 20...400) != nil }
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Make it personal", title: "Start with you.", detail: "Give your journal a little context. You decide what to share.")
            Surface {
                HStack(spacing: 16) {
                    IconTile(icon: "person.crop.circle")
                    VStack(alignment: .leading, spacing: 4) { Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your personal profile" : name).font(.system(.title2, design: .rounded).weight(.bold)); Text("Only stored in your journal").font(.caption).foregroundStyle(.secondary) }
                }
                Divider()
                SectionHeading(title: "What should we call you?")
                TextField("Your name (optional)", text: $name).textContentType(.givenName).focused($textFocused).padding(14).background(NourishStyle.canvas, in: RoundedRectangle(cornerRadius: 14))
                if name.count > 200 { Text("Keep your name under 200 characters.").font(.caption).foregroundStyle(.red) }
                HStack { Text("Age (optional)"); Spacer(); TextField("Not set", text: $age).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 95).focused($textFocused) }
                if !ageValid { Text("Use a whole number from 1 to 120, or leave age blank.").font(.caption).foregroundStyle(.red) }
            }
            Surface {
                SectionHeading(title: "Your measurements", subtitle: "Metric units · cm and kg")
                NumberDraftField(title: "Height (cm)", text: $height, range: 80...250)
                Divider()
                NumberDraftField(title: "Current weight (kg)", text: $weight, range: 20...400)
                DetailNote(icon: "pencil", text: "Edit these at any time. Saving a profile measurement doesn't add a dated weight entry to Progress.")
                Button { weightBeforeLogging = diary.profile.weight; loggingWeight = true } label: { Label("Log a dated weight measurement", systemImage: "plus.circle") }.font(.subheadline.weight(.semibold))
            }
            Surface {
                SectionHeading(title: "What does your day look like?", subtitle: "Optional context for your profile")
                Picker("Usual activity", selection: $activity) { ForEach(activities, id: \.self) { Text($0) } }.pickerStyle(.menu)
                Text(activityDetail).font(.subheadline).foregroundStyle(.secondary)
                DetailNote(icon: "info.circle", text: "Age and activity are profile context only. They do not automatically change your calorie target.")
            }
            Surface {
                SectionHeading(title: "Bring in Apple Health measurements")
                Text("Use an available measurement as a draft, then review it before saving.").font(.subheadline).foregroundStyle(.secondary)
                if let h = health.height { Button("Use Health height · \(h, specifier: "%.1f") cm") { height = h.formatted(.number.grouping(.never)) } }
                if let w = health.weight { Button("Use Health weight · \(w, specifier: "%.1f") kg") { weight = w.formatted(.number.grouping(.never)) } }
                NavigationLink(destination: HealthScreen()) { RouteRow(title: "Apple Health connection", subtitle: "Connect or refresh available measurements", icon: "heart.fill", color: .pink) }.buttonStyle(.plain)
            }
            if let error = diary.storageError { DetailNote(icon: "exclamationmark.triangle", text: error) }
            Button("Save personal details", action: save).buttonStyle(PrimaryAction()).disabled(!valid).opacity(valid ? 1 : 0.5)
            DetailNote(icon: "lock.shield", text: "Your edits stay on this page until saved. Going back leaves the saved profile unchanged.")
        }.navigationTitle("Personal details").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $loggingWeight, onDismiss: {
            if diary.profile.weight != weightBeforeLogging { weight = diary.profile.weight.formatted(.number.grouping(.never)) }
        }) { WeightLogScreen().adaptiveEntrySheet() }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { if textFocused { Spacer(); Button("Done") { textFocused = false } } } }
        .onAppear { if !loaded { let p = diary.profile; name = p.name ?? ""; age = p.age.map(String.init) ?? ""; height = p.height.formatted(.number.grouping(.never)); weight = p.weight.formatted(.number.grouping(.never)); activity = activities.contains(p.activityLevel ?? "") ? p.activityLevel! : "Not specified"; loaded = true } }
    }
    private var activityDetail: String {
        switch activity {
        case "Mostly seated": return "Much of your day is spent sitting, with limited movement between tasks."
        case "Some daily movement": return "You spend part of the day walking, standing or doing everyday errands."
        case "Regular exercise": return "Your routine includes planned exercise alongside everyday movement."
        case "Very active days": return "Your usual routine includes substantial physical work or frequent exercise."
        default: return "You can leave this blank and continue using a manual daily target."
        }
    }
    private func save() {
        guard valid, let h = NumberDraftField.value(height, range: 80...250), let w = NumberDraftField.value(weight, range: 20...400) else { return }
        if diary.transaction({ $0.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines); $0.profile.age = Int(age); $0.profile.height = h; $0.profile.weight = w; $0.profile.activityLevel = activity == "Not specified" ? nil : activity }) { dismiss() }
    }
}
struct GoalsScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    @State private var goal = "Maintain"
    @State private var target = ""
    @State private var hasGoalWeight = false
    @State private var goalWeight = ""
    @State private var note = ""
    @State private var loaded = false
    private var calories: Double? { NumberDraftField.value(target, range: 500...10000) }
    private var valid: Bool { calories != nil && (!hasGoalWeight || NumberDraftField.value(goalWeight, range: 20...400) != nil) && note.count <= 500 }
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Your direction", title: "A goal that fits your life.", detail: "Choose a direction, set your daily target and give yourself something to work toward.")
            Surface {
                SectionHeading(title: "What would you like to focus on?")
                SelectionCard(title: "Maintain", detail: "Keep a consistent routine and stay aware of your intake.", icon: "equal.circle", selected: goal == "Maintain") { goal = "Maintain" }
                SelectionCard(title: "Lose weight", detail: "Record a weight-loss goal while choosing your own daily intake.", icon: "arrow.down.right.circle", selected: goal == "Lose weight") { goal = "Lose weight" }
                SelectionCard(title: "Gain weight", detail: "Record a weight-gain goal and track your consistency over time.", icon: "arrow.up.right.circle", selected: goal == "Gain weight") { goal = "Gain weight" }
            }
            Surface {
                HStack { SectionHeading(title: "Daily energy target"); Spacer(); Pill(text: "MANUAL") }
                NumberDraftField(title: "Calories per day", text: $target, range: 500...10000)
                if let calories {
                    Divider()
                    ValueRow(title: "Logged today", value: "\(diary.consumed) kcal")
                    ValueRow(title: "Remaining with this target", value: "\(max(0, Int(calories) - diary.consumed)) kcal")
                    if Int(calories) < diary.consumed { Text("Today's logged intake is \(diary.consumed - Int(calories)) kcal above this draft target.").font(.caption).foregroundStyle(.secondary) }
                }
                DetailNote(icon: "info.circle", text: "This is your chosen target, not an automatic recommendation. Selecting a goal does not calculate calories. Input limits are validation limits.")
            }
            Surface {
                SectionHeading(title: "A weight milestone", subtitle: "Optional · no deadline required")
                ValueRow(title: "Current profile weight", value: String(format: "%.1f kg", diary.profile.weight))
                Toggle("Keep a goal weight", isOn: $hasGoalWeight)
                if hasGoalWeight { NumberDraftField(title: "Goal weight (kg)", text: $goalWeight, range: 20...400); Text("Saved as a personal milestone. It doesn't calculate a calorie deficit, pace or completion date.").font(.footnote).foregroundStyle(.secondary) }
                NavigationLink(destination: ProgressScreen()) { Label("View your weight history", systemImage: "chart.line.uptrend.xyaxis") }.font(.subheadline)
            }
            Surface {
                SectionHeading(title: "What matters to you?", subtitle: "An optional reminder in your own words")
                TextEditor(text: $note).frame(minHeight: 90).padding(6).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
                    .accessibilityLabel("Personal goal note")
                Text("\(note.count)/500 characters").font(.caption).foregroundStyle(note.count > 500 ? Color.red : Color.secondary)
            }
            Surface {
                SectionHeading(title: "How your target is used")
                DetailNote(icon: "flame", text: "Active energy from Apple Health stays separate and is not added to your food target.")
                DetailNote(icon: "chart.bar", text: "Changing your target updates the dashboard and progress comparisons. Previous food entries are preserved; historical targets are not tracked yet.")
            }
            if let error = diary.storageError { DetailNote(icon: "exclamationmark.triangle", text: error) }
            Button("Save goals & target", action: save).buttonStyle(PrimaryAction()).disabled(!valid).opacity(valid ? 1 : 0.5)
        }.navigationTitle("Goals & daily target").navigationBarTitleDisplayMode(.inline)
        .onAppear { if !loaded { let p = diary.profile; goal = p.goal; target = p.target.formatted(.number.grouping(.never)); hasGoalWeight = p.goalWeight != nil; goalWeight = (p.goalWeight ?? p.weight).formatted(.number.grouping(.never)); note = p.goalNote ?? ""; loaded = true } }
    }
    private func save() {
        guard valid, let calories else { return }
        if diary.transaction({ $0.profile.goal = goal; $0.profile.target = calories; $0.profile.goalWeight = hasGoalWeight ? NumberDraftField.value(goalWeight, range: 20...400) : nil; $0.profile.goalNote = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines) }) { dismiss() }
    }
}
struct PreferencesScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    @State private var style = "Balanced"
    @State private var exclusions = ""
    @State private var loaded = false
    @FocusState private var focused: Bool
    private var terms: [String] { Meal.exclusionTerms(exclusions) }
    private var valid: Bool { terms.count <= 20 && terms.allSatisfy { $0.count <= 50 } }
    private var matches: [Meal] { Meal.ideas.filter { $0.matches(preference: style, excluding: terms) } }
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Your food, your way", title: "Make room for what you enjoy.", detail: "Shape your meal inspiration with a food style and a few personal preferences.")
            Surface {
                SectionHeading(title: "Choose your food style")
                SelectionCard(title: "Balanced", detail: "Explore all available ideas, including plant-based meals, chicken and fish.", icon: "fork.knife", selected: style == "Balanced") { style = "Balanced" }
                SelectionCard(title: "Vegetarian", detail: "Show meat-free ideas. Dairy is included; this is not a vegan filter.", icon: "leaf", selected: style == "Vegetarian") { style = "Vegetarian" }
            }
            Surface {
                SectionHeading(title: "Ingredients you'd rather skip", subtitle: "Optional · separate words with commas")
                TextField("For example: salmon, yogurt", text: $exclusions).focused($focused).textInputAutocapitalization(.never).disableAutocorrection(true).padding(14).background(NourishStyle.canvas, in: RoundedRectangle(cornerRadius: 14))
                Text("\(terms.count)/20 ingredient terms").font(.caption).foregroundStyle(valid ? Color.secondary : Color.red)
                if !valid { Text("Use up to 20 terms, with no more than 50 characters each.").font(.caption).foregroundStyle(.red) }
                DetailNote(icon: "line.3.horizontal.decrease.circle", text: "Matching words are hidden from meal names and ingredient descriptions. This is a simple text filter; spelling variations and unlisted ingredients can be missed.")
            }
            Surface {
                HStack { SectionHeading(title: "A preview for your plate"); Spacer(); Pill(text: "\(matches.count) ideas") }
                Text("This preview uses your unsaved choices. The Meals tab changes after you save.").font(.footnote).foregroundStyle(.secondary)
                if matches.isEmpty { EmptyCard(title: "No ideas match yet", message: "Try fewer exclusions or another food style.", icon: "magnifyingglass") }
                ForEach(matches) { meal in
                    HStack(spacing: 12) { IconTile(icon: meal.vegetarian ? "leaf" : "fork.knife"); VStack(alignment: .leading, spacing: 4) { Text(meal.name).font(.headline); Text(meal.detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("≈ \(meal.calories) kcal").font(.caption).foregroundStyle(.secondary) }
                    if meal.id != matches.last?.id { Divider() }
                }
            }
            Surface {
                SectionHeading(title: "Know what your filters do")
                DetailNote(icon: "checkmark.circle", text: "Your choices filter meal inspiration. They never remove foods you've logged or meals you've already planned.")
                DetailNote(icon: "exclamationmark.circle", text: "These preferences are not verified allergy or medical-diet checks. Review full ingredients and preparation before choosing food.")
            }
            if let error = diary.storageError { DetailNote(icon: "exclamationmark.triangle", text: error) }
            Button("Save food preferences", action: save).buttonStyle(PrimaryAction()).disabled(!valid).opacity(valid ? 1 : 0.5)
        }.navigationTitle("Food preferences").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { if focused { Spacer(); Button("Done") { focused = false } } } }
        .onAppear { if !loaded { style = diary.profile.preferences; exclusions = (diary.profile.excludedIngredients ?? []).joined(separator: ", "); loaded = true } }
    }
    private func save() {
        guard valid else { return }
        if diary.transaction({ $0.profile.preferences = style; $0.profile.excludedIngredients = terms.isEmpty ? nil : terms }) { dismiss() }
    }
}
