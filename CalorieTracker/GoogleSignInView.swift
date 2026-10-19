import SwiftUI
import GoogleSignInSwift

struct GoogleAccountAction: View {
    @EnvironmentObject var account: AccountStore
    @State private var error: String?
    var body: some View {
        Surface {
            SectionHeading(title: "Continue with Google", subtitle: "Use your Google account. No separate Nourish password needed.")
            GoogleSignInButton {
                error = nil
                Task {
                    do { try await account.signInWithGoogle() }
                    catch is CancellationError { }
                    catch { self.error = error.localizedDescription }
                }
            }.frame(minHeight: 48).disabled(account.busy || !account.googleSignInAvailable)
            if account.busy { ProgressView("Connecting to Google…") }
            if let message = account.configurationMessage { Label(message, systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary) }
            if let error { Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red) }
            if let message = account.restorationError { Text(message).font(.footnote).foregroundStyle(.secondary) }
            Text("Google shares your basic profile and email for sign-in. Nourish does not send your journal or Apple Health records to Google.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
