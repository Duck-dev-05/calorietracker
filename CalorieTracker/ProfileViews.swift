import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var account: AccountStore
    var body: some View {
        Group {
            if account.isAuthenticated { signedInProfile }
            else { LoginScreen() }
        }
    }
    private var signedInProfile: some View {
        PageCanvas {
            BrandLockup()
            PageIntro(eyebrow: "Your space", title: "Wellness, your way.", detail: "A plan that belongs to you.")
            Surface {
                HStack(spacing: 16) {
                    BrandMark(size: 64)
                    VStack(alignment: .leading, spacing: 6) { Text(diary.profile.name.flatMap { $0.isEmpty ? nil : $0 } ?? "Your profile").font(.system(.title2, design: .rounded).weight(.bold)); Pill(text: diary.profile.goal.isEmpty ? "Goal not set" : diary.profile.goal) }
                }
                Divider()
                HStack {
                    measurement("Height", diary.profile.height.map { String(format: "%.0f cm", $0) } ?? "Not set")
                    Spacer(); measurement("Weight", diary.profile.weight.map { String(format: "%.1f kg", $0) } ?? "Not set")
                    Spacer(); measurement("Target", diary.profile.target.map { "\(Int($0)) kcal" } ?? "Not set")
                }
            }
            Surface {
                NavigationLink(destination: AccountSecurityScreen()) {
                    RouteRow(title: "Account", subtitle: account.session?.email ?? "Sign in to unlock your journal", icon: "person.crop.circle.badge.checkmark")
                }.buttonStyle(.plain)
            }
            SectionHeading(title: "Make it personal")
            Surface {
                NavigationLink(destination: PersonalDetailsScreen()) { RouteRow(title: "Personal details", subtitle: "Your measurements, age and activity", icon: "person.crop.circle") }.buttonStyle(.plain)
                Divider()
                NavigationLink(destination: GoalsScreen()) { RouteRow(title: "Goals & daily target", subtitle: diary.profile.goal.isEmpty ? "Choose your direction" : diary.profile.goal, icon: "target") }.buttonStyle(.plain)
                Divider()
                NavigationLink(destination: PreferencesScreen()) { RouteRow(title: "Food preferences", subtitle: diary.profile.preferences.isEmpty ? "Choose your food style" : diary.profile.preferences, icon: "fork.knife") }.buttonStyle(.plain)
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
struct HealthScreen: View {
    @EnvironmentObject var health: HealthService
    @AppStorage("healthEnabled") private var enabled = false
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Optional connection", title: "Your activity, with context.", detail: "Open a metric to review its status, update time and available source information.")
            Surface {
                Text(health.status).font(.subheadline)
                Button("Connect / manage Health access") { enabled = true; Task { await health.connect() } }.buttonStyle(PrimaryAction()).disabled(health.busy)
                Button("Refresh available data") { Task { await health.refresh() } }.disabled(health.busy)
                if health.busy { ProgressView("Refreshing metrics independently…") }
                Toggle("Refresh when opening Nourish", isOn: $enabled)
                Text("Turning this off stops automatic reads. Revoke access in Apple Health → your profile → Apps → Nourish.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(HealthMetric.allCases) { metric in
                NavigationLink(destination: HealthMetricScreen(metric: metric)) {
                    Surface {
                        RouteRow(title: metric.title, subtitle: health.result(metric).status.rawValue, icon: metric.icon, color: metric.isDaily ? NourishStyle.accent : .pink)
                        if let value = health.value(metric) { Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) \(metric.unit)").font(.title2.bold()).foregroundStyle(.primary) }
                    }
                }.buttonStyle(.plain)
            }
            Text("An empty result may mean no records or restricted read access. No Health data is written by Nourish.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Apple Health").navigationBarTitleDisplayMode(.inline).onAppear { health.expireOldResults() }
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
            Section("Account") { NavigationLink("Login & registration", destination: AccountWelcomeScreen()); NavigationLink("Account & security", destination: AccountSecurityScreen()) }
            Section("Your information") {
                NavigationLink(destination: BackupScreen()) { Label("Backup & restore", systemImage: "externaldrive") }
                NavigationLink("Privacy & storage", destination: PrivacyScreen())
                Button("Review welcome setup") { replay = true }
            }
            Section("Application") {
                BrandLockup().padding(.vertical, 8)
                ValueRow(title: "Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unavailable")
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
            Section("Login & registration") { Text("The account screens are available, but no authentication service is configured in this build. Passwords stay only in the current form and are cleared when leaving it. No account is created and no reset email is sent. Signing in is required to unlock the diary.") }
            Section("Network & accounts") { Text("No account, advertising, analytics or server connection is used by the app. There is no automatic cloud synchronization. You can export a JSON backup to a location you choose in Files. Exported backups contain your personal information and are not encrypted by Nourish.") }
            Section("Backups & recovery") { NavigationLink("Open backup & restore", destination: BackupScreen()); Text("Before replacing or resetting a diary, Nourish preserves the old file on this device. Keep an exported copy before uninstalling the app.") }
            Section("Managing entries") { Text("Swipe left on diary, weight, water or planned meal entries to remove them. Food details also let you edit or delete a food entry. Health access can be revoked in Apple Health.") }
        }.navigationTitle("Privacy & storage")
    }
}
struct HelpScreen: View {
    var body: some View {
        List {
            Section("How do I start?") { Text("Set your target in You → Goals & daily target. Add what you eat in Diary, including calories for your actual serving. Save your own meals in Meals for reuse.") }
            Section("Does planning count as eating?") { Text("No. Add meals to your planner, then mark them as eaten to move them into the diary. Future meals cannot be marked as eaten.") }
            Section("Where do calories come from?") { Text("Food diary calories are entered by you. Saved meals use the calories and ingredients you enter. No meals or measurements are preloaded. There is no barcode scanner, photo analysis or live nutrition database yet.") }
            Section("Why is Health data unavailable?") { Text("Check that Apple Health contains records and Nourish has read permission. Open You → Apple Health and refresh. HealthKit and TrollStore installation need testing on your specific phone.") }
            Section("How is my target calculated?") { Text("It is currently set manually. Recording your measurements and goal does not automatically calculate it. The app does not prescribe a diet.") }
            Section("How do I keep a backup?") { Text("Open You → Settings → Backup & restore. Export to Files. To restore, choose a backup, check its preview and confirm replacement. This version replaces rather than merges journals.") }
            Section("About Nourish") { Text("A personal food and activity journal for iPhone, with iOS 15 support and a TrollStore IPA build workflow.") }
        }.navigationTitle("Help & about")
    }
}
