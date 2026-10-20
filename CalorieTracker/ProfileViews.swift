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
            PageIntro(eyebrow: "Your space", title: "Your profile", detail: "Manage your details and daily goals.")
            Surface {
                HStack(spacing: 16) {
                    Text(account.session?.initials ?? "").font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(NourishStyle.accent).frame(width: 64, height: 64)
                        .background(NourishStyle.accent.opacity(0.12), in: Circle()).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(account.session?.displayName ?? "Your account").font(.system(.title2, design: .rounded).weight(.bold)).fixedSize(horizontal: false, vertical: true)
                        if let session = account.session {
                            Text(session.email).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Label("Signed in with \(session.providerName)", systemImage: "checkmark.circle.fill").font(.caption.weight(.medium)).foregroundStyle(NourishStyle.accent)
                        }
                    }
                }
                if let name = diary.profile.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty, name != account.session?.displayName {
                    ValueRow(title: "Journal name", value: name)
                }
                Pill(text: diary.profile.goal.isEmpty ? "Goal not set" : diary.profile.goal)
                Divider()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 18) {
                    measurement("Height", diary.profile.height.map { String(format: "%.0f cm", $0) } ?? "Not set")
                    measurement("Weight", diary.profile.weight.map { String(format: "%.1f kg", $0) } ?? "Not set")
                    measurement("Target", diary.profile.target.map { "\(Int($0)) kcal" } ?? "Not set")
                }
            }
            Surface {
                NavigationLink(destination: AccountSecurityScreen()) {
                    RouteRow(title: "Account", subtitle: account.session?.email ?? "Sign in to unlock your journal", icon: "person.crop.circle.badge.checkmark")
                }.buttonStyle(.plain)
            }
            SectionHeading(title: "Personal settings")
            NavigationLink(destination: PersonalDetailsScreen()) {
                Surface { RouteRow(title: "Personal details", subtitle: "Measurements, age and activity", icon: "person.crop.circle") }
            }.buttonStyle(.plain)
            NavigationLink(destination: GoalsScreen()) {
                Surface { RouteRow(title: "Goals & daily target", subtitle: diary.profile.goal.isEmpty ? "Choose your direction" : diary.profile.goal, icon: "target", color: NourishStyle.peach) }
            }.buttonStyle(.plain)
            NavigationLink(destination: PreferencesScreen()) {
                Surface { RouteRow(title: "Food preferences", subtitle: diary.profile.preferences.isEmpty ? "Choose your food style" : diary.profile.preferences, icon: "fork.knife", color: NourishStyle.blue) }
            }.buttonStyle(.plain)
            SectionHeading(title: "App & connections")
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
            PageIntro(eyebrow: "Apple Health & Fitness", title: "Your health, in one place.", detail: "Connect, choose the data you allow, then browse your available records.")
            Surface {
                Text(health.status).font(.subheadline)
                Button("Connect / manage Health access") { enabled = true; Task { await health.connect() } }.buttonStyle(PrimaryAction()).disabled(health.busy)
                Button("Refresh available data") { Task { await health.refresh() } }.disabled(health.busy)
                if health.busy { ProgressView("Refreshing metrics independently…") }
                Toggle("Refresh when opening Nourish", isOn: $enabled)
                Text("Turning this off stops automatic reads. Revoke access in Apple Health → your profile → Apps → Nourish.").font(.footnote).foregroundStyle(.secondary)
            }
            Surface {
                SectionHeading(title: "Body measurements", subtitle: "Import from Health or review a measurement to share.")
                NavigationLink(destination: HealthMetricScreen(metric: .height)) { RouteRow(title: "Height", subtitle: "Review Health value or share your measurement", icon: "ruler") }.buttonStyle(.plain)
                Divider()
                NavigationLink(destination: HealthMetricScreen(metric: .weight)) { RouteRow(title: "Weight", subtitle: "Review Health value or share your measurement", icon: "scalemass") }.buttonStyle(.plain)
                Text("Fitness uses Apple's Health data. Nourish shares body measurements only; it does not change activity rings or goals.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(HealthMetric.allCases.filter { $0.isDaily }) { metric in
                NavigationLink(destination: HealthMetricScreen(metric: metric)) {
                    Surface {
                        RouteRow(title: metric.title, subtitle: health.result(metric).status.rawValue, icon: metric.icon, color: metric.isDaily ? NourishStyle.accent : .pink)
                        if let value = health.value(metric) { Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) \(metric.unit)").font(.title2.bold()).foregroundStyle(.primary) }
                    }
                }.buttonStyle(.plain)
            }
            HealthCataloguePanel()
            Text("An empty result may mean no records or restricted read access. Height and weight are written only after you review sharing and allow the selected permission.").font(.footnote).foregroundStyle(.secondary)
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
            Section("Apple Health") { Text("Nourish requests read access for the 26 types listed in the Health browser, including activity summaries, workouts, body measurements, heart/respiratory readings, sleep, mindfulness and nutrition. Choose which types to allow. Browser records remain in memory and are not included in diary exports. Importing a measurement requires review. Sharing height or weight requests write permission for that type and saves only the reviewed measurement. This is separate from local profile saving; no steps, workouts, energy or rings are written. Local deletion does not delete Health records.") }
            Section("Google sign-in") { Text("Google receives the OAuth sign-in request and shares basic profile information and email with Nourish. Google credentials are managed by its SDK and Keychain; they are not included in journal backups. The app does not send food or Apple Health records to Google. Local email/password accounts are also available and stay in this installation’s private Keychain. Your journal remains on this device; signing in does not provide cloud sync or separate journals for different accounts.") }
            Section("Network & accounts") { Text("Google sign-in connects to Google. Local registration and login work on this device without a server; email ownership is not verified and password recovery is unavailable. No advertising or analytics service is integrated. There is no automatic cloud synchronization. You can export a JSON backup to a location you choose in Files. Exported backups contain your personal information and are not encrypted by Nourish.") }
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
