# Nourish implementation plan

Status: proposed work, based on a source review on 18 October 2026. This document does not mark the work below as implemented.

## Objective and current evidence

Deliver a dependable personal iPhone calorie tracker: enter personal measurements, choose a daily target, log actual servings, see a trustworthy daily balance, explore suitable meals, and optionally use Apple Health activity.

- The user confirmed that an IPA installs and runs on their iPhone.
- The previous adaptive-interface cloud build succeeded: https://github.com/Duck-dev-05/calorietracker/actions/runs/39115610949
- Installation/launch and compilation do not establish that every feature or OS layout has been tested.
- The app contains the primary screens, local JSON persistence, read-only HealthKit queries, and an iOS 15 minimum.
- Calorie targets are manual; meals are five hard-coded illustrative ideas. Personalization, serving-based custom foods, backups, and automated behavior tests are missing.
- Keep the five main tabs: Today, Diary, Meals, Progress, You. Put new secondary screens under these tabs instead of adding more tabs.

## Priority and delivery order

| Milestone | Scope | Release gate |
| --- | --- | --- |
| M1 / P0 | Reliable storage, validation, date handling and honest save feedback | A failed write cannot masquerade as success or corrupt a meal-plan transfer |
| M2 / P1 | Practical daily food logging and a small local food library | A saved food can be logged with an accurate portion without retyping its calories |
| M3 / P1 | Reliable Health status and optional calorie-target estimation | Users can distinguish estimates, manual targets, unavailable data and stale data |
| M4 / P1 | Backup, restore, settings and release validation | Data survives app upgrades and a tested export/import round trip |
| M5 / P2 | Better meal planning, history and progress | History reflects recorded measurements and targets consistently |
| Later / P3 | Optional remote database, barcode scanning and reminders | Add only after the local daily-use flows are verified |

M1 is the prerequisite for every data-writing feature. M2 and M3 can follow independently. M4 needs the versioned schema from M1. M5 should use the serving and target-history models introduced earlier.

## Page-by-page work

| Page or flow | Existing behavior / gap | Planned improvement | Priority |
| --- | --- | --- | --- |
| Welcome / setup | Writes the profile while users are still entering it; default measurements appear as real values | Use a draft, clearly mark defaults, validate on Continue, and commit setup deliberately; keep Health optional | P0 |
| Today dashboard | Ring and activity cards work from local state; limited recent context | Show recent logged meals, last Health update, actionable empty states and one-tap links to log/edit; keep active energy separate | P1 |
| Food diary | Date picker and category groups; basic swipe deletion | Previous/next day controls, Today shortcut, per-meal totals and undo delete; preserve the selected date when adding | P1 |
| Add / edit food | Name and total calories only; form closes after in-memory mutation | Save only after persistence succeeds, show field-level errors, support numeric keyboard dismissal and keep input after errors | P0 |
| Food details | Displays name, calories, category and timestamp | Add serving, unit, source and optional macros once supplied; provide duplicate/re-log action | P1 |
| Food library — new | No reusable custom food collection | Search local custom foods, recent foods and favorites; quick-add with portion selection | P1 |
| Custom food editor — new | No calories-per-serving model | Create/edit a named food with serving amount, unit and calories; optional macros; no network required | P1 |
| Meal inspiration | Searches five estimated examples | Keep clear estimate labels, expand useful local options with documented servings and sources, retain vegetarian filter; never present budget fit as dietary suitability | P2 |
| Meal details | Whole-serving stepper; can log or plan | Fractional servings, ingredient quantities where known, optional preparation notes, consistent energy calculation and successful-save confirmation | P2 |
| Meal planner | Date filtering and mark-as-eaten; transfer uses separate saves | Atomic transfer, duplicate-tap protection and idempotent operation IDs first; then edit portions, move/copy days and create a custom planned meal | P0 / P2 |
| Progress | Seven-day calories and weight list | 7/30-day ranges, dated measurements, missing-day states and simple accessible weight trend; distinguish current-target comparison from historical targets | P2 |
| Weight entry | Logging can update profile; deletion does not reconcile the latest value | Centralize latest-measurement selection; allow edit/delete; consistently handle manual/Health measurements with timestamps and source | P1 |
| Water | Quick-add today and delete | Custom amount, undo deletion, date history; optional user-set goal, without prescribing a universal water target | P2 |
| You / profile | Summary and links exist | Show completeness, distinguish user-entered/imported/default values, and route to missing personal inputs | P1 |
| Personal details | Editable name, height and weight | Draft edits, clear validation, measurement provenance, optional unit switching with one internal canonical representation | P0 / P2 |
| Goals & daily target | Manual target only; goal is a preference | Add manual/estimated modes, required inputs, estimate explanation, preview and explicit Apply; retain manual override and target history | P1 |
| Food preferences | Balanced/vegetarian only | Expand supported preferences only when meal metadata supports them; ingredient exclusions must not claim verified allergen safety | P2 |
| Apple Health | Sequential queries, one status string, no update time | Per-metric loading/error/unavailable/stale state, freshness timestamps, independent queries and separate permission request/refresh functions | P1 |
| Settings | Appearance, setup replay and static units | Add backup/restore entry, deliberate reset flow, actual build information; keep interface generation detection and accessible appearance controls | P1 |
| Backup & restore — new | No portable recovery | Export a versioned JSON file through the share sheet; import with preview, validation, replace confirmation and rollback backup | P1 |
| Storage recovery — new | A load failure blocks saving but has no recovery interface | Persistent read-only error state with retry, recover/export original file and explicit reset after backup; preserve original data | P0 |
| Privacy & storage | Explains current local-only model | Update alongside backup/source changes; provide real data controls and accurate Health permission guidance | P1 |
| Help & about | Basic FAQs exist | Document serving units, target estimate limits, read-only Health access, recovery and current build/version | P2 |

