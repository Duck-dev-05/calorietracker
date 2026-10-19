import SwiftUI

struct AccountSecurityScreen: View {
    @EnvironmentObject var account: AccountStore
    var body: some View {
        Form {
            Section("Session") {
                ValueRow(title: "Status", value: account.isAuthenticated ? "Signed in" : "Signed out")
                ValueRow(title: "Account", value: account.session?.email ?? "Not signed in")
                if let expiry = account.session?.expiresAt { Text("Session expires: \(expiry.formatted())").font(.footnote) }
            }
            Section {
                Text("Sign-in is required for your journal, profile, Health connection and backup tools. Signing out or an expired session locks the app without deleting your diary.")
                Text("Account authentication is not connected in this build. A valid session must come from the account service; there is no guest bypass.")
            }.font(.footnote)
            if account.isAuthenticated { Button("Sign out", role: .destructive) { account.endLocalSession() } }
        }.navigationTitle("Account & security").navigationBarTitleDisplayMode(.inline)
    }
}


/// Public navigation stays available; protected views are created only after sign-in.
struct SignInRequired<Content: View>: View {
    @EnvironmentObject var account: AccountStore
    @ViewBuilder let content: () -> Content
    var body: some View {
        if account.isAuthenticated { content() }
        else { LoginScreen() }
    }
}
struct VisitorHomeScreen: View {
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Welcome to Nourish", title: "A little more balance.", detail: "Your space for meals, movement and everyday progress.")
            Surface {
                IconTile(icon: "leaf.fill")
                SectionHeading(title: "Make each day your own", subtitle: "Keep a food diary, save your meals and follow your progress in one place.")
                Text("Sign in whenever you're ready to open your personal journal. Your existing entries stay private while you're signed out.").font(.subheadline).foregroundStyle(.secondary)
                NavigationLink(destination: LoginScreen()) { Text("Sign in").frame(maxWidth: .infinity).padding(.vertical, 12) }.buttonStyle(.borderedProminent)
                NavigationLink("Create an account", destination: RegisterScreen())
            }
            Surface {
                RouteRow(title: "Your meals", subtitle: "Record food and portions you actually eat", icon: "fork.knife")
                Divider()
                RouteRow(title: "Your progress", subtitle: "Keep your measurements and journal together", icon: "chart.line.uptrend.xyaxis")
                Divider()
                RouteRow(title: "Your privacy", subtitle: "Personal pages open after sign-in", icon: "lock.shield")
            }
        }.navigationTitle("Nourish").navigationBarTitleDisplayMode(.inline)
    }
}
