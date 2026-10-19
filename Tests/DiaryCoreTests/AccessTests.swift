import XCTest
@testable import DiaryCore

@MainActor private final class ClaimsProvider: AccountProvider {
    let configured = true
    let claims: AccountSession
    init(_ claims: AccountSession) { self.claims = claims }
    func signIn(email: String, password: String) async throws -> AccountSession { claims }
    func register(name: String, email: String, password: String) async throws -> AccountSession { claims }
    func resetPassword(email: String) async throws { }
}
final class AccessTests: XCTestCase {
    private func claims(_ role: AccountRole, owner: String = "owner", expiresAt: Date = Date().addingTimeInterval(3600)) -> AccountSession {
        AccountSession(id: owner, email: "user@example.test", name: nil, role: role, expiresAt: expiresAt)
    }
    private func temporaryURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AccessTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("diary.json")
    }
    func testRolePermissionAndOwnershipMatrix() {
        for permission in AppPermission.allCases {
            XCTAssertTrue(AccessPolicy.allows(permission, session: nil, ownerAccountID: nil))
            XCTAssertFalse(AccessPolicy.allows(permission, session: nil, ownerAccountID: "owner"))
            for role in AccountRole.allCases {
                let session = claims(role)
                let expected = role == .member || role == .admin || (role == .viewer && permission == .readJournal)
                XCTAssertEqual(AccessPolicy.allows(permission, session: session, ownerAccountID: "owner"), expected, "\(role) / \(permission)")
                XCTAssertFalse(AccessPolicy.allows(permission, session: session, ownerAccountID: "someone-else"))
                XCTAssertFalse(AccessPolicy.allows(permission, session: session, ownerAccountID: nil))
            }
        }
    }
    func testExpiredMissingAndUnknownClaimsDenyByDefault() {
        for permission in AppPermission.allCases {
            XCTAssertFalse(AccessPolicy.allows(permission, session: claims(.admin, expiresAt: .distantPast), ownerAccountID: "owner"))
            let missing = AccountSession(id: "owner", email: "user@example.test", name: nil)
            XCTAssertFalse(AccessPolicy.allows(permission, session: missing, ownerAccountID: "owner"))
            XCTAssertFalse(AccessPolicy.allows(permission, session: claims(.member, owner: ""), ownerAccountID: ""))
        }
    }
    func testViewerCannotBypassServiceByCallingGenericTransactionOrRestore() async throws {
        let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var saved = DiarySnapshot.empty; saved.ownerAccountID = "owner"; saved.foods = [Food(name: "Private", calories: 100)]
        let bytes = try saved.encoded(); try bytes.write(to: url)
        let identity = claims(.viewer)
        let account = await MainActor.run { AccountStore(provider: ClaimsProvider(identity)) }
        try await account.signIn(email: identity.email, password: "test only")
        try await MainActor.run {
            let diary = Diary(url: url, account: account)
            XCTAssertTrue(diary.canReadJournal); XCTAssertEqual(diary.foods.count, 1)
            XCTAssertFalse(diary.transaction { $0.foods = [] })
            XCTAssertFalse(diary.deleteFood(saved.foods[0].id))
            XCTAssertFalse(diary.resetJournal()); XCTAssertFalse(diary.replace(with: saved))
            XCTAssertThrowsError(try diary.backupData()); XCTAssertThrowsError(try diary.originalData())
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            XCTAssertEqual(diary.foods.count, 1)
        }
    }
    func testAdminCannotReadOrOverwriteAnotherOwnersJournal() async throws {
        let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var saved = DiarySnapshot.empty; saved.ownerAccountID = "another-owner"; saved.foods = [Food(name: "Private", calories: 100)]
        let bytes = try saved.encoded(); try bytes.write(to: url)
        let identity = claims(.admin)
        let account = await MainActor.run { AccountStore(provider: ClaimsProvider(identity)) }
        try await account.signIn(email: identity.email, password: "test only")
        try await MainActor.run {
            let diary = Diary(url: url, account: account)
            XCTAssertFalse(diary.canReadJournal); XCTAssertTrue(diary.foods.isEmpty); XCTAssertNil(diary.snapshot.ownerAccountID)
            XCTAssertFalse(diary.upsertFood(Food(name: "Denied", calories: 200)))
            XCTAssertFalse(diary.resetJournal()); XCTAssertThrowsError(try diary.backupData())
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }
    func testMemberCanEditOwnJournalButCannotChangeOwnerOrImportOthers() async throws {
        let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var saved = DiarySnapshot.empty; saved.ownerAccountID = "owner"; try saved.encoded().write(to: url)
        let identity = claims(.member)
        let account = await MainActor.run { AccountStore(provider: ClaimsProvider(identity)) }
        try await account.signIn(email: identity.email, password: "test only")
        try await MainActor.run {
            let diary = Diary(url: url, account: account)
            XCTAssertTrue(diary.upsertFood(Food(name: "Owned", calories: 200)))
            XCTAssertFalse(diary.transaction { $0.ownerAccountID = nil })
            XCTAssertFalse(diary.replace(with: .empty))
            XCTAssertEqual(try DiarySnapshot.decode(diary.backupData()).ownerAccountID, "owner")
            XCTAssertTrue(diary.resetJournal())
            XCTAssertEqual(diary.snapshot.ownerAccountID, "owner")
            account.endLocalSession()
            XCTAssertFalse(diary.canReadJournal); XCTAssertTrue(diary.foods.isEmpty)
        }
    }
    func testGuestCannotAdoptAccountBackupAndRolesAreNotExported() async throws {
        let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await MainActor.run {
            let diary = Diary(url: url)
            XCTAssertTrue(diary.upsertFood(Food(name: "Local", calories: 123)))
            var foreign = DiarySnapshot.empty; foreign.ownerAccountID = "foreign"
            XCTAssertFalse(diary.replace(with: foreign))
            XCTAssertEqual(diary.foods.count, 1)
            XCTAssertFalse(String(decoding: try diary.backupData(), as: UTF8.self).contains("\"role\""))
        }
    }
    func testInvalidProviderClaimsCannotInstallSession() async throws {
        for identity in [claims(.unknown), claims(.localOwner), claims(.admin, expiresAt: .distantPast), AccountSession(id: "owner", email: "user@example.test", name: nil)] {
            let account = await MainActor.run { AccountStore(provider: ClaimsProvider(identity)) }
            do { try await account.signIn(email: "user@example.test", password: "test only"); XCTFail("Claims must be rejected") } catch { }
            await MainActor.run { XCTAssertNil(account.session); XCTAssertFalse(account.busy) }
        }
    }
    func testSchemaTwoLocalDiaryMigratesWithoutRoleOrOwnershipAssignment() throws {
        var saved = DiarySnapshot.empty; saved.schemaVersion = 2; saved.foods = [Food(name: "Local", calories: 200)]
        let loaded = try DiarySnapshot.decode(JSONEncoder().encode(saved))
        XCTAssertEqual(loaded.schemaVersion, 3); XCTAssertNil(loaded.ownerAccountID)
        XCTAssertEqual(loaded.foods.first?.id, saved.foods.first?.id)
    }
}
