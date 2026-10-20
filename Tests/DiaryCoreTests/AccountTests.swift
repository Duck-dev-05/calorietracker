import XCTest
@testable import DiaryCore

final class AccountTests: XCTestCase {
    func testLocalProfileIdentityUsesRegisteredDetails() {
        let session = AccountSession(id: "local:test", email: "user@example.test", name: "Taylor Smith", expiresAt: .distantFuture)
        XCTAssertTrue(AccessPolicy.isAuthenticated(session))
        XCTAssertEqual(session.displayName, "Taylor Smith")
        XCTAssertEqual(session.initials, "TS")
        XCTAssertEqual(session.providerName, "Local account")
        XCTAssertEqual(session.email, "user@example.test")
    }
    func testGoogleAvatarUsesHTTPSAndLocalAccountsFallBackToInitials() {
        var session = AccountSession(id: "google:test", email: "user@example.test", name: "Taylor Smith", expiresAt: .distantFuture, avatarURL: URL(string: "https://lh3.googleusercontent.com/test-photo"))
        XCTAssertEqual(session.safeAvatarURL, session.avatarURL)
        session.avatarURL = URL(string: "http://example.test/photo")
        XCTAssertNil(session.safeAvatarURL)
        session.avatarURL = URL(string: "https://user:password@example.test/photo")
        XCTAssertNil(session.safeAvatarURL)
        let local = AccountSession(id: "local:test", email: "user@example.test", name: "Taylor Smith", expiresAt: .distantFuture)
        XCTAssertNil(local.safeAvatarURL); XCTAssertEqual(local.initials, "TS")
    }
    func testEmailValidationDoesNotAcceptMalformedInput() {
        XCTAssertTrue(AccountValidation.email(" user@example.test "))
        XCTAssertTrue(AccountValidation.email("name+tag@example.test"))
        for invalid in ["", "abc", "a@", "@example.test", "a b@example.test", "name@example", "name@example.test\nother"] { XCTAssertFalse(AccountValidation.email(invalid), invalid) }
    }
    func testRegistrationRequiresMatchingLongPasswordAndName() {
        let password = "a sufficiently long phrase"
        XCTAssertTrue(AccountValidation.registration(name: "User", email: "user@example.test", password: password, confirmation: password))
        XCTAssertFalse(AccountValidation.registration(name: " ", email: "user@example.test", password: password, confirmation: password))
        XCTAssertFalse(AccountValidation.registration(name: "User", email: "user@example.test", password: "short", confirmation: "short"))
        XCTAssertFalse(AccountValidation.registration(name: "User", email: "user@example.test", password: password, confirmation: password + "x"))
        XCTAssertFalse(AccountValidation.registration(name: "User", email: "user@example.test", password: String(repeating: "a", count: 129), confirmation: String(repeating: "a", count: 129)))
    }
    func testUnconfiguredServiceNeverCreatesSessionOrClaimsSuccess() async {
        let store = await MainActor.run { AccountStore(provider: UnconfiguredAccountProvider()) }
        do { try await store.signIn(email: "user@example.test", password: "entered password"); XCTFail("Unconfigured login must fail") } catch { XCTAssertTrue(error is AccountUnavailable) }
        do { try await store.register(name: "User", email: "user@example.test", password: "a long password phrase", confirmation: "a long password phrase"); XCTFail("Unconfigured registration must fail") } catch { XCTAssertTrue(error is AccountUnavailable) }
        do { try await store.resetPassword(email: "user@example.test"); XCTFail("Unconfigured reset must fail") } catch { XCTAssertTrue(error is AccountUnavailable) }
        await MainActor.run { XCTAssertNil(store.session); XCTAssertFalse(store.busy); XCTAssertFalse(store.configured) }
    }
}
