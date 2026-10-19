# Activate Google sign-in (Windows + GitHub Actions)

The code uses Google's official GoogleSignIn SDK 10.0.0 and an **iOS OAuth client ID**. No client secret, Firebase project, service-account key or server OAuth client is required for this local-journal sign-in flow. Google must issue the client ID; the app cannot invent one.

## 1. Create the public iOS client ID

1. Open [Google Cloud Console](https://console.cloud.google.com/) in your Google account and select/create the project that will own this application.
2. Configure Google Auth Platform branding/audience/consent for your app. If the app is in testing, add the Google accounts that should be allowed to test it.
3. Create an OAuth client with application type **iOS** and bundle ID **com.personal.CalorieTracker**. Use the iOS client, not a Web/Android client.
4. Copy its client ID, ending in `.apps.googleusercontent.com`. Do not copy or send a client secret.

## 2. Configure from Windows

From `D:\Code\calorietracker` run:

```powershell
py scripts/configure-google.py --client-id 'PASTE_THE_ACTUAL_IOS_CLIENT_ID_HERE'
```

The command saves the public identifier in `Config/GoogleSignIn.json` and generates the ignored `Config/GoogleInfo.generated.plist`. It derives the reversed callback URL scheme automatically. Placeholder strings are rejected.

For builds using the committed config file, commit/push `Config/GoogleSignIn.json`. OAuth client IDs are public app identifiers, not secrets.

Alternatively, set the GitHub repository **Actions variable** `GOOGLE_IOS_CLIENT_ID` to the actual iOS client ID. This overrides the JSON file during the IPA workflow. Trigger the Build TrollStore IPA workflow after changing a repository variable; changing the variable alone does not rebuild an existing IPA.

Never paste a client secret into either configuration path. No environment variable needs to contain a secret.

## 3. Build and test

The normal `scripts/build-trollstore.sh` runs the configuration generator before XcodeGen. If building manually on a Mac, run `python3 scripts/configure-google.py` before generating/building the project. The IPA contains the public client ID and matching `CFBundleURLTypes`; the SwiftUI app forwards callbacks to Google's SDK.

Install the new IPA and tap Google sign-in from Login or Register. Verify successful consent, browser callback, cancellation, incorrect test-user settings, relaunch restoration, expiry refresh, sign-out and no automatic interactive login on launch. Existing Home stays public and no user roles are introduced.

Google's SDK handles credential persistence with Keychain. Google's documentation requires appropriate Apple signing for Keychain support; **the fake-signed TrollStore installation must be tested on the actual phone**. Build success does not prove Google OAuth/Keychain work in that installation. Keychain errors do not unlock the app, and the implementation does not fall back to plaintext credentials or invented sessions.

## Boundaries

- Google authenticates the user; the journal remains one local on-device diary. Different Google accounts do not get isolated journals or cloud sync in this version. The UI discloses that limitation.
- No food/Health data is sent to Google by the app's sign-in adapter. It requests the SDK's basic profile/email flow only.
- Google sign-in is also used to get started; no separate Nourish email/password registration exists in this provider. Google account recovery manages forgotten passwords.
- Sign out clears the SDK's credentials for this app. It is not Google account deletion and does not revoke prior consent grants.
- If a backend is introduced later, validate Google ID tokens on that backend; do not trust a client-supplied email/ID as server authentication. That requires a separate server integration, not a client secret embedded in the IPA.

## Official references

- [Google iOS setup](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Google sign-in, callbacks and restoration](https://developers.google.com/identity/sign-in/ios/sign-in)
- [Google backend authentication](https://developers.google.com/identity/sign-in/ios/backend-auth)
