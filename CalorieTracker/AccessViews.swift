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
