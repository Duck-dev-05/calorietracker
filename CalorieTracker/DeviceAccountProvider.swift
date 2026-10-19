import Foundation
import Security
import CommonCrypto

/// Device-only account database. Keychain contains salted verifiers, never passwords.
@MainActor final class DeviceAccountProvider: AccountProvider {
    private struct Record: Codable {
        let id: String
        let name: String
        let email: String
        let salt: Data
        let verifier: Data
        var failures = 0
        var lockedUntil: Date?
    }
    private let google = GoogleAccountProvider()
    private var localSession: AccountSession?
    var configured: Bool { true }
    var supportsPassword: Bool { true }
    var googleSignInAvailable: Bool { google.googleSignInAvailable }
    var configurationMessage: String? { google.configurationMessage }
    private let service = "com.personal.CalorieTracker.local-accounts.v1"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "database"]
    }
    private func read() throws -> [Record] {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data else { throw storageError() }
        do { return try JSONDecoder().decode([Record].self, from: data) }
        catch { throw DiaryFailure.invalid("The local account database could not be read. Existing accounts were preserved.") }
    }
    private func write(_ records: [Record]) throws {
        let data = try JSONEncoder().encode(records)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var request = query
            request[kSecValueData as String] = data
            request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else { throw storageError() }
        } else if status != errSecSuccess { throw storageError() }
    }
    private func storageError() -> DiaryFailure {
        .invalid("Local accounts could not access this installation's private Keychain. Unlock your iPhone and check your TrollStore installation, then try again.")
    }
    private static func normalized(_ email: String) -> String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    private static func derive(_ password: String, salt: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let bytes = Array(password.utf8)
            var output = Data(count: 32)
            let status = output.withUnsafeMutableBytes { destination in
                salt.withUnsafeBytes { saltBytes in
                    bytes.withUnsafeBytes { passwordBytes in
                        CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordBytes.baseAddress!.assumingMemoryBound(to: Int8.self), bytes.count,
                            saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 600_000,
                            destination.baseAddress!.assumingMemoryBound(to: UInt8.self), 32)
                    }
                }
            }
            guard status == kCCSuccess else { throw DiaryFailure.invalid("Password verification could not finish. Please try again.") }
            return output
        }.value
    }
    private func session(_ record: Record) -> AccountSession {
        AccountSession(id: record.id, email: record.email, name: record.name, expiresAt: Date().addingTimeInterval(12 * 60 * 60))
    }
    func register(name: String, email: String, password: String) async throws -> AccountSession {
        guard AccountValidation.registration(name: name, email: email, password: password, confirmation: password) else { throw DiaryFailure.invalid("Check your registration details.") }
        let address = Self.normalized(email)
        guard !(try read()).contains(where: { $0.email == address }) else { throw DiaryFailure.invalid("This email already has a local account. Log in instead.") }
        var salt = Data(count: 32)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard status == errSecSuccess else { throw storageError() }
        let verifier = try await Self.derive(password, salt: salt)
        // Re-read after hashing so an asynchronous operation cannot overwrite another registration.
        var records = try read()
        guard !records.contains(where: { $0.email == address }) else { throw DiaryFailure.invalid("This email already has a local account. Log in instead.") }
        let record = Record(id: "local:" + UUID().uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: address, salt: salt, verifier: verifier)
        records.append(record)
        try write(records)
        google.signOut()
        let result = session(record); localSession = result
        return result
    }
    func signIn(email: String, password: String) async throws -> AccountSession {
        guard AccountValidation.email(email), !password.isEmpty, password.count <= 128 else { throw DiaryFailure.invalid("Check your email and password.") }
        let address = Self.normalized(email)
        let records = try read()
        let record = records.first { $0.email == address }
        if let until = record?.lockedUntil, until > Date() { throw DiaryFailure.invalid("Too many attempts. Try again in 15 minutes.") }
        let candidate = try await Self.derive(password, salt: record?.salt ?? Data(repeating: 0, count: 32))
        let expected = record?.verifier ?? Data(repeating: 0, count: 32)
        var difference: UInt8 = 0
        for (a, b) in zip(candidate, expected) { difference |= a ^ b }
        guard let record else { throw DiaryFailure.invalid("Email or password is incorrect. Register first if you have no account on this iPhone.") }
        var latest = try read()
        guard let index = latest.firstIndex(where: { $0.id == record.id }) else { throw storageError() }
        if difference != 0 {
            latest[index].failures += 1
            if latest[index].failures >= 5 { latest[index].lockedUntil = Date().addingTimeInterval(15 * 60); latest[index].failures = 0 }
            try write(latest)
            throw DiaryFailure.invalid("Email or password is incorrect.")
        }
        latest[index].failures = 0; latest[index].lockedUntil = nil
        try write(latest)
        google.signOut()
        let result = session(record); localSession = result
        return result
    }
    func signInWithGoogle() async throws -> AccountSession {
        let result = try await google.signInWithGoogle()
        localSession = nil
        return result
    }
    func restoreSession() async throws -> AccountSession? { try await google.restoreSession() }
    func refreshSession() async throws -> AccountSession? {
        if localSession != nil { return nil }
        return try await google.refreshSession()
    }
    func signOut() { localSession = nil; google.signOut() }
    func resetPassword(email: String) async throws {
        throw DiaryFailure.invalid("Local accounts cannot receive reset emails. No password was changed. Use your original password or Google sign-in.")
    }
}