## M1 — reliability implementation

### 1. Transactional data operations

Current issue: published property observers write the entire JSON file after each mutation. Views mutate arrays directly. A save failure sets a message but leaves the in-memory change; forms still dismiss. Moving a plan to the diary writes once when appending food and again when removing the plan.

Implementation:

- Extract domain models from the app entry point into Models/.
- Introduce DiaryStore with explicit operations: add/update/delete food, log water, log weight, transfer planned meal, and update profile.
- Use a candidate snapshot: validate, encode and persist atomically, then publish committed state. Do not report success if disk persistence fails.
- Execute a plan-to-diary transfer as one snapshot and one write. Give the operation an identity so a repeated tap cannot create a second diary entry.
- Introduce a schema version and explicit migration from current JSON. Preserve UUIDs and original timestamps.
- Preserve existing file protection and atomic replacement; make encoding and file I/O avoid blocking typing on the main thread, with serialized writes that cannot complete out of order.
- Keep errors visible in the relevant flow; centralize recovery when loading fails.

Completion checks:

- Inject a failed write; the form remains open with all draft input and no committed entry.
- Inject failure during plan transfer; either both changes commit or neither does.
- Double-tap transfer; exactly one diary entry exists after relaunch.
- Load the current unversioned diary; food, water, weights, plans and IDs survive migration.
- Load malformed JSON; no original file is overwritten and recovery actions are available.

### 2. Validation and input

Current issue: NumericRow clamps the bound value on every update. Intermediate digits can become the lower bound, making normal editing unreliable. Food fields already use drafts, but profile fields do not.

Implementation:

- Use editable string/draft fields for profile and numeric forms; parse and validate on Apply/Save or leaving the field.
- Accept locale-appropriate decimal separators; reject non-finite values and invalid portions.
- Show the accepted range and a readable inline error instead of silently replacing input.
- Treat allowed input ranges as validation boundaries, not nutritional recommendations.
- Provide Done keyboard controls consistently and prevent accidental draft loss where material.

Completion checks: typing, clearing, replacing, pasting, decimal commas/points and cancelling work on iOS 15 and modern iOS. Invalid input cannot be committed.

### 3. Dates and measurement consistency

- Introduce a shared clock/day context refreshed on foreground, local day change and timezone change; the dashboard currently has its own timer while other pages use Date directly.
- Preserve past-date selection when logging and prevent future eaten-food timestamps.
- Timestamp profile weight sources; derive or deliberately select the latest measurement after add/edit/delete/import.
- Define whether historical date grouping follows the current timezone or the original entry day, document the choice and test it.

Completion checks: midnight, foreground after a day away, timezone changes, latest-weight deletion and an older backdated measurement do not produce misleading totals/profile values.

## M2 — faster logging

Proposed model additions:

- CustomFood: stable ID, name, reference amount/unit, calories per reference serving, optional protein/carbohydrate/fat grams, source and modification date.
- FoodEntry: eaten amount/unit plus a nutrition snapshot. Editing a library food must not retroactively change previous diary entries.
- Favorites and recent selections reference library IDs; deleted library foods leave diary snapshots intact.
- Existing Food records migrate as manual total-calorie entries without invented macros or portions.

Completion checks: half/double servings calculate correctly; a favorite logs quickly; edited/deleted library items do not rewrite history; missing macros remain unknown rather than zero.

## M3 — Health and calorie personalization

### Health reliability

- Split requestAccess() from refresh() so foreground refresh does not unnecessarily repeat authorization calls.
- Refresh metrics independently so one query failure does not prevent the remaining metrics from updating.
- Track result time, sample time where applicable, source and per-metric failure state.
- Clear or visibly mark old values on error; never imply yesterday's steps are today's fresh steps.
- Do not infer read authorization from an empty query or successful permission-sheet completion.
- Show imported height/weight timestamps before applying them; use the same measurement consistency rules as manual entries.
- Keep writes to Apple Health outside the first version to avoid new permissions and duplicate food accounting.

