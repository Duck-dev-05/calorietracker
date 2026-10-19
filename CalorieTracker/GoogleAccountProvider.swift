import Foundation
import UIKit
import GoogleSignIn

/// SDK owns OAuth, token refresh and Keychain persistence. Diary backups never contain credentials.
@MainActor final class GoogleAccountProvider: AccountProvider {
    private let settings: GoogleOAuthSettings
    init(settings: GoogleOAuthSettings = .load()) { self.settings = settings }
    var configured: Bool { settings.issue == nil }
    var googleSignInAvailable: Bool { configured }
    let supportsPassword = false
    var configurationMessage: String? { settings.issue }

    private func configure() throws {
        if let issue = settings.issue { throw DiaryFailure.invalid(issue) }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: settings.clientID)
    }
    func signInWithGoogle() async throws -> AccountSession {
        try configure()
        guard let presenter = Self.presenter() else { throw DiaryFailure.invalid("Open the login page in the active app window and try again.") }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            return try session(for: result.user)
        } catch { throw mapped(error) }
    }
    func restoreSession() async throws -> AccountSession? {
        try configure()
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return nil }
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            return try session(for: user)
        } catch { throw mapped(error) }
    }
    func refreshSession() async throws -> AccountSession? {
        try configure()
        guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
        do {
            let refreshed = try await user.refreshTokensIfNeeded()
            return try session(for: refreshed)
        } catch { throw mapped(error) }
    }
    private func session(for user: GIDGoogleUser) throws -> AccountSession {
        guard user.configuration.clientID == settings.clientID,
              let id = user.userID, !id.isEmpty, let profile = user.profile,
              let expiry = user.accessToken.expirationDate else {
            throw DiaryFailure.invalid("Google did not return a complete account session. Please sign in again.")
        }
        let result = AccountSession(id: "google:" + id, email: profile.email, name: profile.name, expiresAt: expiry)
        guard AccessPolicy.isAuthenticated(result) else { throw DiaryFailure.invalid("Google returned an invalid or expired session.") }
        return result
    }
    func signOut() { GIDSignIn.sharedInstance.signOut() }
    func signIn(email: String, password: String) async throws -> AccountSession { throw passwordUnavailable() }
    func register(name: String, email: String, password: String) async throws -> AccountSession { throw passwordUnavailable() }
    func resetPassword(email: String) async throws { throw passwordUnavailable() }
    private func passwordUnavailable() -> DiaryFailure { .invalid("Use Sign in with Google. Nourish does not collect your Google password or create a separate email/password account.") }
    private func mapped(_ error: Error) -> Error {
        let value = error as NSError
        if value.domain == kGIDSignInErrorDomain {
            if value.code == -5 { return CancellationError() }
            if value.code == -2 { return DiaryFailure.invalid("Google sign-in could not access this installation's Keychain. Check signing/Keychain support on your iPhone; no session was opened.") }
        }
        // Do not expose provider error payloads, redirect URLs or tokens in UI/logs.
        return DiaryFailure.invalid("Google sign-in did not finish. Check your connection and OAuth app configuration, then try again.")
    }
    private static func presenter() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        guard let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        func top(_ controller: UIViewController) -> UIViewController {
            if let shown = controller.presentedViewController, !shown.isBeingDismissed { return top(shown) }
            if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController { return top(visible) }
            if let tabs = controller as? UITabBarController, let selected = tabs.selectedViewController { return top(selected) }
            return controller
        }
        return top(root)
    }
}
