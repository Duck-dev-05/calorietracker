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
enum AppPermission: String, CaseIterable, Identifiable {
    case readJournal, editJournal, exportJournal, restoreJournal, readHealth
    var id: String { rawValue }
    var title: String { switch self { case .readJournal: return "View journal"; case .editJournal: return "Edit journal and profile"; case .exportJournal: return "Export journal and recovery files"; case .restoreJournal: return "Restore or reset journal"; case .readHealth: return "Read this device's Apple Health data" } }
}
struct AccountSession {
    let id: String
    let email: String
    let name: String?
    var expiresAt: Date? = nil
    var displayName: String {
        let value = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? email : value
    }
    var initials: String {
        let value = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return String(email.prefix(1)).uppercased() }
        return value.split(whereSeparator: { $0.isWhitespace }).prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
    var providerName: String { id.hasPrefix("google:") ? "Google" : "Account" }
}
struct AccessPolicy {
    static func isAuthenticated(_ session: AccountSession?, now: Date = Date()) -> Bool {
        guard let session, !session.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              session.id.count <= 300, AccountValidation.email(session.email),
              let expiry = session.expiresAt, expiry.timeIntervalSinceReferenceDate.isFinite,
              expiry > now else { return false }
        return true
    }
}
struct AccessDenied: LocalizedError {
    let permission: AppPermission
    var errorDescription: String? { "Access denied: \(permission.title.lowercased()). Sign in to access your journal." }
}
@MainActor protocol AccountProvider {
    var configured: Bool { get }
    var supportsPassword: Bool { get }
    var googleSignInAvailable: Bool { get }
    var configurationMessage: String? { get }
    func signInWithGoogle() async throws -> AccountSession
    func restoreSession() async throws -> AccountSession?
    func refreshSession() async throws -> AccountSession?
    func signOut()
    func signIn(email: String, password: String) async throws -> AccountSession
    func register(name: String, email: String, password: String) async throws -> AccountSession
    func resetPassword(email: String) async throws
}
extension AccountProvider {
    var supportsPassword: Bool { true }
    var googleSignInAvailable: Bool { false }
    var configurationMessage: String? { nil }
    func signInWithGoogle() async throws -> AccountSession { throw AccountUnavailable() }
    func restoreSession() async throws -> AccountSession? { nil }
    func refreshSession() async throws -> AccountSession? { nil }
    func signOut() { }
}
struct AccountUnavailable: LocalizedError {
    var errorDescription: String? { "An account service has not been connected to this build. No account was created, no email was sent and no password was stored. Sign-in is required to unlock the app." }
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
    var supportsPassword: Bool { provider.supportsPassword }
    var googleSignInAvailable: Bool { provider.googleSignInAvailable }
    var configurationMessage: String? { provider.configurationMessage }
    @Published private(set) var restorationError: String?
    private var attemptedRestore = false
    func signInWithGoogle() async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        busy = true; defer { busy = false }
        let generation = requestGeneration
        let candidate = try await provider.signInWithGoogle()
        guard generation == requestGeneration else { provider.signOut(); throw CancellationError() }
        do { try install(candidate); restorationError = nil }
        catch { provider.signOut(); throw error }
    }
    func restoreSessionIfNeeded() async {
        guard !attemptedRestore, !busy else { return }
        attemptedRestore = true
        guard configured else { return }
        busy = true; defer { busy = false }
        let generation = requestGeneration
        do {
            let candidate = try await provider.restoreSession()
            guard generation == requestGeneration else { provider.signOut(); return }
            if let candidate { try install(candidate) }
            restorationError = nil
        } catch {
            guard generation == requestGeneration else { return }
            restorationError = "Your previous Google session could not be restored. Sign in again."
        }
    }
    var isAuthenticated: Bool { AccessPolicy.isAuthenticated(session) }
    func allows(_ permission: AppPermission) -> Bool { isAuthenticated }
    func require(_ permission: AppPermission) throws {
        guard isAuthenticated else { throw AccessDenied(permission: permission) }
    }
    /// Clears local claims only; a connected provider must revoke remote sessions separately.
    func endLocalSession() { requestGeneration += 1; expiryTask?.cancel(); expiryTask = nil; session = nil; provider.signOut(); restorationError = nil }
    private func accepted(_ candidate: AccountSession) throws -> AccountSession {
        guard AccessPolicy.isAuthenticated(candidate) else { throw DiaryFailure.invalid("The account service returned an invalid or expired session.") }
        return candidate
    }
    private var expiryTask: Task<Void, Never>?
    private func install(_ candidate: AccountSession) throws {
        let accepted = try accepted(candidate)
        expiryTask?.cancel()
        session = accepted
        expiryTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let expiry = self.session?.expiresAt else { return }
                let remaining = expiry.timeIntervalSinceNow
                if remaining <= 0 {
                    if await self.refreshExpiredSession() { return }
                    self.endLocalSession(); return
                }
                do { try await Task.sleep(nanoseconds: UInt64(min(remaining, 60) * 1_000_000_000)) }
                catch { return }
            }
        }
    }
    private func refreshExpiredSession() async -> Bool {
        guard !busy else { return false }
        busy = true; defer { busy = false }
        let generation = requestGeneration
        do {
            guard let candidate = try await provider.refreshSession(), generation == requestGeneration else { return false }
            try install(candidate)
            return true
        } catch { return false }
    }
    func signIn(email: String, password: String) async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        guard AccountValidation.email(email), !password.isEmpty else { throw DiaryFailure.invalid("Enter your email and password.") }
        busy = true; defer { busy = false }
        let generation = requestGeneration
        let candidate = try await provider.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        guard generation == requestGeneration else { throw DiaryFailure.invalid("This account request was cancelled by ending the session.") }
        try install(candidate)
    }
    func register(name: String, email: String, password: String, confirmation: String) async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        guard AccountValidation.registration(name: name, email: email, password: password, confirmation: confirmation) else { throw DiaryFailure.invalid("Check your name, email, password and confirmation.") }
        busy = true; defer { busy = false }
        let generation = requestGeneration
        let candidate = try await provider.register(name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        guard generation == requestGeneration else { throw DiaryFailure.invalid("This account request was cancelled by ending the session.") }
        try install(candidate)
    }
    func resetPassword(email: String) async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        guard AccountValidation.email(email) else { throw DiaryFailure.invalid("Enter a valid email address.") }
        busy = true; defer { busy = false }
        try await provider.resetPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
