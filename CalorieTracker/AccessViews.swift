import SwiftUI

struct AccountSecurityScreen: View {
    @EnvironmentObject var account: AccountStore
    var body: some View {
        Form {
            Section("Session") {
                ValueRow(title: "Status", value: account.isAuthenticated ? "Signed in" : "Signed out")
                if let session = account.session, account.isAuthenticated {
                    ValueRow(title: "Name", value: session.displayName)
                    ValueRow(title: "Email", value: session.email)
                    ValueRow(title: "Sign-in provider", value: session.providerName)
                }
                if let expiry = account.session?.expiresAt { Text("Session expires: \(expiry.formatted())").font(.footnote) }
            }
            Section {
                Text("Sign-in is required for your journal, profile, Health connection and backup tools. Signing out or an expired session locks the app without deleting your diary.")
                Text("Google manages sign-in and stores its credentials in the device Keychain. Signing out clears Google credentials for this app, not your browser or other Google apps. It does not revoke previously granted Google access.")
                if let message = account.configurationMessage { Text(message) }
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
            BrandLockup()
            Surface {
                Text("Food and activity,\nmade simple.").font(.system(.title, design: .default).weight(.bold)).fixedSize(horizontal: false, vertical: true)
                Text("Keep a food diary, save meals and review your Apple Health data.").font(.subheadline).foregroundStyle(.secondary)
                NavigationLink("Log in", destination: LoginScreen()).buttonStyle(PrimaryAction())
                NavigationLink("Create an account", destination: RegisterScreen()).buttonStyle(SecondaryAction())
            }
            SectionHeading(title: "What you can do")
            Surface {
                RouteRow(title: "Log food", subtitle: "Start with a name and calories", icon: "plus", showsChevron: false)
                Divider()
                RouteRow(title: "Save meals", subtitle: "Reuse servings you eat regularly", icon: "fork.knife", showsChevron: false)
                Divider()
                RouteRow(title: "Review Health data", subtitle: "Choose what to connect and share", icon: "heart", showsChevron: false)
            }
            Text("Sign in when you're ready. Existing diary entries stay on this iPhone.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Nourish").navigationBarTitleDisplayMode(.inline)
    }
}
