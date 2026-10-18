# Nourish — iPhone calorie tracker

Native SwiftUI app screens for iOS 15+, including onboarding, daily dashboard, dated food diary and editing, meal discovery and planning, calorie history, weight and water logging, profile, settings, and optional read-only HealthKit integration.

## Build from Windows for TrollStore

TrollStore installs the IPA; it does not compile Swift code. You can edit on Windows and use the included GitHub Actions workflow to compile on a hosted Mac, without owning a Mac or supplying an Apple signing certificate.

1. Upload this project, including `.github/workflows/build-ipa.yml` and `scripts/`, to your GitHub repository. Keep the workflow on the default branch.
2. Open the repository's **Actions** tab, select **Build TrollStore IPA**, and click **Run workflow**.
3. After a successful run, download the **Nourish-TrollStore-iOS15** artifact. Extract the downloaded ZIP to get `Nourish.ipa`.
4. Transfer the IPA to your iPhone, share/open it in your existing TrollStore installation, and install.
5. Open Nourish, set your calorie target in Profile, and optionally connect Apple Health.

The workflow builds a Release arm64 device app with minimum iOS 15.0, embeds the public HealthKit entitlement using ldid, and packages `Payload/CalorieTracker.app` into an IPA. No Apple account, provisioning profile, private entitlement, root access or sandbox bypass is requested by this build. GitHub-hosted runner availability and usage limits depend on your account.

