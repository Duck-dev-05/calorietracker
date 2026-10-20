import SwiftUI
import GoogleSignInSwift

struct GoogleAccountAction: View {
    @EnvironmentObject var account: AccountStore
    @State private var error: String?
    var body: some View {
        Surface {
            SectionHeading(title: "Google")
            GoogleSignInButton {
                error = nil
                Task {
                    do { try await account.signInWithGoogle() }
                    catch is CancellationError { }
                    catch { self.error = error.localizedDescription }
                }
            }.frame(minHeight: 48).disabled(account.busy || !account.googleSignInAvailable)
            if account.busy { ProgressView("Signing in…") }
            if let message = account.configurationMessage { Label(message, systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary) }
            if let error { Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red) }
            if let message = account.restorationError { Text(message).font(.footnote).foregroundStyle(.secondary) }
            DisclosureGroup("What Google shares") { Text("Google shares your name and email for sign-in. Your journal and Apple Health records are not sent to Google.").font(.caption).foregroundStyle(.secondary) }.font(.subheadline)
        }
    }
}