### Optional estimated target

- Keep manual mode fully functional and clearly distinguish an estimate from a prescription.
- Add the inputs required by the selected adult energy-estimation method, including age and activity context; the existing optional age field is not currently collected or used.
- Before implementing, select and document an authoritative method, assumptions, supported population and behavior for unsupported/incomplete profiles. Do not invent calorie floors or goal adjustments during UI work.
- Explain each input and allow manual mode when a user does not want to supply it.
- Preview the estimate and its assumptions; only apply it after an explicit user action. Do not silently overwrite a target after a new Health measurement.
- Store target changes with effective dates. Explicitly choose how activity is handled so a general activity factor and tracked exercise are not counted twice.

Completion checks: incomplete profiles never produce a fabricated estimate; known formula examples pass unit tests; applying/restoring manual targets works; historical entries remain unchanged.

## M4 — backup and first usable release

- Export schema-versioned data with timestamps and units. Explain that the exported file contains personal information.
- Validate imported structure, sizes, finite numeric values, identifiers and dates before committing.
- First restore version: preview counts/date range, then replace after confirmation; create a rollback copy first. Merge is deferred until deduplication rules are defined.
- Add app icon assets, readable app version/build and concise release notes.
- Keep the bundle identifier stable so an IPA upgrade preserves the existing app container.
- Correct README verification history: successful cloud builds and user-confirmed launch are established; feature/OS testing remains pending.

Completion checks: export → restore round trip preserves all entries, IDs and dates; invalid import leaves the current diary untouched; upgrading the IPA retains data and preferences.

## UI and platform acceptance checks

Retain the shared design system; finish interaction details rather than creating unrelated visual themes for every OS release.

- iOS 15: classic navigation and native sheets; complete all daily-use paths.
- iOS 16–18: modern stack navigation, back behavior, drag indicators and keyboard dismissal.
- iOS 26+: native system bars and sheet appearance; verify Reduce Motion tab behavior using an installation method available for that OS. No TrollStore support is implied.
- Small iPhone layouts, large accessibility text, light/dark/system appearance, VoiceOver labels and navigation order, contrast, Reduce Motion and Reduce Transparency.
- Long food names, large numbers, empty states, loading, no Health records, partial results, permission restrictions, failures and recovery.
- Extend acceptance checks to every new screen; screenshots from one OS do not prove all versions render correctly.

## Engineering structure and tests

Suggested structure: Models/, Persistence/, Services/, Features/Today, Features/Diary, Features/Meals, Features/Progress, Features/Profile, SharedUI/. Split the current multi-screen source files as features change rather than moving everything in a separate untested rewrite.

Add meaningful automated tests for:

1. Schema migration, encode/decode, failed writes and restoration.
2. Food totals, portion math, date boundaries and missing macro values.
3. Plan transfer atomicity/idempotency and latest-weight selection.
4. Health partial failure and stale-state handling via a mock service.
5. Target estimation once its method and assumptions are selected.

Cloud CI should run domain tests before packaging the IPA. Test UI paths on available simulators and the user's actual iPhone. Current hosted runners may not provide an iOS 15 simulator; report unavailable OS coverage rather than claiming it passed.

## Scope deferred until the basics pass

Accounts, cloud synchronization, subscriptions, social features, automatic food-photo estimates, barcode scanning, background Health observers, Health food export and push notifications. These add dependencies or permissions without fixing the current core reliability gaps.

## Definition of a basic usable release

- Install/update the IPA and retain the diary.
- Finish setup with real values or an explicitly chosen manual target.
- Add/edit/delete food for today and a past day; all totals and saved state remain correct after relaunch.
- Reuse a saved food with a serving size.
- Transfer a planned meal exactly once, without partial saves.
- Read optional Health data with honest freshness and failure states.
- Export and restore the journal safely.
- Navigate all screens with readable text and usable controls on the available supported test devices.
- Publish the tested IPA with its version, changes and the remaining known limitations.

First implementation task: M1 transactional storage and draft validation, before introducing more data-writing pages.

## Implementation update — critical-page iteration

Implemented in source: dedicated backup/restore and storage-recovery screens; preview and confirmation before replacement; preservation of original bytes; archive discovery after relaunch; versioned/validated snapshots; commit-before-publish storage; atomic/idempotent plan transfer; explicit drafts for onboarding, measurements, target and weight entry; save-success-dependent food/weight dismissal. A macOS Swift package and CI test step cover persistence and recovery behavior.

This does not complete all of M1/M4. Background file I/O, a shared clock/day context, full measurement provenance/reconciliation, app icon assets and comprehensive on-device recovery/backup UI testing remain open. M2 food library and M3 personalization/Health refinements are not part of this iteration.
