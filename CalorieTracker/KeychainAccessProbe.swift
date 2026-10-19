import Foundation
import Security

/// Checks the same default Keychain group used by Google's SDK. Only a temporary,
/// random probe item is touched; it never queries or deletes authentication items.
enum KeychainAccessProbe {
    static func verify() throws {
        let data = Data(UUID().uuidString.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.personal.CalorieTracker.keychain-probe",
            kSecAttrAccount as String: UUID().uuidString
        ]
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let writeStatus = SecItemAdd(add as CFDictionary, nil)
        guard writeStatus == errSecSuccess else { throw failure(writeStatus) }
        defer { SecItemDelete(query as CFDictionary) }
        var read = query
        read[kSecReturnData as String] = true
        read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let readStatus = SecItemCopyMatching(read as CFDictionary, &result)
        guard readStatus == errSecSuccess else { throw failure(readStatus) }
        guard (result as? Data) == data else { throw DiaryFailure.invalid("The device Keychain check returned unexpected data. No Google sign-in was started.") }
        let deleteStatus = SecItemDelete(query as CFDictionary)
        guard deleteStatus == errSecSuccess else { throw failure(deleteStatus) }
    }
    private static func failure(_ status: OSStatus) -> DiaryFailure {
        if status == errSecInteractionNotAllowed {
            return .invalid("Unlock your iPhone and try Google sign-in again. Keychain status: \(status).")
        }
        return .invalid("This installation cannot use its private Keychain (status \(status)). Install the latest Nourish IPA as an update through TrollStore, then try again.")
    }
}
