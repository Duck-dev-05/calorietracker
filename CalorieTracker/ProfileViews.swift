import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var diary: Diary
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Your space", title: "Wellness, your way.", detail: "A plan that belongs to you.")
            Surface {
                HStack(spacing: 16) {
                    ZStack { Circle().fill(NourishStyle.accent.opacity(0.12)).frame(width: 64, height: 64); Image(systemName: "person.fill").font(.title).foregroundStyle(NourishStyle.accent) }
                    VStack(alignment: .leading, spacing: 6) { Text(diary.profile.name.flatMap { $0.isEmpty ? nil : $0 } ?? "Your profile").font(.system(.title2, design: .rounded).weight(.bold)); Pill(text: diary.profile.goal) }
                }
                Divider()
                HStack {
                    measurement("Height", String(format: "%.0f cm", diary.profile.height))
                    Spacer(); measurement("Weight", String(format: "%.1f kg", diary.profile.weight))
                    Spacer(); measurement("Target", "\(Int(diary.profile.target)) kcal")
                }
            }
            SectionHeading(title: "Make it personal")
            Surface {
                NavigationLink(destination: PersonalDetailsScreen()) { RouteRow(title: "Personal details", subtitle: "Your name and measurements", icon: "person.crop.circle") }.buttonStyle(.plain)
                Divider()
                NavigationLink(destination: GoalsScreen()) { RouteRow(title: "Goals & daily target", subtitle: diary.profile.goal, icon: "target") }.buttonStyle(.plain)
                Divider()
                NavigationLink(destination: PreferencesScreen()) { RouteRow(title: "Food preferences", subtitle: diary.profile.preferences, icon: "fork.knife") }.buttonStyle(.plain)
            }
            SectionHeading(title: "Connected to your day")
            Surface {
                NavigationLink(destination: HealthScreen()) { RouteRow(title: "Apple Health", subtitle: "Activity, height and weight", icon: "heart.fill", color: .pink) }.buttonStyle(.plain)
                Divider()
                NavigationLink(destination: SettingsScreen()) { RouteRow(title: "Settings", subtitle: "Appearance and app preferences", icon: "slider.horizontal.3") }.buttonStyle(.plain)
                Divider()
                NavigationLink(destination: HelpScreen()) { RouteRow(title: "A little guidance", subtitle: "Help and about Nourish", icon: "questionmark.circle") }.buttonStyle(.plain)
            }
            Label("Your journal stays on your device", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }.navigationTitle("You").navigationBarTitleDisplayMode(.inline)
    }
    private func measurement(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.system(.subheadline, design: .rounded).weight(.semibold)).fixedSize(horizontal: false, vertical: true) }
    }
}
struct PersonalDetailsScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var loaded = false
    private var valid: Bool { name.count <= 200 && NumberDraftField.value(height, range: 80...250) != nil && NumberDraftField.value(weight, range: 20...400) != nil }
    var body: some View {
        Form {
            Section("About you") { TextField("Your name", text: $name) }
            Section("Measurements") {
                NumberDraftField(title: "Height (cm)", text: $height, range: 80...250)
                NumberDraftField(title: "Weight (kg)", text: $weight, range: 20...400)
            }
            Section { Text("Changes are applied only when you save. Apple Health imports are available on the connection page.").font(.footnote) }
            if let error = diary.storageError { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Personal details").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") {
            guard let height = NumberDraftField.value(height, range: 80...250), let weight = NumberDraftField.value(weight, range: 20...400) else { return }
            if diary.transaction({ $0.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines); $0.profile.height = height; $0.profile.weight = weight }) { dismiss() }
        }.disabled(!valid) } }
        .onAppear { if !loaded { name = diary.profile.name ?? ""; height = diary.profile.height.formatted(.number.grouping(.never)); weight = diary.profile.weight.formatted(.number.grouping(.never)); loaded = true } }
    }
}
struct GoalsScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    @State private var goal = "Maintain"
    @State private var target = ""
    @State private var loaded = false
    var body: some View {
        Form {
            Section("Your direction") { Picker("Goal", selection: $goal) { ForEach(["Maintain", "Lose weight", "Gain weight"], id: \.self) { Text($0) } } }
            Section("Daily calorie target") {
                NumberDraftField(title: "Target (kcal)", text: $target, range: 500...10000)
                Text("Set your own target. Input limits are not recommendations. Height and weight do not yet calculate a personalized target.").font(.footnote)
            }
            Section("Activity") { Text("Activity calories are displayed separately and do not automatically increase your food target.") }
            if let error = diary.storageError { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Goals & target").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") {
            guard let target = NumberDraftField.value(target, range: 500...10000) else { return }
            if diary.transaction({ $0.profile.goal = goal; $0.profile.target = target }) { dismiss() }
        }.disabled(NumberDraftField.value(target, range: 500...10000) == nil) } }
        .onAppear { if !loaded { goal = diary.profile.goal; target = diary.profile.target.formatted(.number.grouping(.never)); loaded = true } }
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
                HStack { IconTile(icon: "heart.fill", color: .pink); Spacer(); Pill(text: "OPTIONAL") }
                Text("A fuller view of your day.").font(.system(.title2, design: .rounded).weight(.bold))
                Text("Connect the activity and measurements available in Apple Health, including records from compatible iPhone and Apple Watch apps.")
            }
            Section("Connection") {
                Text(health.status).font(.subheadline)
                Button { enabled = true; Task { await health.connect() } } label: {
                    HStack { if health.busy { ProgressView() }; Label(health.busy ? "Refreshing…" : "Connect / refresh Health", systemImage: "arrow.triangle.2.circlepath") }.frame(maxWidth: .infinity).padding(.vertical, 8)
                }.disabled(health.busy)
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
                ValueRow(title: "Interface", value: InterfaceGeneration.name)
                Text(InterfaceGeneration.explanation).font(.footnote).foregroundStyle(.secondary)
            }
            Section("Your information") {
                NavigationLink(destination: BackupScreen()) { Label("Backup & restore", systemImage: "externaldrive") }
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
            Section("Network & accounts") { Text("No account, advertising, analytics or server connection is used by the app. There is no automatic cloud synchronization. You can export a JSON backup to a location you choose in Files. Exported backups contain your personal information and are not encrypted by Nourish.") }
            Section("Backups & recovery") { NavigationLink("Open backup & restore", destination: BackupScreen()); Text("Before replacing or resetting a diary, Nourish preserves the old file on this device. Keep an exported copy before uninstalling the app.") }
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
            Section("How do I keep a backup?") { Text("Open You → Settings → Backup & restore. Export to Files. To restore, choose a backup, check its preview and confirm replacement. This version replaces rather than merges journals.") }
            Section("About Nourish") { Text("A personal food and activity journal for iPhone, with iOS 15 support and a TrollStore IPA build workflow.") }
        }.navigationTitle("Help & about")
    }
}
