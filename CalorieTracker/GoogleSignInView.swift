import SwiftUI
import GoogleSignInSwift

struct GoogleAccountAction: View {
    @EnvironmentObject var account: AccountStore
    var compact = false
    @State private var error: String?
    @State private var signingIn = false
    var body: some View {
        Group {
            if compact { controls }
            else { Surface { SectionHeading(title: "Google"); controls } }
        }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            GoogleSignInButton {
                error = nil; signingIn = true
                Task {
                    defer { signingIn = false }
                    do { try await account.signInWithGoogle() }
                    catch is CancellationError { }
                    catch { self.error = error.localizedDescription }
                }
            }.frame(minHeight: 48).disabled(account.busy || !account.googleSignInAvailable)
            if signingIn { ProgressView("Signing in…") }
            if let message = account.configurationMessage { Label(message, systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary) }
            if let error { Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red) }
            if let message = account.restorationError { Text(message).font(.footnote).foregroundStyle(.secondary) }
            if !compact { DisclosureGroup("What Google shares") { Text("Google shares your name and email for sign-in. Your journal and Apple Health records are not sent to Google.").font(.caption).foregroundStyle(.secondary) }.font(.subheadline) }
        }
    }
}
