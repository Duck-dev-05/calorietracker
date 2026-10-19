import Foundation

struct GoogleOAuthSettings {
    let clientID: String
    let callbackSchemes: [String]
    var reversedClientID: String { clientID.split(separator: ".").reversed().joined(separator: ".") }
    var issue: String? {
        let suffix = ".apps.googleusercontent.com"
        let prefix = String(clientID.dropLast(min(clientID.count, suffix.count)))
        guard clientID.hasSuffix(suffix), !prefix.isEmpty,
              !clientID.localizedCaseInsensitiveContains("YOUR_"),
              clientID.range(of: #"^[A-Za-z0-9-]+\.apps\.googleusercontent\.com$"#, options: .regularExpression) != nil else {
            return "Google sign-in needs your Google Cloud iOS client ID for com.personal.CalorieTracker. Add it to Config/GoogleSignIn.json and rebuild."
        }
        guard callbackSchemes.contains(reversedClientID) else { return "The Google OAuth callback scheme is missing or does not match the iOS client ID. Rebuild with scripts/configure-google.py." }
        return nil
    }
    static func load(bundle: Bundle = .main) -> GoogleOAuthSettings {
        let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return GoogleOAuthSettings(clientID: bundle.object(forInfoDictionaryKey: "GIDClientID") as? String ?? "", callbackSchemes: types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] })
    }
}
