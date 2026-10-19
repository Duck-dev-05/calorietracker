import XCTest
@testable import DiaryCore

@MainActor private final class GoogleTestProvider: AccountProvider {
    var configured = true
    var googleSignInAvailable = true
    var supportsPassword = false
    var googleCalls = 0
    var restoreCalls = 0
    var signOutCalls = 0
    var fail = false
    let value = AccountSession(id: "google:test", email: "user@example.test", name: "User", expiresAt: .distantFuture)
    func signInWithGoogle() async throws -> AccountSession {
        googleCalls += 1
        if fail { throw CancellationError() }
        return value
    }
    func restoreSession() async throws -> AccountSession? { restoreCalls += 1; return value }
    func signOut() { signOutCalls += 1 }
    func signIn(email: String, password: String) async throws -> AccountSession { throw AccountUnavailable() }
    func register(name: String, email: String, password: String) async throws -> AccountSession { throw AccountUnavailable() }
    func resetPassword(email: String) async throws { throw AccountUnavailable() }
}
final class GoogleAccountTests: XCTestCase {
    func testClientIDAndCallbackMustMatch() {
        let id = "123456-test.apps.googleusercontent.com"
        XCTAssertNil(GoogleOAuthSettings(clientID: id, callbackSchemes: ["com.googleusercontent.apps.123456-test"]).issue)
        XCTAssertNotNil(GoogleOAuthSettings(clientID: id, callbackSchemes: []).issue)
        for value in ["", "YOUR_CLIENT_ID", "abc.apps.googleusercontent.com.evil", "bad id.apps.googleusercontent.com"] {
            XCTAssertNotNil(GoogleOAuthSettings(clientID: value, callbackSchemes: []).issue)
        }
    }
    func testGoogleSignInUnlocksAndSignOutClearsProvider() async throws {
        let provider = await MainActor.run { GoogleTestProvider() }
        let account = await MainActor.run { AccountStore(provider: provider) }
        try await account.signInWithGoogle()
        await MainActor.run {
            XCTAssertTrue(account.isAuthenticated); XCTAssertFalse(account.supportsPassword)
            XCTAssertEqual(account.session?.name, "User")
            XCTAssertEqual(account.session?.email, "user@example.test")
            XCTAssertEqual(account.session?.providerName, "Google")
            XCTAssertEqual(provider.googleCalls, 1)
            account.endLocalSession()
            XCTAssertFalse(account.isAuthenticated); XCTAssertNil(account.session); XCTAssertEqual(provider.signOutCalls, 1)
        }
    }
    func testGoogleCancellationDoesNotUnlock() async {
        let account = await MainActor.run { () -> AccountStore in
            let provider = GoogleTestProvider(); provider.fail = true
            return AccountStore(provider: provider)
        }
        do { try await account.signInWithGoogle(); XCTFail("Cancelled sign-in must fail") } catch { }
        await MainActor.run { XCTAssertFalse(account.isAuthenticated); XCTAssertFalse(account.busy) }
    }
    func testRestorationRunsOnceAndNeverPresentsInteractiveLogin() async {
        let provider = await MainActor.run { GoogleTestProvider() }
        let account = await MainActor.run { AccountStore(provider: provider) }
        await account.restoreSessionIfNeeded(); await account.restoreSessionIfNeeded()
        await MainActor.run {
            XCTAssertTrue(account.isAuthenticated); XCTAssertEqual(provider.restoreCalls, 1); XCTAssertEqual(provider.googleCalls, 0)
        }
    }
    func testUnconfiguredGoogleNeverUnlocks() async {
        let account = await MainActor.run { AccountStore(provider: UnconfiguredAccountProvider()) }
        await account.restoreSessionIfNeeded()
        do { try await account.signInWithGoogle(); XCTFail("No Google provider configured") } catch { }
        await MainActor.run { XCTAssertFalse(account.isAuthenticated); XCTAssertFalse(account.googleSignInAvailable) }
    }
}
