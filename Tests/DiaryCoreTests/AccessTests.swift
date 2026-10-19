import XCTest
@testable import DiaryCore

@MainActor final class TestIdentityProvider: AccountProvider {
    let configured = true
    let claims: AccountSession
    init(_ claims: AccountSession = AccountSession(id: "test-user", email: "user@example.test", name: nil, expiresAt: Date().addingTimeInterval(3600))) { self.claims = claims }
    func signIn(email: String, password: String) async throws -> AccountSession { claims }
    func register(name: String, email: String, password: String) async throws -> AccountSession { claims }
    func resetPassword(email: String) async throws { }
}
@MainActor func signedInTestAccount() async throws -> AccountStore {
    let account = AccountStore(provider: TestIdentityProvider())
    try await account.signIn(email: "user@example.test", password: "test fixture only")
    return account
}
final class AccessTests: XCTestCase {
    private func temporaryURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AccessTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("diary.json")
    }
    func testSignedOutAndExpiredSessionsStayLocked() {
        XCTAssertFalse(AccessPolicy.isAuthenticated(nil))
        XCTAssertFalse(AccessPolicy.isAuthenticated(AccountSession(id: "user", email: "user@example.test", name: nil)))
        XCTAssertFalse(AccessPolicy.isAuthenticated(AccountSession(id: "user", email: "user@example.test", name: nil, expiresAt: .distantPast)))
        XCTAssertFalse(AccessPolicy.isAuthenticated(AccountSession(id: "", email: "user@example.test", name: nil, expiresAt: .distantFuture)))
        XCTAssertTrue(AccessPolicy.isAuthenticated(AccountSession(id: "user", email: "user@example.test", name: nil, expiresAt: .distantFuture)))
    }
    func testSignedOutCannotReadWriteExportOrResetStoredJournal() async throws {
        let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var saved = DiarySnapshot.empty; saved.foods = [Food(name: "Private", calories: 123)]
        let bytes = try saved.encoded(); try bytes.write(to: url)
        try await MainActor.run {
            let diary = Diary(url: url)
            XCTAssertFalse(diary.canReadJournal); XCTAssertTrue(diary.foods.isEmpty)
            for permission in AppPermission.allCases { XCTAssertFalse(diary.can(permission)) }
            XCTAssertFalse(diary.upsertFood(Food(name: "Denied", calories: 200)))
            XCTAssertFalse(diary.transaction { $0.foods = [] })
            XCTAssertFalse(diary.resetJournal()); XCTAssertFalse(diary.replace(with: .empty))
            XCTAssertThrowsError(try diary.backupData()); XCTAssertThrowsError(try diary.originalData())
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }
    func testSignInUnlocksExistingDiaryAndSignOutLocksWithoutDeleting() async throws {
        let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var saved = DiarySnapshot.empty; saved.foods = [Food(name: "Existing", calories: 123)]
        try saved.encoded().write(to: url)
        let account = await MainActor.run { AccountStore(provider: TestIdentityProvider()) }
        let diary = await MainActor.run { Diary(url: url, account: account) }
        await MainActor.run { XCTAssertFalse(diary.canReadJournal) }
        try await account.signIn(email: "user@example.test", password: "test fixture only")
        try await MainActor.run {
            XCTAssertTrue(diary.canReadJournal); XCTAssertEqual(diary.foods.count, 1)
            for permission in AppPermission.allCases { XCTAssertTrue(diary.can(permission)) }
            XCTAssertTrue(diary.upsertFood(Food(name: "New", calories: 200)))
            let savedBytes = try Data(contentsOf: url)
            account.endLocalSession()
            XCTAssertFalse(account.isAuthenticated); XCTAssertTrue(diary.foods.isEmpty)
            XCTAssertFalse(diary.deleteFood(saved.foods[0].id))
            XCTAssertThrowsError(try diary.backupData())
            XCTAssertEqual(try Data(contentsOf: url), savedBytes)
        }
        try await account.signIn(email: "user@example.test", password: "test fixture only")
        await MainActor.run { XCTAssertEqual(diary.foods.count, 2) }
    }
    func testInvalidProviderSessionCannotUnlockApp() async throws {
        let identity = AccountSession(id: "user", email: "user@example.test", name: nil, expiresAt: .distantPast)
        let account = await MainActor.run { AccountStore(provider: TestIdentityProvider(identity)) }
        do { try await account.signIn(email: identity.email, password: "test only"); XCTFail("Expired sessions must fail") } catch { }
        await MainActor.run { XCTAssertFalse(account.isAuthenticated); XCTAssertNil(account.session); XCTAssertFalse(account.busy) }
    }
    func testSessionExpiryRelocksAutomatically() async throws {
        let identity = AccountSession(id: "user", email: "user@example.test", name: nil, expiresAt: Date().addingTimeInterval(0.4))
        let account = await MainActor.run { AccountStore(provider: TestIdentityProvider(identity)) }
        try await account.signIn(email: identity.email, password: "test only")
        try await Task.sleep(nanoseconds: 800_000_000)
        await MainActor.run { XCTAssertFalse(account.isAuthenticated); XCTAssertNil(account.session) }
    }
    func testRegistrationUnlocksOnlyWithValidProviderSession() async throws {
        let account = await MainActor.run { AccountStore(provider: TestIdentityProvider()) }
        try await account.register(name: "User", email: "user@example.test", password: "a sufficiently long password", confirmation: "a sufficiently long password")
        await MainActor.run { XCTAssertTrue(account.isAuthenticated) }
    }
}
