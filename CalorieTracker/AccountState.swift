import Foundation
import Combine

enum AccountValidation {
    static func email(_ input: String) -> Bool {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count <= 254 else { return false }
        return value.range(of: #"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]*[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]*[A-Z0-9])?)+$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
    static func registration(name: String, email: String, password: String, confirmation: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 100 && self.email(email) && (15...128).contains(password.count) && password == confirmation
    }
}
enum AccountRole: String, CaseIterable, Identifiable {
    case localOwner, member, viewer, admin, unknown
    var id: String { rawValue }
    var title: String { switch self { case .localOwner: return "Local owner"; case .member: return "Member"; case .viewer: return "Viewer"; case .admin: return "Admin"; case .unknown: return "No assigned role" } }
}
enum AppPermission: String, CaseIterable, Identifiable {
    case readJournal, editJournal, exportJournal, restoreJournal, readHealth
    var id: String { rawValue }
    var title: String { switch self { case .readJournal: return "View journal"; case .editJournal: return "Edit journal and profile"; case .exportJournal: return "Export journal and recovery files"; case .restoreJournal: return "Restore or reset journal"; case .readHealth: return "Read this device's Apple Health data" } }
}
struct AccountSession {
    let id: String
    let email: String
    let name: String?
    // Only a validated identity-provider response may supply account claims.
    var role: AccountRole = .unknown
    var expiresAt: Date? = nil
}
struct AccessPolicy {
    private static let ownerPermissions: Set<AppPermission> = [.readJournal, .editJournal, .exportJournal, .restoreJournal, .readHealth]
    static func allows(_ permission: AppPermission, session: AccountSession?, ownerAccountID: String?, now: Date = Date()) -> Bool {
        guard let session else { return ownerAccountID == nil && ownerPermissions.contains(permission) }
        guard !session.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let expiry = session.expiresAt, expiry.timeIntervalSinceReferenceDate.isFinite, expiry > now,
              ownerAccountID == session.id else { return false }
        switch session.role {
        case .member, .admin: return ownerPermissions.contains(permission)
        case .viewer: return permission == .readJournal
        case .localOwner, .unknown: return false
        }
    }
}
struct AccessDenied: LocalizedError {
    let permission: AppPermission
    var errorDescription: String? { "Access denied: \(permission.title.lowercased()). Your role, session or journal ownership does not allow this action." }
}
@MainActor protocol AccountProvider {
    var configured: Bool { get }
    func signIn(email: String, password: String) async throws -> AccountSession
    func register(name: String, email: String, password: String) async throws -> AccountSession
    func resetPassword(email: String) async throws
}
struct AccountUnavailable: LocalizedError {
    var errorDescription: String? { "An account service has not been connected to this build. No account was created, no email was sent and no password was stored. Continue with the local journal for now." }
}
@MainActor final class UnconfiguredAccountProvider: AccountProvider {
    let configured = false
    func signIn(email: String, password: String) async throws -> AccountSession { throw AccountUnavailable() }
    func register(name: String, email: String, password: String) async throws -> AccountSession { throw AccountUnavailable() }
    func resetPassword(email: String) async throws { throw AccountUnavailable() }
}
@MainActor final class AccountStore: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var session: AccountSession?
    private var requestGeneration = 0
    let provider: AccountProvider
    init(provider: AccountProvider) { self.provider = provider }
    var configured: Bool { provider.configured }
    var role: AccountRole { session?.role ?? .localOwner }
    func allows(_ permission: AppPermission, ownerAccountID: String?) -> Bool { AccessPolicy.allows(permission, session: session, ownerAccountID: ownerAccountID) }
    func require(_ permission: AppPermission, ownerAccountID: String?) throws {
        guard allows(permission, ownerAccountID: ownerAccountID) else { throw AccessDenied(permission: permission) }
    }
    /// Clears local claims only; a connected provider must revoke remote sessions separately.
    func endLocalSession() { requestGeneration += 1; session = nil }
    private func accepted(_ candidate: AccountSession) throws -> AccountSession {
        guard !candidate.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, candidate.id.count <= 300,
              AccountValidation.email(candidate.email), let expiry = candidate.expiresAt,
              expiry.timeIntervalSinceReferenceDate.isFinite, expiry > Date(), [.member, .viewer, .admin].contains(candidate.role) else { throw DiaryFailure.invalid("The account service returned an invalid, expired or unassigned access role.") }
        return candidate
    }
    func signIn(email: String, password: String) async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        guard AccountValidation.email(email), !password.isEmpty else { throw DiaryFailure.invalid("Enter your email and password.") }
        busy = true; defer { busy = false }
        let generation = requestGeneration
        let candidate = try await provider.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        guard generation == requestGeneration else { throw DiaryFailure.invalid("This account request was cancelled by ending the session.") }
        session = try accepted(candidate)
    }
    func register(name: String, email: String, password: String, confirmation: String) async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        guard AccountValidation.registration(name: name, email: email, password: password, confirmation: confirmation) else { throw DiaryFailure.invalid("Check your name, email, password and confirmation.") }
        busy = true; defer { busy = false }
        let generation = requestGeneration
        let candidate = try await provider.register(name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        guard generation == requestGeneration else { throw DiaryFailure.invalid("This account request was cancelled by ending the session.") }
        session = try accepted(candidate)
    }
    func resetPassword(email: String) async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        guard AccountValidation.email(email) else { throw DiaryFailure.invalid("Enter a valid email address.") }
        busy = true; defer { busy = false }
        try await provider.resetPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
