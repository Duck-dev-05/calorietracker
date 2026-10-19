import SwiftUI

struct AccessPermissionsScreen: View {
    @EnvironmentObject var account: AccountStore
    @EnvironmentObject var diary: Diary
    var body: some View {
        Form {
            Section("Current access") {
                ValueRow(title: "Role", value: account.role.title)
                ValueRow(title: "Identity", value: account.session?.email ?? "This device's local journal")
                if let expiry = account.session?.expiresAt { Text("Session expires: \(expiry.formatted())").font(.footnote) }
                Text("Local use does not require an account. Account roles must be supplied by a connected identity service; they cannot be selected here.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Permissions for this journal") {
                ForEach(AppPermission.allCases) { permission in
                    HStack { Text(permission.title); Spacer(); Image(systemName: diary.can(permission) ? "checkmark.circle.fill" : "lock.fill").foregroundStyle(diary.can(permission) ? Color.green : Color.secondary).accessibilityLabel(diary.can(permission) ? "Allowed" : "Not allowed") }
                }
            }
            Section("Role rules") {
                Text("Local owner: manage the local journal on this device. Member: manage an account-owned journal. Viewer: read an account-owned journal only. Admin: the same personal journal permissions as Member; no access to other people's journals.")
                Text("Unknown or expired account roles are denied. Roles are not imported from backups. Sharing, role assignment and guest-journal adoption require a future account service.")
            }.font(.footnote)
            if account.session != nil { Button("End local account session") { account.endLocalSession() }; Text("This clears the session in Nourish. It does not revoke a server session or delete journal data.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Access & permissions").navigationBarTitleDisplayMode(.inline)
    }
}
struct JournalAccessDeniedScreen: View {
    @EnvironmentObject var account: AccountStore
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Journal access", title: "This journal is restricted.", detail: "Your current session cannot access this journal. Its data has been kept on this device.")
            Surface {
                NavigationLink("Review access & permissions", destination: AccessPermissionsScreen())
                NavigationLink("Login & registration", destination: AccountWelcomeScreen())
                Text("Guest-journal adoption and account switching are not connected in this build. An account role does not grant access to someone else's journal.").font(.footnote).foregroundStyle(.secondary)
                if account.session != nil { Button("Return to local access") { account.endLocalSession() } }
            }
        }.navigationTitle("Access required")
    }
}
