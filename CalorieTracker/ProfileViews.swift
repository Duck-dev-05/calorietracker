import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var diary: Diary
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 52)).foregroundStyle(nourishGreen)
                    VStack(alignment: .leading, spacing: 6) { Text(diary.profile.name.flatMap { $0.isEmpty ? nil : $0 } ?? "Your profile").font(.title2.bold()); Text(diary.profile.goal).foregroundStyle(.secondary) }
                }.padding(.vertical, 8)
            }
            Section("Personal details") {
                TextField("Your name", text: Binding(get: { diary.profile.name ?? "" }, set: { diary.profile.name = $0 }))
                NumericRow(title: "Height (cm)", value: $diary.profile.height, range: 80...250)
                NumericRow(title: "Weight (kg)", value: $diary.profile.weight, range: 20...400)
            }
            Section("Your plan") {
                NavigationLink(destination: GoalsScreen()) { Label("Goals & daily target", systemImage: "target") }
                NavigationLink(destination: PreferencesScreen()) { Label("Food preferences", systemImage: "fork.knife") }
                NavigationLink(destination: HealthScreen()) { Label("Apple Health & activity", systemImage: "heart.fill") }
            }
            Section {
                NavigationLink(destination: SettingsScreen()) { Label("Settings", systemImage: "gearshape") }
                NavigationLink(destination: HelpScreen()) { Label("Help & about", systemImage: "questionmark.circle") }
            }
        }.navigationTitle("You")
    }
}
struct GoalsScreen: View {
    @EnvironmentObject var diary: Diary
    var body: some View {
        Form {
            Section("Your direction") {
                Picker("Goal", selection: $diary.profile.goal) { ForEach(["Maintain", "Lose weight", "Gain weight"], id: \.self) { Text($0) } }
            }
            Section("Daily calorie target") {
                NumericRow(title: "Target (kcal)", value: $diary.profile.target, range: 500...10000)
                Text("Choose your own daily target. The initial 2,000 kcal is a placeholder. Your height, weight and goal are recorded, but do not yet generate a personalized calorie recommendation.").font(.footnote)
            }
            Section("Activity") { Text("Steps and active calories from Apple Health are displayed separately. Exercise does not automatically increase your food target.") }
        }.navigationTitle("Goals & target")
    }
}
struct PreferencesScreen: View {
    @EnvironmentObject var diary: Diary
    var body: some View {
        Form {
            Section("Meal inspiration") {
                Picker("Food style", selection: $diary.profile.preferences) { Text("Balanced").tag("Balanced"); Text("Vegetarian").tag("Vegetarian") }.pickerStyle(.inline)
            }
            Section { Text("Vegetarian filtering includes dairy. Meal ideas are not checked for allergies, intolerances or medical diets. Read the ingredients before choosing a meal.") }
        }.navigationTitle("Food preferences")
    }
}
struct HealthScreen: View {
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var health: HealthService
    @AppStorage("healthEnabled") private var enabled = false
    var body: some View {
        Form {
            Section {
                Label("A fuller view of your day", systemImage: "heart.fill").font(.headline).foregroundStyle(nourishGreen)
                Text("Connect the activity and measurements available in Apple Health, including records from compatible iPhone and Apple Watch apps.")
            }
            Section("Connection") {
                Text(health.status).font(.subheadline)
                Button(health.busy ? "Refreshing…" : "Connect / refresh Health") { enabled = true; Task { await health.connect() } }.disabled(health.busy)
                Toggle("Refresh when opening Nourish", isOn: $enabled)
                Text("Turning off refresh stops automatic reads. To revoke access, use Apple Health → your profile → Apps → Nourish.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Today's activity") {
                ValueRow(title: "Steps", value: health.steps.map { Int($0).formatted() } ?? "Unavailable")
                ValueRow(title: "Active energy", value: health.activeEnergy.map { "\(Int($0)) kcal" } ?? "Unavailable")
            }
            Section("Available measurements") {
                if let height = health.height {
                    ValueRow(title: "Height", value: String(format: "%.1f cm", height))
                    Button("Use this height") { diary.profile.height = height }
                } else { ValueRow(title: "Height", value: "Unavailable") }
                if let weight = health.weight {
                    ValueRow(title: "Weight", value: String(format: "%.1f kg", weight))
                    Button("Use this weight") { diary.profile.weight = weight }
                } else { ValueRow(title: "Weight", value: "Unavailable") }
            }
            Section("About access") { Text("Permission is optional. Unavailable values can mean missing records or restricted read access. Nourish cannot tell which. Food logs and measurements you enter here are not written to Apple Health.") }
        }.navigationTitle("Apple Health")
    }
}
struct SettingsScreen: View {
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("onboardingComplete") private var complete = true
    @State private var replay = false
    var body: some View {
        Form {
            Section("Display") {
                Picker("Appearance", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }
                ValueRow(title: "Measurements", value: "cm · kg · mL")
            }
            Section("Your information") {
                NavigationLink("Privacy & storage", destination: PrivacyScreen())
                Button("Review welcome setup") { replay = true }
            }
            Section("Application") {
                ValueRow(title: "Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")
                ValueRow(title: "Minimum iOS", value: "15.0")
                NavigationLink("Help & about", destination: HelpScreen())
            }
        }.navigationTitle("Settings")
        .alert("Review setup again?", isPresented: $replay) {
            Button("Open setup") { complete = false }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Your diary and measurements will be kept.") }
    }
}
struct PrivacyScreen: View {
    var body: some View {
        List {
            Section("Stored on your device") { Text("Your profile, food diary, planned meals, water logs and weight history are saved locally with file protection. Preferences use the device's local settings storage. Device backups follow your iPhone settings.") }
            Section("Apple Health") { Text("Nourish requests read access to height, body mass, steps and active energy only when you choose to connect. Health results are displayed in memory. Measurements are saved to your profile only when you import them.") }
            Section("Network & accounts") { Text("No account, advertising, analytics or server connection is used by the app. There is no cloud synchronization or data export in this version.") }
            Section("Managing entries") { Text("Swipe left on diary, weight, water or planned meal entries to remove them. Food details also let you edit or delete a food entry. Health access can be revoked in Apple Health.") }
        }.navigationTitle("Privacy & storage")
    }
}
struct HelpScreen: View {
    var body: some View {
        List {
            Section("How do I start?") { Text("Set your target in You → Goals & daily target. Add what you eat in Diary, including calories for your actual serving. Explore Meals for inspiration.") }
            Section("Does planning count as eating?") { Text("No. Add meals to your planner, then mark them as eaten to move them into the diary. Future meals cannot be marked as eaten.") }
            Section("Where do calories come from?") { Text("Food diary calories are entered by you. The built-in meal ideas have illustrative calorie estimates. There is no barcode scanner, photo analysis or live nutrition database yet.") }
            Section("Why is Health data unavailable?") { Text("Check that Apple Health contains records and Nourish has read permission. Open You → Apple Health and refresh. HealthKit and TrollStore installation need testing on your specific phone.") }
            Section("How is my target calculated?") { Text("It is currently set manually. Recording your measurements and goal does not automatically calculate it. The app does not prescribe a diet.") }
            Section("About Nourish") { Text("A personal food and activity journal for iPhone, with iOS 15 support and a TrollStore IPA build workflow.") }
        }.navigationTitle("Help & about")
    }
}
