import SwiftUI

private struct AccountHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BrandLockup().padding(.bottom, 16)
            Text(title).font(.system(.largeTitle, design: .rounded).weight(.bold)).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 10)
    }
}
private struct AccountAvailability: View {
    @EnvironmentObject var account: AccountStore
    var body: some View {
        if !account.configured {
            Label(account.configurationMessage ?? "Email/password authentication is not connected in this build.", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
private struct PasswordInput: View {
    let title: String
    @Binding var text: String
    var newPassword = false
    @State private var visible = false
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if visible { TextField(title, text: $text) }
                else { SecureField(title, text: $text) }
            }.textContentType(newPassword ? .newPassword : .password).textInputAutocapitalization(.never).disableAutocorrection(true)
            Button { visible.toggle() } label: { Image(systemName: visible ? "eye.slash" : "eye").frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(visible ? "Hide \(title.lowercased())" : "Show \(title.lowercased())")
        }.padding(.leading, 14).padding(.trailing, 2).background(NourishStyle.canvas, in: RoundedRectangle(cornerRadius: 14))
    }
}
private struct AccountEmailField: View {
    @Binding var text: String
    var body: some View {
        TextField("Email address", text: $text).keyboardType(.emailAddress).textContentType(.username).textInputAutocapitalization(.never).disableAutocorrection(true).padding(16).background(NourishStyle.canvas, in: RoundedRectangle(cornerRadius: 14)).accessibilityLabel("Email address")
    }
}
struct AccountWelcomeScreen: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        PageCanvas {
            AccountHeader(title: "Your everyday,\na little healthier.", subtitle: "A personal space for your meals, movement and progress.")
            Surface {
                IconTile(icon: "person.crop.circle")
                SectionHeading(title: "Welcome to Nourish", subtitle: "Sign in or register to unlock your journal")
                NavigationLink("Log in", destination: LoginScreen()).buttonStyle(PrimaryAction())
                NavigationLink("Create an account", destination: RegisterScreen()).buttonStyle(SecondaryAction())
                AccountAvailability()
            }
            Label("Your existing local diary stays on this device.", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
            NavigationLink("Privacy & storage", destination: PrivacyScreen()).font(.footnote)
        }.navigationTitle("Welcome").navigationBarTitleDisplayMode(.inline)
    }
}
struct LoginScreen: View {
    @EnvironmentObject var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var attempted = false
    private var valid: Bool { AccountValidation.email(email) && !password.isEmpty }
    var body: some View {
        PageCanvas {
            AccountHeader(title: "Welcome back.", subtitle: "Your journal is a sign-in away.")
            GoogleAccountAction()
            if account.supportsPassword {
            Surface {
                Text("EMAIL").font(.caption.bold()).foregroundStyle(.secondary)
                AccountEmailField(text: $email)
                if attempted && !AccountValidation.email(email) { Text("Enter a valid email address.").font(.caption).foregroundStyle(.red) }
                Text("PASSWORD").font(.caption.bold()).foregroundStyle(.secondary)
                PasswordInput(title: "Password", text: $password)
                HStack { Spacer(); NavigationLink("Forgot password?", destination: ResetPasswordScreen()).font(.subheadline) }
                if let error { Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red) }
                Button(action: signIn) { HStack { if account.busy { ProgressView().tint(.white) }; Text(account.busy ? "Logging in…" : "Log in") } }.buttonStyle(PrimaryAction()).disabled(account.busy || email.isEmpty || password.isEmpty).opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
            }
            AccountAvailability()
            }
            HStack { Text("New to Nourish?").foregroundStyle(.secondary); NavigationLink("Create an account", destination: RegisterScreen()).font(.subheadline.weight(.semibold)) }.font(.subheadline).frame(maxWidth: .infinity)
        }.navigationTitle("Log in").navigationBarTitleDisplayMode(.inline).onDisappear { password = "" }
    }
    private func signIn() {
        attempted = true; error = nil
        guard valid else { error = "Check your email address and password."; return }
        Task {
            do { try await account.signIn(email: email, password: password); password = ""; dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }
}
struct RegisterScreen: View {
    @EnvironmentObject var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var error: String?
    private var valid: Bool { AccountValidation.registration(name: name, email: email, password: password, confirmation: confirmation) }
    var body: some View {
        PageCanvas {
            AccountHeader(title: "Make space for you.", subtitle: "Get started with your Google account. Your journal stays on this device.")
            GoogleAccountAction()
            if account.supportsPassword {
            Surface {
                SectionHeading(title: "Your account details")
                TextField("Your name", text: $name).accessibilityLabel("Your name").textContentType(.name).padding(16).background(NourishStyle.canvas, in: RoundedRectangle(cornerRadius: 14))
                AccountEmailField(text: $email)
                if !email.isEmpty && !AccountValidation.email(email) { Text("Enter a valid email address.").font(.caption).foregroundStyle(.red) }
                PasswordInput(title: "Create password", text: $password, newPassword: true)
                Label("Use 15–128 characters. Spaces and long passphrases are welcome.", systemImage: password.count >= 15 && password.count <= 128 ? "checkmark.circle" : "lock").font(.caption).foregroundStyle(.secondary)
                PasswordInput(title: "Confirm password", text: $confirmation, newPassword: true)
                if !confirmation.isEmpty && password != confirmation { Text("Passwords must match.").font(.caption).foregroundStyle(.red) }
                if name.count > 100 { Text("Keep your name under 100 characters.").font(.caption).foregroundStyle(.red) }
                if let error { Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red) }
                Button(action: register) { HStack { if account.busy { ProgressView().tint(.white) }; Text(account.busy ? "Creating account…" : "Create account") } }.buttonStyle(PrimaryAction()).disabled(!valid || account.busy).opacity(valid ? 1 : 0.5)
            }
            AccountAvailability()
            }
            NavigationLink("Review privacy & storage", destination: PrivacyScreen()).font(.footnote)
        }.navigationTitle("Register").navigationBarTitleDisplayMode(.inline).onDisappear { clearPasswords() }
    }
    private func clearPasswords() { password = ""; confirmation = "" }
    private func register() {
        guard valid else { return }; error = nil
        Task {
            do { try await account.register(name: name, email: email, password: password, confirmation: confirmation); clearPasswords(); dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }
}
struct ResetPasswordScreen: View {
    @EnvironmentObject var account: AccountStore
    @State private var email = ""
    @State private var feedback: String?
    var body: some View {
        PageCanvas {
            AccountHeader(title: "Let's get you back in.", subtitle: "Enter the email associated with your account.")
            if account.supportsPassword {
            Surface {
                AccountEmailField(text: $email)
                if let feedback { Text(feedback).font(.footnote).foregroundStyle(.secondary) }
                Button(account.busy ? "Requesting…" : "Request reset email") {
                    Task { do { try await account.resetPassword(email: email); feedback = "If an account exists for this email, follow the service's reset instructions." } catch { feedback = error.localizedDescription } }
                }.buttonStyle(PrimaryAction()).disabled(!AccountValidation.email(email) || account.busy)
            }
            AccountAvailability()
            } else {
                Surface { Text("Google manages your password. Use Google Account recovery if you cannot sign in; Nourish never asks for your Google password.").font(.subheadline); Link("Recover your Google account", destination: URL(string: "https://accounts.google.com/signin/recovery")!) }
                GoogleAccountAction()
            }
        }.navigationTitle("Reset password").navigationBarTitleDisplayMode(.inline)
    }
}
