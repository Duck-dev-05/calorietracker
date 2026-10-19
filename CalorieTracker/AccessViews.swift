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
            BrandLockup().padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text("WELCOME TO NOURISH").font(.caption.weight(.semibold)).tracking(1.5); Spacer(); Image(systemName: "sun.max") }.foregroundStyle(NourishStyle.lime)
                Text("Your day.\nA healthier rhythm.").font(.system(.largeTitle, design: .rounded).weight(.bold)).tracking(-0.8).fixedSize(horizontal: false, vertical: true)
                Text("Make room for meals, movement and a healthier everyday.").font(.subheadline).lineSpacing(3).foregroundStyle(Color.white.opacity(0.8))
                HStack(spacing: 12) { Image(systemName: "fork.knife"); Image(systemName: "drop.fill"); Image(systemName: "figure.walk"); Spacer(); BrandMark(size: 64) }.font(.title2).foregroundStyle(NourishStyle.lime).padding(.vertical, 12)
                Label("A personal journal, made for you", systemImage: "lock.shield").font(.caption).foregroundStyle(Color.white.opacity(0.8))
            }.padding(26).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).background(NourishStyle.forest, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            SectionHeading(title: "Meet your daily rhythm", subtitle: "Simple tools for the things that add up.")
            Surface {
                RouteRow(title: "Food, thoughtfully logged", subtitle: "Keep meals, portions and nutrition in one place", icon: "fork.knife", showsChevron: false)
                Divider()
                RouteRow(title: "Progress, at your pace", subtitle: "Follow the measurements you choose to record", icon: "chart.line.uptrend.xyaxis", color: NourishStyle.peach, showsChevron: false)
                Divider()
                RouteRow(title: "Private by default", subtitle: "Your personal pages stay locked until you sign in", icon: "lock.shield", color: NourishStyle.blue, showsChevron: false)
            }
            VStack(spacing: 12) {
                NavigationLink("Sign in to your journal", destination: LoginScreen()).buttonStyle(PrimaryAction())
                NavigationLink("Create an account", destination: RegisterScreen()).buttonStyle(SecondaryAction())
                Text("Already have entries? They stay on this device.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }.navigationTitle("Nourish").navigationBarTitleDisplayMode(.inline)
    }
}