An iOS 15 minimum does not guarantee TrollStore support for every later iOS release. Check your exact OS version/device against the [official TrollStore project](https://github.com/opa334/TrollStore). Apple Health permission is still required, and HealthKit behavior under TrollStore must be verified on your actual phone.

## Optional local Mac build

Install Xcode, XcodeGen and ldid (`brew install xcodegen ldid`), then run `bash scripts/build-trollstore.sh`. Output: `dist/Nourish.ipa`. For ordinary Xcode development, run `xcodegen generate`, open the generated project, and configure your own signing team.

## Behavior and limits

- The 2,000 calorie default is an editable placeholder. Height and weight are stored/imported but do not calculate a calorie prescription. Goal is a stored preference. Personalized energy estimation and age-specific planning are future work.
- Meal calories are illustrative portion estimates, not a nutrition database; allergies and medical diets are not evaluated.
- Fitness activity is accessed through the shared HealthKit store, not by opening the Fitness app. Active calories are displayed separately to avoid automatically adding exercise calories to the food budget.
- Missing Health values are displayed as unavailable: HealthKit does not reveal whether read permission was denied. The permission sheet completing does not prove access was granted.
- No food logs are imported from or exported to Health, avoiding duplicate counting. Refresh is manual and on foreground when the saved refresh preference is enabled. No background sync.
- Local JSON is written atomically with complete file protection. No network calls or account. Device backups follow OS settings. There is no automatic cloud sync. Backup & restore exports/imports versioned JSON through Files. Restore previews the file and preserves the previous bytes locally before replacing them. Existing diary files are migrated by treating new collections and schema version as optional. If loading fails, a dedicated recovery screen blocks editing and offers retry, original-file export, backup restore, and an archive-before-reset option.

## Verification

This project was authored on Windows; Xcode/SwiftUI and iPhone execution are unavailable here. Previous cloud builds have passed and the user confirmed IPA launch on an iPhone. New builds run the storage test suite before compiling the app. Backup dialogs, recovery interactions, UI layout and HealthKit behavior still require on-device verification before release.

Device checklist:
- Run the IPA workflow; verify the resulting app installs and launches through TrollStore on iOS 15.
- Accept/deny Health permissions on-device and verify imports work with the embedded HealthKit entitlement.
- Log a food, cancel an entry, reject invalid calories, delete an entry, and restart to confirm persistence.
- Confirm the diary rolls over at local midnight and older foods do not affect today's total.
- Change target and vegetarian preference; verify balance and meal filtering.
- Test Health access allowed, partially allowed, denied, no records, and unavailable; confirm missing data never appears as a fabricated zero.
- Test independent height/weight availability, foreground refresh, large Dynamic Type and VoiceOver.

Apple documentation: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data

## Screen map

- Welcome setup: introduction → measurements and goal → preferences → dashboard. Reopen from Settings without deleting your diary.
- Today: calorie balance, quick food logging, activity summary, water shortcut, and today's meal plan.
- Diary: choose a past/current day, browse meal groups, open food details, edit an entry, or delete it.
- Log food: name, calories, meal category and date/time; shared by quick logging and editing.
- Meals: search the built-in ideas, filter by preference or remaining calories, and open meal details.
- Meal details: choose servings, log now, or add to a future plan.
- Meal planner: date navigation, planned energy, remove plans or mark past/current meals as eaten.
- Progress: seven days of logged calories and dated weight history, with a weight entry form.
- Water: quick-add amounts and remove today's drink entries.
- You: personal measurements and links to goals, preferences, Health, settings and help.
- Goals: direction and manual calorie target.
- Food preferences: balanced or vegetarian meal filtering.
- Apple Health: optional connection, refresh preference, activity and independent measurement imports.
- Settings: working system/light/dark appearance control and welcome setup replay.
- Privacy & storage: local data and permissions explanation.
- Help & about: usage, calorie estimates, planning behavior and Health troubleshooting.

All screen actions use local state or HealthKit; no server-backed placeholder buttons are included. Barcode scanning, food photo analysis, automatic diet prescriptions, account login and cloud sync are outside this version.

Additional device checks for the screen build:
- Complete and replay onboarding; confirm entered profile and diary persist.
- Create a past-day meal, edit it and change its category; verify both date totals.
- Plan a meal, mark it eaten once and confirm it is removed from the plan and counted once in the diary.
- Confirm future plans cannot be marked eaten.
- Add/delete water and dated weights; an older weight should not replace the latest profile weight.
- Confirm existing pre-screen-build diary JSON loads without losing entries.
- Switch light/dark/system appearance, relaunch, and test all pages at large text sizes.

## Adaptive interface by iOS version

One IPA keeps the same features and stored diary across versions:

| Device OS | Interface |
| --- | --- |
| iOS 15 | Classic stack navigation, native tabs and sheets, 20-point card corners. |
| iOS 16–18 | NavigationStack, large entry sheets with drag handles, 24-point cards. On 16.4+, sheets use rounded corners and short pages only bounce when needed. |
| iOS 26+ | Native Liquid Glass tabs/toolbars via the Xcode 26 SDK, scroll-minimizing tabs, system sheet styling and 28-point cards. Reduce Motion disables tab minimization. |

Settings shows the active interface generation automatically. Individual OS releases render their own native controls; the app does not force a separate theme for every point release. Content cards remain solid for readability. Light/dark/system preferences work in every generation.

The cloud workflow explicitly selects Xcode 26.0.1 while retaining the iOS 15 deployment target. For full local iOS 26 styling, use Xcode 26+. Older compilers omit tab minimization via a compiler guard. OS availability checks protect every newer runtime API.

TrollStore compatibility is separate from UI compatibility: do not update your phone merely to get newer styling. Use a supported installation method for its actual OS. No iOS 26 TrollStore support is claimed.

Verification: cloud device compilation is required; visually test navigation push/back, all entry sheets, keyboard dismissal, tab scrolling, Reduce Motion and both color schemes on each OS generation available to you.

## Critical data-protection pages (0.2.0)

- You → Settings → Backup & restore: export your journal to Files, choose and validate a JSON backup, inspect entry counts, and confirm replacement. A local recovery copy is written before replacement; export the previous file from the same page.
- Storage recovery appears automatically instead of editable screens when the diary cannot load. Retry, export original bytes, restore a known backup, or confirm archive-and-reset. A failed archive prevents replacement/reset.
- Onboarding, personal details, goals and weight entry now keep draft input and explicitly validate/save. Food and weight forms close only after storage commits successfully.
- A planned meal is moved into the diary in one transaction, and repeated taps after success cannot create a second entry.
- All legacy computed model bindings now commit candidate snapshots to disk before publishing changed state. Data is versioned and validated; duplicate identifiers and unsupported backup versions are rejected.
- Backups contain personal information and are not app-encrypted. App appearance and Health permissions are not included. Maximum supported JSON file size is 10 MB and maximum combined entry count is 100,000. Files from older app versions are accepted if valid. There is no merge function.
- Storage transactions are serialized on the main actor and perform synchronous local file writes in this iteration. Moving large-file encoding/I/O off the main thread, shared day context and complete measurement-source reconciliation remain follow-up work.

Tests on macOS: `swift test`. The package isolates Models.swift and Diary.swift from SwiftUI and HealthKit. CI runs tests for old-file migration, invalid backup rejection, failed saves, atomic/idempotent meal transfer, corrupt-file preservation, backup round trip, failed restore, future-plan rejection and backdated weights.

Device acceptance: export/restore a test journal; cancel import/confirmation; try a malformed backup; check IDs/totals after relaunch; test numeric fields and keyboard Done on iOS 15 and modern iOS. Keep a personal backup before testing destructive restore/reset flows.

## Detailed personal pages (0.3.0)

The three links under **You → Make it personal** now open dedicated card-based detail pages:

- Personal details: optional name/age, editable measurements, optional activity description, available Health measurements copied into drafts, and a dated-weight logging sheet. Age and activity do not generate a calorie prescription.
- Goals & daily target: descriptive goal selection, manual calorie entry, live preview against today's diary, optional weight milestone and a personal note. Goal changes do not calculate a deficit or deadline.
- Food preferences: balanced/vegetarian selection, up to 20 ingredient-word exclusions and a live matching-meal preview. Saving applies the filters to Meals. Exclusions match text in names/descriptions and are not verified allergy checks. Logged/planned meals are preserved.

All three pages use explicit Save actions. Old diaries/backups continue to decode because new profile fields are optional; new fields are included in exported backups. Unit tests cover expanded-profile persistence, validation and meal-filter behavior. Visual/keyboard and file-dialog testing on actual phones remains required.
