import SwiftUI

struct ProfileScreen: View {
    @State private var showingAccountSecurity = false
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var account: AccountStore
    var body: some View {
        Group {
            if account.isAuthenticated { signedInProfile }
            else { LoginScreen() }
        }
    }
    private var signedInProfile: some View {
        List {
            Section {
                NavigationLink(destination: PersonalDetailsScreen()) {
                    HStack(alignment: .center, spacing: 14) {
                        AccountAvatar(size: 54)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(account.session?.displayName ?? "Your account").font(.headline).fixedSize(horizontal: false, vertical: true)
                            Text(account.session?.email ?? "").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            Text("View personal details").font(.caption).foregroundStyle(NourishStyle.accent)
                        }
                    }.padding(.vertical, 8)
                }
                .accessibilityLabel("Personal details for \(account.session?.displayName ?? "your account")")
                .accessibilityHint("Opens your name, measurements and activity settings")
                Button {
                    showingAccountSecurity = true
                } label: {
                    Label("Account & security", systemImage: "lock.shield")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }.buttonStyle(.bordered)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), alignment: .leading)], spacing: 14) {
                    measurement("Height", diary.profile.height.map { "\($0.formatted()) cm" } ?? "Not set")
                    measurement("Weight", diary.profile.weight.map { "\($0.formatted()) kg" } ?? "Not set")
                    measurement("Daily target", diary.currentTargetCalories.map { "\(Int($0)) kcal" } ?? "Not set")
                }.padding(.vertical, 6)
            }
            Section("Personal settings") {
                NavigationLink(destination: CombinedMeasurementsScreen()) {
                    Label("Height & weight", systemImage: "ruler")
                }
                NavigationLink(destination: GoalsScreen()) { RouteRow(title: "Goals & calorie target", subtitle: diary.profile.goal.isEmpty ? "Set your daily target" : diary.profile.goal, icon: "target", showsChevron: false) }
                NavigationLink(destination: PreferencesScreen()) { RouteRow(title: "Food preferences", subtitle: diary.profile.preferences.isEmpty ? "Diet and ingredient preferences" : diary.profile.preferences, icon: "fork.knife", showsChevron: false) }
            }
            Section {
                NavigationLink(destination: ProgressScreen()) { Label("Progress", systemImage: "chart.bar") }
            }
            Section("App & data") {
                NavigationLink(destination: SettingsScreen()) { Label("Settings & help", systemImage: "gearshape") }
                NavigationLink(destination: BackupScreen()) { Label("Backup & recovery", systemImage: "externaldrive") }
            }
            Section { Text("Signed-in accounts share this iPhone's local journal.").font(.caption).foregroundStyle(.secondary) }
        }.listStyle(.insetGrouped).navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAccountSecurity) {
            NavigationView {
                AccountSecurityScreen()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingAccountSecurity = false }
                        }
                    }
            }.navigationViewStyle(.stack)
        }
        .onChange(of: account.isAuthenticated) { authenticated in
            if !authenticated { showingAccountSecurity = false }
        }
    }
    private func measurement(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true) }
    }
}
struct HealthScreen: View {
    @EnvironmentObject var health: HealthService
    @AppStorage("healthEnabled") private var enabled = false
    @State private var section = "Overview"
    var body: some View {
        VStack(spacing: 0) {
            Picker("Health section", selection: $section) { Text("Overview").tag("Overview"); Text("Browse data").tag("Browse data") }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 12)
            PageCanvas {
                if section == "Overview" {
                    Surface {
                        SectionHeading(title: "Apple Health connection", subtitle: "Choose what Nourish can read. Sharing measurements is always reviewed separately.")
                        Button("Choose Health access") { enabled = true; Task { await health.connect() } }.buttonStyle(PrimaryAction()).disabled(health.busy)
                        Button("Refresh available data") { Task { await health.refresh() } }.disabled(health.busy)
                        if health.busy { ProgressView("Refreshing…") }
                        DisclosureGroup("Connection details") { Text(health.status).font(.footnote).foregroundStyle(.secondary); Toggle("Refresh when opening Nourish", isOn: $enabled); Text("Turning refresh off does not revoke permissions. Manage those in Apple Health.").font(.caption).foregroundStyle(.secondary) }
                    }
                    Surface {
                        SectionHeading(title: "Body measurements")
                        NavigationLink(destination: HealthMetricScreen(metric: .height)) { RouteRow(title: "Height", subtitle: health.height.map { "\($0.formatted()) cm · latest reading" } ?? "Review or share a measurement", icon: "ruler") }.buttonStyle(.plain)
                        Divider()
                        NavigationLink(destination: HealthMetricScreen(metric: .weight)) { RouteRow(title: "Weight", subtitle: health.weight.map { "\($0.formatted()) kg · latest reading" } ?? "Review or share a measurement", icon: "scalemass") }.buttonStyle(.plain)
                    }
                    Surface {
                        SectionHeading(title: "Today's activity")
                        NavigationLink(destination: HealthMetricScreen(metric: .steps)) { RouteRow(title: "Steps", subtitle: health.steps.map { Int($0).formatted() } ?? "No current value", icon: "figure.walk") }.buttonStyle(.plain)
                        Divider()
                        NavigationLink(destination: HealthMetricScreen(metric: .activeEnergy)) { RouteRow(title: "Active energy", subtitle: health.activeEnergy.map { "\(Int($0)) kcal" } ?? "No current value", icon: "flame", color: NourishStyle.peach) }.buttonStyle(.plain)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        NavigationLink(destination: HealthRecordsScreen(kind: .workouts)) { QuickActionTile(title: "Workouts", subtitle: "Sessions and sources", icon: "figure.walk") }.buttonStyle(.plain)
                        NavigationLink(destination: HealthRecordsScreen(kind: .rings)) { QuickActionTile(title: "Activity rings", subtitle: "Daily summaries", icon: "circle.dashed") }.buttonStyle(.plain)
                    }
                    Button("Browse all 26 supported types") { section = "Browse data" }.buttonStyle(SecondaryAction())
                } else { HealthCataloguePanel() }
            }
        }.background(NourishStyle.canvas.ignoresSafeArea()).navigationTitle("Health").navigationBarTitleDisplayMode(.inline)
        .onAppear { health.expireOldResults() }
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
                BrandLockup().padding(.vertical, 8)
                ValueRow(title: "Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unavailable")
                ValueRow(title: "Minimum iOS", value: "15.0")
                DisclosureGroup("Help & how to use Nourish") { HelpContent().padding(.vertical, 8) }
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
            Section("Stored on your device") { Text("Your profile, dated calorie/macro targets and accepted estimate inputs, food diary, planned meals, water logs and weight history are saved locally with file protection. Preferences use the device's local settings storage. Device backups follow your iPhone settings.") }
            Section("Apple Health") { Text("Nourish requests read access for the 26 types listed in the Health browser, including activity summaries, workouts, body measurements, heart/respiratory readings, sleep, mindfulness and nutrition. Choose which types to allow. Browser records remain in memory and are not included in diary exports. Importing a measurement requires review. Sharing height or weight requests write permission for that type and saves only the reviewed measurement. This is separate from local profile saving; no steps, workouts, energy or rings are written. Local deletion does not delete Health records.") }
            Section("Google sign-in") { Text("Google receives the OAuth sign-in request and shares basic profile information and email with Nourish. When available, Nourish downloads your Google profile photo for your avatar; the photo URL is session data and is not part of diary backups. Google credentials are managed by its SDK and Keychain; they are not included in journal backups. The app does not send food or Apple Health records to Google. Local email/password accounts are also available and stay in this installation’s private Keychain. Your journal remains on this device; signing in does not provide cloud sync or separate journals for different accounts.") }
            Section("Network & accounts") { Text("Google sign-in connects to Google. Local registration and login work on this device without a server; email ownership is not verified and password recovery is unavailable. No advertising or analytics service is integrated. There is no automatic cloud synchronization. You can export a JSON backup to a location you choose in Files. Exported backups contain your personal information and are not encrypted by Nourish.") }
            Section("Backups & recovery") { NavigationLink("Open backup & restore", destination: BackupScreen()); Text("Before replacing or resetting a diary, Nourish preserves the old file on this device. Keep an exported copy before uninstalling the app.") }
            Section("Managing entries") { Text("Swipe left on diary, weight, water or planned meal entries to remove them. Food details also let you edit or delete a food entry. Health access can be revoked in Apple Health.") }
        }.navigationTitle("Privacy & storage")
    }
}
private struct HelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group { Text("How do I start?").font(.headline); Text("Set your target in Profile → Goals & calorie target. Add what you eat in Diary, including calories for your actual serving. Save your own meals in Meals for reuse.") }
            Group { Text("Does planning count as eating?").font(.headline); Text("No. Add meals to your planner, then mark them as eaten to move them into the diary. Future meals cannot be marked as eaten.") }
            Group { Text("Where do calories come from?").font(.headline); Text("Food diary calories are entered by you. Saved meals use the calories and ingredients you enter. No meals or measurements are preloaded. There is no barcode scanner, photo analysis or live nutrition database yet.") }
            Group { Text("Why is Health data unavailable?").font(.headline); Text("Check that Apple Health contains records and Nourish has read permission. Open Health → Overview and refresh. HealthKit and TrollStore installation need testing on your specific phone.") }
            Group { Text("How is my target calculated?").font(.headline); Text("Open Goals & calorie target to enter a manual target or review a maintenance estimate. Estimate inputs and method are shown before applying. Choosing a weight goal does not automatically add a deficit. Targets have effective dates; target history preserves prior records.") }
            Group { Text("How do I keep a backup?").font(.headline); Text("Open Profile → Backup & recovery. Export to Files. To restore, choose a backup, check its preview and confirm replacement. This version replaces rather than merges journals.") }
            Group { Text("About Nourish").font(.headline); Text("A personal food and activity journal for iPhone, with iOS 15 support and a TrollStore IPA build workflow.") }
        }.font(.subheadline).fixedSize(horizontal: false, vertical: true)
    }
}
