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
struct AccountSession { let id: String; let email: String; let name: String? }
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
    let provider: AccountProvider
    init(provider: AccountProvider) { self.provider = provider }
    var configured: Bool { provider.configured }
    func signIn(email: String, password: String) async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        guard AccountValidation.email(email), !password.isEmpty else { throw DiaryFailure.invalid("Enter your email and password.") }
        busy = true; defer { busy = false }
        session = try await provider.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
    }
    func register(name: String, email: String, password: String, confirmation: String) async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        guard AccountValidation.registration(name: name, email: email, password: password, confirmation: confirmation) else { throw DiaryFailure.invalid("Check your name, email, password and confirmation.") }
        busy = true; defer { busy = false }
        session = try await provider.register(name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
    }
    func resetPassword(email: String) async throws {
        guard !busy else { throw DiaryFailure.invalid("An account request is already in progress.") }
        guard AccountValidation.email(email) else { throw DiaryFailure.invalid("Enter a valid email address.") }
        busy = true; defer { busy = false }
        try await provider.resetPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
