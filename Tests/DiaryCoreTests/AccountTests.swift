import XCTest
@testable import DiaryCore

final class AccountTests: XCTestCase {
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
