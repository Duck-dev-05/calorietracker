# Nourish — personal iPhone calorie tracker

Native SwiftUI application with an iOS 15 minimum. All journal content comes from user entry or optional Apple Health reads. No sample meals, body measurements, calorie targets or ingredient suggestions are seeded into the app.

## Build an IPA from Windows

1. Push to the GitHub repository's `main` branch, or open Actions → Build TrollStore IPA → Run workflow.
2. The hosted Mac runs `swift test`, compiles with Xcode 26.0.1 and packages an arm64 device IPA with a minimum deployment target of iOS 15.0.
3. Download the `Nourish-TrollStore-iOS15` artifact and extract `Nourish.ipa` from the ZIP.
4. Transfer the IPA to your supported iPhone and install it through your existing TrollStore installation.

TrollStore installs the app; it does not compile it. No signing certificate is supplied to this workflow. App UI support and TrollStore OS compatibility are separate. Check the [official TrollStore project](https://github.com/opa334/TrollStore) for installation compatibility.

Optional Mac build: install Xcode, XcodeGen and ldid, then run `bash scripts/build-trollstore.sh`. Ordinary Xcode development requires your own signing configuration.

## First use and real data

- Setup starts with blank measurements, no goal, no food style and no calorie target. You may leave them blank and fill them in later.
- Today shows logged totals and available Health results. Remaining calories are unavailable until you set your own target; the app does not invent a target.
- You → Personal details stores optional measurements, age and activity context. These do not calculate a calorie prescription.
- You → Goals & target sets or clears your manual target and optional milestone/note.
- Meals starts empty. Create a reusable meal with its name, ingredients/serving description, calories per serving and vegetarian classification. Edit/delete it from its detail page. Calories are not generated or fetched automatically.
- Log a saved meal now or plan it for another day. Planned entries count toward intake only when marked eaten.
- Food preferences filters the user's own saved meals using food style and ingredient-word exclusions. There are no preset ingredient quick picks. Text exclusions are not verified allergy checks.
- Diary supports manual food entry, editing, deletion and past days. Weight and water history are entered by the user.
- Zero entries produce real empty states. Input ranges, serving selectors, meal-category options and water quick-add buttons are controls, not stored sample records.

## Existing data and backups

Upgrades preserve existing profiles, logged food, weight, water and planned meals. Earlier versions did not mark whether a saved measurement matched an old default, so those values are not automatically erased. Clear measurement fields or the target and save if you want to remove a previously saved value. Saved meals are a new optional collection and migrate as empty when absent.

You → Settings → Backup & restore exports/imports versioned JSON through Files. Restore validates and previews a selected file, then requires confirmation. The prior diary bytes are preserved in a local recovery copy before replacement. Exports contain personal information and are not encrypted by Nourish. They include saved meals but exclude appearance preferences and Health permissions. There is no automatic cloud sync or merge. Maximum supported file size is 10 MB and maximum combined entry count is 100,000.

Unreadable storage opens a dedicated recovery page instead of editable screens. Retry, export original bytes, restore a known backup or confirm archive-and-reset. If archiving fails, replacement/reset is refused.

## Health and privacy

The app reads height, weight, steps and active energy through HealthKit only when connected. It never fills missing metrics with fabricated values. Read restrictions and missing records cannot always be distinguished. Measurements are copied to the profile only when the user imports them. Food is not imported from or written to Health. Activity energy is displayed separately from the calorie target.

No account, server, advertising or analytics is used. Local snapshots are validated and written atomically with file protection before publishing committed changes. Transactions are currently serialized with synchronous local writes; moving large-file work off the main thread remains future work.

## Interface

Personal details has a profile banner and numbered editing groups; Goals has direction tiles and a manual calorie panel; Preferences has removable exclusion chips and a preview of the actual saved meal collection. A persistent Save dock keeps actions reachable. Accessibility text sizes switch grids and meal previews to one column.

iOS 15 uses classic navigation; iOS 16–18 use modern navigation/sheets; iOS 26+ uses native system bar styling via the Xcode 26 SDK. The minimum remains iOS 15. Newer APIs are availability-guarded. No iOS 26 TrollStore support is implied.

## Verification

CI runs the macOS Swift package tests before building the IPA. Tests use synthetic inputs isolated under `Tests/`; these are never bundled or loaded by the iOS app. They check legacy migration, empty first-run state, missing targets, failed saves, atomic/idempotent plan transfer, file recovery, backup round trips, optional profile fields and user-created meal persistence/filtering.

The user confirmed an earlier IPA launches on their iPhone. On-device validation is still needed for new creation/edit/deletion flows, empty states, backup dialogs, Health permissions, large text, keyboard/Save positioning and layouts on each available OS generation.

Deferred: live food database, barcode/photo recognition, automatic calorie recommendations, cloud synchronization and reminders.

## Critical build-order pages (0.5.0)

- Tap Steps/Active energy on Today, or a metric in Apple Health, for result status, last check, source/measurement date when available, individual refresh and measurement import.
- Health reads run independently. An individual failure clears that current result without blocking other metrics. Foreground refresh does not request permission; Connect/manage access is explicit. Values expire after 15 minutes, with daily totals also invalidated by local day/timezone changes.
- Progress → Weight history lists real dated measurements and opens an edit/delete page. Current-weight provenance is stored; deleting the chosen dated entry reconciles to the next eligible entry or an unset value. Newer explicit profile/Health values are protected from older measurements. Old profiles without provenance are labeled accordingly.
- Water now includes date history, custom amounts, edits and confirmed deletion. Planner rows open editing, rescheduling, saved-value copying, confirmed deletion and mark-as-eaten. The plus action creates a real user-entered plan.
- A shared minute/foreground/significant-time-change refresh drives date-sensitive screens. Screens follow the current day only while viewing Today, preserving deliberate historical/future selections. Historical timestamps are grouped in the device's current local timezone; no historical timezone is fabricated.

The store remains atomic and synchronous in this iteration. Off-main-thread persistence, portion-aware food selection and the optional AI pilot are follow-up work. No provider credentials, mock Health readings or example meals are included in the app.

Additional tests cover partial Health failures, permission/refresh separation, unavailable/empty results, freshness/day/timezone expiry, weight reconciliation, water/plan editing and identity rules, shared day rollover and future food rejection. Test providers exist only in the test target.

## Login and registration pages (0.6.0)

The welcome screen offers Log in and Create account. Login includes email/password fields, visibility control and a password-reset link. Registration includes name, email, a matching 15–128-character password and confirmation. The UI provides loading/error states and password autofill hints. Profile → Account and Settings → Login & registration reopen these pages.

**Authentication is not connected.** No backend, identity-provider project, endpoint or client configuration was supplied. The included UnconfiguredAccountProvider always returns a clear unavailable error: it does not create accounts, sign in, send mail, retain passwords or fabricate a session. Passwords live only in form state and are cleared when leaving the screen. Version 0.8.1 requires sign-in; guest continuation has been removed.

To enable real accounts, select/configure an identity provider or backend, implement AccountProvider, align validation with its policy, securely persist actual tokens using Keychain, and define account switching/data-isolation, verification, reset, sign-out and deletion behavior. Do not embed provider secrets in the IPA. Existing local diaries must not silently become shared or uploaded when authentication is connected. The current account scaffolding intentionally provides no cloud sync or real-session persistence.

Device checks after provider configuration: signed-out access stays locked, valid sign-in reaches diary/setup, Profile and Settings links work, secure-field visibility/autofill and keyboard behavior are usable, malformed email/mismatched password errors are readable, and service-unavailable submissions leave the diary unchanged.


### Version 0.7.0 — nutrition and data protection

- Schema 2 preserves old calorie entries and archives the original before the first migrated save.
- Stale diary instances refuse to overwrite changed/deleted files; reload through recovery before retrying.
- Optional protein/carbohydrate/fat entry, explicit unknown values and fractional saved-meal servings.
- Validated portion calculations and nutrition snapshots preserved through planning, logging, export and restore.
- No automatic target/activity adjustment or invented nutrition. Manual values still depend on the label/source you enter.


### Version 0.8.1 — sign-in required

The role model introduced in 0.8.0 has been removed. Access has two states: signed out (locked) and signed in with a valid session (unlocked). Welcome/login/register/reset-password remain available while locked. There is no Continue without an account button. Settings -> Account & security provides Sign out; logout/expiry hides application data without deleting the diary.

**The production identity provider remains unconfigured. This build stays at the authentication pages until a real provider is connected.** Form validation does not create a session. No mock sign-in or device-stored plaintext password is introduced. Any valid connected-provider session unlocks the same existing on-device journal; per-account storage separation is not implemented.

The authentication gate supersedes earlier optional-login/guest instructions in this README. Tests use isolated provider fixtures to exercise login/logout and continue checking existing nutrition/migration behavior.


### Version 0.8.3 — open Home before sign-in

Launch shows the public Today welcome page and tabs without redirecting to Login. Login appears when opening a protected tab/Profile or choosing Sign in. Personal journal data and actions remain locked until a valid provider session exists. This supersedes the launch routing in 0.8.1–0.8.2; authentication is still unconfigured.


### Version 0.9.0 — Nourish visual identity

Shared forest/ivory/lime styling, a new public welcome hero, consistent page/card/button styling, adaptive metric grids and branded Home/account/tracking/profile/onboarding pages. New logo assets are in Brand/; the full generation prompt is in Brand/README.md. Assets.xcassets includes the in-app mark and all required iPhone app icon sizes. IPA packaging checks the icon metadata and compiled catalog.

Launch and authentication behavior, journal data and nutrition calculations are unchanged. Device visual checks remain necessary.


### Version 0.10.0 — Google sign-in

Login and Register now use the official Google sign-in button/provider. Callback routing, SDK Keychain restoration, expiry refresh and Google sign-out are wired to the existing private-page gate. Home still opens without forcing login. No separate Google password is collected and no user roles are introduced.

**Activation requires your actual Google Cloud iOS OAuth client ID** for `com.personal.CalorieTracker`. Set `Config/GoogleSignIn.json` using `py scripts/configure-google.py --client-id 'ACTUAL_ID'`, or set the GitHub Actions repository variable `GOOGLE_IOS_CLIENT_ID`, then rebuild. No client secret is required. The default configuration is intentionally empty and cannot complete sign-in.

See [Google setup instructions](Config/README.md). Google OAuth/Keychain must be tested on the actual TrollStore installation; CI build success is not a live login test. The journal remains one shared local diary behind Google authentication, not isolated account storage or cloud sync.


### Version 0.10.1 — OAuth client configured

The supplied Google iOS client ID is now in Config/GoogleSignIn.json. Builds generate its callback scheme automatically and verify both values in the packaged app. This supersedes the earlier empty-configuration limitation.

Google Cloud currently restricts OAuth to test users: add your sign-in email under Google Auth Platform -> Audience -> Test users. Install the rebuilt IPA to verify Google sign-in/callback and Keychain persistence on the actual TrollStore device.


### Version 0.10.2 — TrollStore Keychain identity

The signing configuration now includes an explicit app-only Keychain group and matching TrollStore application identity, retaining HealthKit. Packaging validates the generated and extracted entitlements and rejects broad/unrelated grants. Google sign-in checks default Keychain write/read/delete access before starting OAuth and reports a status code if access still fails.

Update the existing installation through TrollStore to preserve diary data. The bundle ID, journal schema and Google client ID remain unchanged. Verify sign-in and restoration on the phone; the build cannot prove device Keychain access.


### Version 0.10.3 — account details in Profile

After Google sign-in, Profile shows the account name, email, initials and signed-in provider. The same details appear in Account & security. Missing names fall back to email; any manual journal name stays separate. Measurements/goals remain your saved values and are not overwritten by Google profile data.


## Local email/password accounts — v0.11.0

Login and Register offer local email/password accounts alongside Google. Local account records (ID, name, normalized email, random salt, PBKDF2-HMAC-SHA256 verifier with 600,000 iterations and failed-attempt lockout) are stored in the app-private, device-only Keychain database. Plaintext passwords are never persisted or exported with diary backups. Hashing runs off the main thread; writes must succeed before authentication succeeds. Five failed attempts lock an account for 15 minutes. Registration signs the user in and Profile displays their registered name/email. Local sessions expire after 12 hours and require login again after app restart; Google restoration remains available. Logout preserves accounts and journal.

Limitations: local email ownership is unverified; no email reset, cloud account sync or per-account journal isolation. Every authenticated account still opens the same on-device journal. Keychain/device restore, registration, duplicate email, wrong password, lockout, logout/relogin and Google switching require physical iPhone validation. Do not delete the app or reset journal data to recover a password. Future work: tested account recovery/deletion and explicit journal ownership/isolation.


## Interface redesign — v0.12.0

Shared teal/mint palette, cool canvas, typographic headers, refined surfaces and navigation rows apply across public home, onboarding, authentication, tracking, personalization, Health and recovery. Today adds responsive calorie-summary and quick-action layouts. Diary adds meal totals and clearer date/intake hierarchy while preserving swipe deletion and entry editing. Meals uses compact serving cards. Progress uses a seven-day review and explicit missing-entry states; bars are labelled as using the current target. Profile presents account identity and three separate personalization destinations. Login/Register prioritize local forms, with a separate Google option. iOS 15 fallback and native newer navigation remain in place; no persistence schema or nutrition calculation changes.

Validation: configuration/core tests and iOS IPA compilation via CI; visual checks on iPhone (light/dark, larger text, keyboard, small screens, VoiceOver, iOS 15 and newer navigation) remain required because this Windows workspace cannot run an iOS simulator.


## v0.13.0 — Phase 1 nutrition foundation

Food, saved meals and plans share a Nutrition & Portion page: label reference amount/unit, calories/macros, consumed quantity and source, with a calculated preview. Cancel discards editor changes; Apply updates a draft and Save commits it. Unchanged nutrient values retain exact precision. Calorie edits no longer silently clear macros. Meal details accepts arbitrary decimal servings within validated limits. Legacy metadata edits retain unknown nutrition. Zero-energy entries and portions rounding below 1 kcal remain explicitly unsupported, without silent coercion. No BMR/TDEE estimates or dynamic activity budgets are enabled in this release.


## Create meal workflow — v0.13.1

Meals has Create Meal entry points at the top, navigation toolbar and empty state. The editor guides name -> multiline ingredients/serving -> reviewed nutrition -> Save Meal, with validation and explicit collection-only behavior. A successful save confirmation opens the exact saved meal to log/plan it, even if dietary filters hide it in the list. Failed writes leave the editor open with its draft and error. No mock meals or inferred ingredient nutrition are added.


## Usability simplification — v0.14.0

New food/meal/plan drafts accept calories directly in the main form; optional macros are collapsed and detailed label/portion editing remains available separately. Existing precise snapshots and legacy unknown nutrition are retained until deliberately edited. Food and meal editors use one persistent primary Save action, explain incomplete requirements and confirm Cancel when applied draft changes exist; swipe dismissal is disabled for those dirty forms. Today removes its tall marketing block and duplicate water destination. Meals keeps one Create action; Profile uses clear labels; account pages are shorter with optional Google sharing details. Initial onboarding can be postponed from its first page without writing measurements or targets. Blank fields do not show red errors before any input. No storage/account schema or nutrition arithmetic changes.

Verification: quick-entry domain regression plus existing configuration/core tests and iOS compilation; actual iPhone small-screen/Dynamic Type/keyboard/VoiceOver and task-completion checks remain pending. Unsaved un-applied label-editor text can still be discarded within that editor; no claim of global draft persistence or full usability testing.
