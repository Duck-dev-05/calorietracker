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
