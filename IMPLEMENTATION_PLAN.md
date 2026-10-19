# Nourish Calorie Tracker — Implementation Plan

Reviewed: 19 October 2026. Application baseline: **0.9.0, build 13**, source commit `da21143`.

This is the consolidated current plan. It replaces the older appended release notes and superseded role/login directions. Status reflects repository code and the latest verified build, not assumed device testing.

## 1. Status definitions and product rules

- **Implemented:** present in application code; does not imply every device workflow has been verified.
- **Partial:** a usable foundation exists, but the listed acceptance requirements remain open.
- **Not started:** no corresponding production implementation was found.
- **Blocked:** requires a service/configuration decision or external integration to become usable.
- **Verification pending:** needs a recorded test or real-device check.

Current behavior to preserve:

1. Launch opens the public Home/Today page and main tabs, not Login.
2. Signed-out Diary, Meals, Progress and Profile open Login instead of personal content. Health, writes, export and recovery operations require a valid session.
3. Valid sign-in unlocks existing onboarding/personal pages. Logout and expiry hide private data and reset personal navigation without deleting the diary.
4. There are **no user roles**. Do not recreate Admin/Member/Viewer roles, role pickers or role-management pages.
5. Keep real user data. No seeded foods, default measurements, fabricated Health results or simulated AI responses.
6. Unknown nutrients stay unknown. Suggestions and target estimates require user review before committing changes.
7. Maintain SwiftUI, iOS 15 minimum support, the bundle identifier and the TrollStore IPA workflow.

**Current usability blocker:** production uses `UnconfiguredAccountProvider`. Public Home works, but real registration/sign-in/reset cannot complete and protected pages remain locked. Tests use isolated provider fixtures; those are not production accounts.

## 2. Completed and partial implementation audit

| Area | Status | What is implemented | What remains |
| --- | --- | --- | --- |
| Public launch | Implemented | Branded Home, tab bar and optional sign-in/register links; no forced Login at launch | Device navigation checks |
| Authentication screens | Implemented UI; blocked integration | Login, registration, reset-password, validation, password visibility and account security screen | Real identity provider, actual email/reset flows and integration tests |
| Session access | Implemented foundation | Session validation/expiry, sign-out, signed-out store guards, hidden private snapshots and navigation reset | Keychain persistence, refresh, remote revocation and connected-provider tests |
| Data ownership | Partial | Legacy owner metadata is preserved; edits/imports cannot silently change that metadata | Decide shared-device diary versus per-account isolation before live authentication; current valid sessions unlock the same on-device journal |
| Profile | Implemented | Personal details, age/activity, optional measurements, goals/preferences and manual calorie target | Formula-specific inputs, estimates and target history |
| Food diary | Partial | Dated entries, categories, detail/edit/delete, optional macros and nutrition snapshots | Saved-food picker, custom portion editor and daily macro aggregation |
| Nutrition arithmetic | Implemented foundation | Finite/range checks, compatible mass/volume conversions, unknown-versus-zero macros and boundary rounding | Full reference-serving UI, edit precision regression and explicit zero-energy-food policy |
| Saved meals | Partial | CRUD, search, vegetarian/exclusion filters, per-serving calories/macros and quarter-serving logging/planning | Arbitrary quantities, structured ingredients/source metadata, favorites and recent selection |
| Planning | Partial | Create/edit/reschedule/copy/delete, snapshot-preserving consumption and idempotent plan transfer | Full portion/macro editing, optional week view |
| Water and weight | Implemented | Custom dated records, edit/delete, weight source/time and current-weight reconciliation | Longer trends, display units and broader device verification |
| HealthKit | Partial | Steps, active energy, height and weight; independent reads, freshness, retry and permission/refresh separation | Workout queries, device checks, optional background updates and a defined activity budget policy |
| Storage | Implemented safeguards; partial tooling | Schema 3, legacy decoding, atomic validated writes, migration archives, stale-file checks, backup preview and recovery | Async serialized operations, archive browser/retention and expanded schema fixtures |
| UI and brand | Implemented shared refresh | Forest/ivory/lime palette, dark variants, shared cards/buttons, responsive grids, branded pages, logo and iPhone icon assets | Small-screen/accessibility/iOS-version visual QA and remaining feature pages |
| Build | Implemented | CI domain tests, iOS 15 compile, IPA packaging and checks for AppIcon metadata/Assets.car | Recorded install/update and icon checks on supported devices |
| BMR/TDEE and macro targets | Not started | Manual calorie target remains available | Calculator, documented method, effective dates and reviewed target UI |
| Recommendations | Not started | Saved-meal search/filtering only; this is not a ranked recommendation engine | Eligibility, scoring, portion selection, explanations and review pages |
| USDA / AI / cloud sync | Not started | No production integration found | Separate adapters, configuration, privacy, failure handling and evaluation |

### Verified baseline

- [Successful application build and IPA](https://github.com/Duck-dev-05/calorietracker/actions/runs/39200760286) corresponds to `da21143`.
- Repository contains **41 test methods** across storage/diary, Health/day handling, nutrition, account validation and session access. The baseline CI test step passed.
- Logo master/source and generation prompt: `Brand/`; compiled icon/mark sources: `CalorieTracker/Assets.xcassets/`.
- An earlier IPA was reported to launch on the user's phone. New UI, connected authentication and every Health/device flow are **not** confirmed by that report or by compilation.

## 3. Architecture to retain

- SwiftUI with observable state (`@StateObject`, `@EnvironmentObject`, `@Published`) and adaptive native navigation/tabs.
- `Diary` transactions validate a candidate and write successfully before publishing it.
- Existing schema 3 JSON storage stays in place. Core Data is optional, not an iOS 15 requirement; any future move needs staged migration, backup and rollback.
- `NutritionSnapshot` and `NutrientValues` provide value-type historical nutrition. Extend these rather than starting a disconnected food catalog.
- `AccountProvider` separates authentication from screens; `AccessPolicy` checks sign-in validity, not roles.
- Health provider/monitor boundaries remain separate from permission prompts and routine refresh.
- Future calculation and recommendation services should be pure/testable. Keep AI and API clients separate from factual arithmetic and persistence.
- Extract feature modules as work changes them; avoid a repository-wide file-moving rewrite solely for architecture.

## 4. Phase 1 — Nutrition, storage and calculation foundation

**Status: Partial. Portion/snapshot safety is implemented; target calculations are not.**

### Already done

- [x] Optional protein/carbohydrate/fat with explicit unknown states.
- [x] Snapshot reference quantity/unit, selected quantity/unit, source string and optional saved-meal ID.
- [x] Compatible kg/g and L/mL conversions; no invented density or serving weight.
- [x] Fractional saved-meal servings and rounded calorie consistency validation.
- [x] Snapshots survive saved-meal changes/deletion, plan transfer and backup round trips.
- [x] Schema upgrade support, exact original archives before migrated writes and failed-save protection.
- [x] Stale instances cannot silently overwrite changed/deleted files.
- [x] Manual entry supports macros; calorie changes explicitly clear previous macro values for re-entry.

### Still required

- [ ] Add a reusable reference-serving editor: per serving/per 100 g/per 100 mL, custom reference amount and explicit unit.
- [ ] Support arbitrary supported quantities, not only quarter-serving increments; only allow serving-to-mass conversion with a real entered/source gram weight.
- [ ] Preserve full precision for untouched nutrient fields when another field is edited. Current drafts format totals into text; add a regression before changing this behavior.
- [ ] Review warnings/confirmation for clearing existing macros during calorie edits; keep draft cancellation non-destructive.
- [ ] Decide how genuine zero-calorie foods and very small portions should be represented. Current diary entry validation requires 1–10,000 rounded kcal; do not silently replace zero with one.
- [ ] Extend the source string into attributed source metadata when integrating external foods: external ID, basis, retrieval/version information and ingredient provenance.
- [ ] Add structured ingredients/dietary metadata and recipe yield aggregation when those features are built. Substring exclusions are not verified allergy protection.
- [ ] Add dated target records, manual/estimated mode, macro allocation and calculation method/version.
- [ ] Implement and research `NutritionCalculator` for supported BMR/TDEE inputs, valid ranges, applicability and explicit review before Apply.
- [ ] Define activity accounting before enabling dynamic targets. Do not add workouts again when represented in active energy; keep stale/mismatched-day activity out of adjustments.
- [ ] Keep historical targets unknown when no historical record exists; do not backfill current values as facts.
- [ ] Move expensive persistence/import work to a serialized async boundary without weakening atomic writes or failure recovery.
- [ ] Expand migration fixtures across supported legacy/schema 1/2/3 shapes and incompatible future schemas; preserve all IDs, dates and nil fields.

Completion: existing records survive migration/restore; portions and edit precision are correct; reviewed targets are reproducible; no unverified automatic activity adjustment ships.

## 5. Phase 2 — HealthKit and deterministic recommendations

**Status: Health reading foundation implemented; recommendation engine not started.**

### Already done

- [x] Read steps, active energy, height and weight independently.
- [x] Separate authorization from refresh and expose per-metric state/retry/freshness.
- [x] Expire stale daily values across time/day/timezone changes.
- [x] Show measurement source/time where available and protect newer profile weights.
- [x] Preserve intentional historical date selection and refresh current-day state.
- [x] Deny protected Health reads while signed out.

### Still required

- [ ] Verify Health permissions, empty/error states, multiple sources and measurement imports on the actual phone.
- [ ] Add workouts only when the history/product flow needs them, with minimum authorization and no duplicate energy accounting.
- [ ] Document historical grouping after travel/timezone changes and test that policy across food, plans, water and Health.
- [ ] Add observer/background updates only after foreground correctness and device behavior are verified.
- [ ] Build `SuggestionContext` from actual saved foods, the selected day's effective target, recorded nutrients and eligible activity.
- [ ] Define whether planned food reserves a budget; never count planned food as already consumed.
- [ ] Filter invalid foods, explicit exclusions and unsupported portions before ranking. Unknown required nutrients cannot pass known-value constraints.
- [ ] Apply calorie/fat constraints, then rank closeness to missing protein and remaining calories with deterministic tie-breaking/tolerances.
- [ ] Handle no target, incomplete macros, stale Health data, empty collection, no candidates and exceeded budget explicitly.
- [ ] Return real source IDs, supported portions, app-calculated nutrients and a reason.
- [ ] Require review before Log/Plan; test repeated actions so the same reviewed draft commits once.

Completion: local recommendations work without AI/network, with stable tested ranking, honest missing data and no invented foods/nutrients.

## 6. Phase 3 — Remaining pages and complete workflows

**Status: Existing journal/profile/Health/history pages and shared UI are implemented; nutrition and suggestion flows remain partial.**

| Page or workflow | Status | Remaining acceptance requirement |
| --- | --- | --- |
| Public Home and protected tabs | Implemented | Check launch, tab changes, sign-out and expiry on device |
| Login / Register / Reset password | UI implemented; service blocked | Connect genuine identity flows and handle verification/recovery errors |
| Account & security | Partial | Secure session lifecycle, deletion/revocation and accurate connected-service disclosure |
| Personal details / Goals / Preferences | Implemented manual editors | Formula inputs, target history and estimates; keep existing pages |
| Choose food | Not started | Search actual saved foods/recent items and preserve selected day/category |
| Portion editor | Partial: meal details stepper exists | Arbitrary quantity/unit, nutrition preview and explicit save for diary/plans |
| Saved-meal nutrition editor | Partial | Reference basis/unit, provenance and structured ingredients |
| Macro target editor | Not started | Validate allocation, preview grams and apply dated targets |
| Calorie estimate review | Not started | Required inputs, method/assumptions, manual alternative and explicit Apply |
| Dashboard macro totals | Not started | Consumed/target/remaining values with incomplete-nutrient coverage clearly shown |
| What should I eat? | Not started | Local ranked candidates, filters, selected meal/day and useful empty states |
| Suggestion review | Not started | Real source, portion, nutrients, reason and editable one-time Log/Plan |
| Planner | Partial | Existing CRUD/copy/consume is done; add full nutrition/portion editing and later optional week view |
| Daily summary and target history | Not started | Use the target effective on that day; explain sparse logging |
| Recovery archive browser | Not started | Real archive list, dates/sizes, export, validated restore and deliberate removal |
| Health / weight / water details | Implemented | Device QA and longer-range insights where useful |
| AI settings / consent | Not started | Build with a selected secured service and explicit sharing scope |

Macro composition must clearly represent grams or energy contribution, never an unexplained mixture. Native `SectorMark` donut/pie needs iOS 17+; provide supported text/progress/Shape alternatives for iOS 15–16. Accessible textual macro values matter before decorative charts.

UI checks still needed: small/large iPhones, Dynamic Type, VoiceOver labels/order, light/dark/system, contrast, Reduce Motion/Transparency, long names, keyboard dismissal, sheet scrolling, unsaved drafts and repeated saves. The latest shared UI refresh is implemented, not proof these checks passed.

## 7. Phase 4 — Connected services and release

**Status: Build/branding implemented; external integrations and device release validation pending.**

### 7.1 Authentication — next release blocker

- [ ] Select/configure an identity provider and its iOS callback/deep-link behavior.
- [ ] Connect real login, registration, email verification and password reset. Never fabricate success when only form validation passed.
- [ ] Implement Keychain-backed session persistence, refresh/expiry, relaunch and offline behavior. The current session is memory-only.
- [ ] Revoke/clear sessions appropriately on sign-out and handle pending/cancelled authentication responses.
- [ ] Decide and explain data ownership **before** live account switching: the present app has one on-device diary that any valid session unlocks. Choose whether to retain that model or implement isolated account stores with reviewed legacy-data adoption.
- [ ] Add account deletion and explain whether local records and remote identity/data are deleted separately.
- [ ] Add provider integration tests for failures, cancellation, invalid sessions, revocation, relaunch and expired credentials.
- [ ] Preserve public Home at launch. Never restore roles or force Login before the user opens personal features.

### 7.2 USDA FoodData Central

- [ ] Search/detail/serving selection with attribution and explicit nutrient-ID/unit mapping.
- [ ] Distinguish per-100g/per-serving data and unknown nutrients; keep immutable logged snapshots.
- [ ] Add external IDs/version metadata, caching, pagination, cancellation, quotas/retry and honest offline errors.
- [ ] Define credential handling; never embed a private backend secret in the IPA or repository.
- [ ] Keep manual foods and traceable recipes for local dishes without source coverage.

### 7.3 Optional AI / LLM

Build after deterministic calculations and recommendations are stable. No provider/model/backend is currently selected.

1. Pilot explanations/suggestions grounded in eligible saved meal IDs and app-calculated nutrients.
2. Add natural-language logging as editable drafts after the pilot passes evaluation.
3. Summarize recorded patterns without treating missing days as fasting or zero intake.
4. Consider ingredient-based ideas later; nutrition must be verified before presenting it as factual logging data.

Required work:

- [ ] Provider-neutral service contract and secured backend adapter; secrets stay server-side.
- [ ] Opt-in settings, provider disclosure and minimum data-sharing scope; no raw Health history by default.
- [ ] Structured response with known IDs, supported portions, missing-data flags and bounded explanations; validate on client and service.
- [ ] Keep arithmetic, exclusions, eligibility and persistence outside the model. Do not accept invented nutrition as verified facts.
- [ ] Treat user text, meal names and retrieved content as untrusted data; the model has no direct journal/Health/account/notification permissions.
- [ ] Controlled access, payload limits, quotas, timeout/cancellation, retry and deterministic offline fallback clearly labeled as local matching.
- [ ] User review for every Log/Plan/target draft; idempotent commits and recoverable save failures.
- [ ] Disable/history controls, clear retention policy and separate local deletion from provider deletion. Exclude conversations from backups until that policy is explicit.
- [ ] Avoid sensitive prompts/Health records in diagnostic logs.
- [ ] Evaluate invalid JSON, unknown IDs, fabricated nutrients, exclusions, prompt injection, sparse logs, service errors, duplicate actions and sharing boundaries.
- [ ] Measure usefulness, latency and cost before expansion. On-device LLMs are a separate later evaluation, not an assumed iOS 15 capability.

### 7.4 Release and device verification

- [x] Shared UI/brand refresh and committed logo/source/prompt.
- [x] Opaque RGB app icon assets and Xcode AppIcon configuration.
- [x] CI tests, iOS 15 compile, IPA upload and icon/catalog packaging checks for the baseline.
- [ ] Install/update latest IPA on the user's supported TrollStore/iOS device and verify data preservation and icon appearance.
- [ ] Record actual OS/device coverage instead of claiming all iOS layouts were tested.
- [ ] Verify connected authentication, Health, file picker/export/import, locked-device behavior and foreground/day/timezone transitions.
- [ ] Exercise disk-full/write failure, corrupt/unsupported files and recovery paths under representative data volumes.
- [ ] Complete accessibility/UI checks and update help/privacy/release notes whenever integrations change data flow.

## 8. Critical-to-Low remaining priorities

Implemented safeguards stay mandatory. Priority is based on impact, not phase numbering. Conditional release gates apply before enabling the affected feature, not as a reason to rebuild completed code.

| Priority | ID | Work still needed | Dependency / completion condition |
| --- | --- | --- | --- |
| P0 Critical | A1 | Connect genuine authentication | Required for protected pages to be usable outside test fixtures |
| P0 Critical | A2 | Secure session lifecycle and explicit on-device/account ownership policy | Complete before live identity/account switching; no role model |
| P0 Critical gate | C1 | Preserve schema/migration/atomic-save protections as models evolve | Foundation implemented; expand fixtures for every new schema |
| P0 Critical gate | C2 | Preserve nutrition accuracy through editing and aggregation | Foundation implemented; verify untouched-field precision and unknown-macro coverage before extending flows |
| P0 Critical gate | C3 | Define activity accounting and dated targets before dynamic budgets | Not started; no duplicate energy or invented historical targets |
| P0 Critical gate | C4 | Validate recommendation eligibility and reviewed one-time commits | Not started; required before recommendation release |
| P0 Critical gate | C5 | Regression, iOS 15 compilation and relevant device checks | CI baseline passes; device/accessibility verification remains open |
| P0 Critical gate | C6 | Secrets, consent and service validation | Required before enabling identity, USDA or online AI as applicable |
| P1 High | H1 | Complete saved-food nutrition/reference-serving editor | Existing macro editor is partial, not missing entirely |
| P1 High | H2 | Choose food and arbitrary Portion editor | Snapshot/calculation foundation exists; connect to diary/date/category |
| P1 High | H3 | Dated calorie/macro targets and estimate review | C3; manual target remains available |
| P1 High | H4 | Daily macro aggregation/dashboard and historical target comparisons | H2–H3; unknown nutrients must not become zero |
| P1 High | H5 | Deterministic recommendation engine | C4 and stable food/target data |
| P1 High | H6 | Suggestion list/detail/review pages | H5; no fabricated candidates |
| P1 High | H7 | Complete planner portion/macro editing | Existing plan CRUD/copy/consumption are already done |
| P1 High | H8 | Health/date integration validation | Existing freshness/day foundation is done; real-device policy checks remain |
| P2 Medium | M1 | Daily summary, target-history browsing and longer trends | Effective-dated targets; current weekly progress uses the current target |
| P2 Medium | M2 | Recovery archive browser/retention | Existing archive/export/recovery behavior remains available after sign-in |
| P2 Medium | M3 | Async serialized persistence and large-import responsiveness | Keep commit ordering/failure guarantees; promote demonstrated correctness failures to P0 |
| P2 Medium | M4 | Workout history/query and optional background delivery | Build only with a defined use case and tested energy policy |
| P2 Medium | M5 | USDA integration | H1–H2 and C6 |
| P2 Medium | M6 | Optional AI pilot/settings/secured adapter | H5–H6 and C6 |
| P2 Medium | M7 | Account deletion and any chosen account data-migration tooling | Basic live authentication/session safety are A1–A2, no longer postponed here |
| P2 Medium | M8 | Structured ingredients and recipe yield calculations | Stable serving model and traceable source data |
| P3 Low | L1 | Favorites and richer recent-food shortcuts | Reliable Choose food flow |
| P3 Low | L2 | Display-unit preferences | Tested canonical unit conversions |
| P3 Low | L3 | Optional food/water reminders and notification preferences | Stable daily flows and explicit opt-in |
| P3 Low | L4 | Week planner and extra trend filters | Existing planner/history correctness |
| P3 Low | L5 | Additional donut styling/chart interaction | Accurate accessible macro values first; guarded iOS APIs |
| P3 Low | L6 | AI history, broader summaries and natural-language convenience | Evaluated pilot, retention policy and reviewed writes |

## 9. Updated build order

1. **Unblock actual use:** select/connect authentication, secure session handling and decide journal ownership. Preserve public Home and Profile login behavior.
2. **Close nutrition gaps:** reference-serving editor, arbitrary portion handling, untouched-field precision tests, zero-energy policy and expanded migration fixtures.
3. **Complete logging:** Choose food -> Portion review -> dated/category-aware Save; reuse actual saved meals and preserve snapshots.
4. **Implement targets:** documented calculator/activity policy -> dated targets -> macro allocation -> review/apply UI.
5. **Show honest daily values:** macro aggregation with coverage, dashboard and historical comparisons; avoid treating current targets as historical facts.
6. **Implement local suggestions:** deterministic eligibility/ranking -> list/detail -> reviewed Log/Plan, including planner nutrition editing.
7. **Improve history/recovery:** summaries, archive browser, measured persistence performance and required workout support.
8. **Connect food data:** USDA with provenance, serving/unit mapping and offline behavior.
9. **Add optional AI:** consent/settings, secured adapter and evaluated saved-meal pilot; expand only after passing quality/privacy checks.
10. **Add conveniences:** favorites, display units, reminders, week view and chart polish.

Run relevant regression/compile checks and device validation throughout, not only at the end. Do not restart the completed logo, basic login UI, dated weight/water pages, plan CRUD or snapshot foundation as if they were unimplemented.

## 10. Source evidence and boundaries

| Evidence | Main files |
| --- | --- |
| Public launch and personal routing | `ContentView.swift`, `AccessViews.swift`, `ProfileViews.swift` |
| Authentication contract and session gate | `AccountState.swift`, `AccountViews.swift`, `CalorieTrackerApp.swift` |
| Actual persisted models and schema | `Models.swift`, `Diary.swift` |
| Portion calculations/snapshots and editor limits | `Nutrition.swift`, `NutritionViews.swift`, `MealAndProgressViews.swift` |
| Profile/plan/measurement editing | `PersonalizationViews.swift`, `CriticalViews.swift` |
| Health states and adapter | `HealthState.swift`, `HealthService.swift` |
| Backup/recovery | `BackupViews.swift`, `Diary.swift` |
| UI/brand/iOS adaptations | `DesignSystem.swift`, `AdaptiveInterface.swift`, `Assets.xcassets/`, `Brand/` |
| Build configuration and packaging | `project.yml`, `.github/workflows/build-ipa.yml`, `scripts/build-trollstore.sh` |
| Domain regression coverage | `Tests/DiaryCoreTests/` |

This update is documentation only. It does not connect authentication, implement recommendations/AI, rerun the application build or establish new device test results. Existing release evidence is linked above.

Explicitly outside the initial scope: subscriptions, social feeds, administrator roles, photo-based nutrition estimates, barcode scanning, cloud diary sync and dietary writes to Health. Revisit these only as separately agreed features.

## 11. Reference documentation

- [Apple: HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Apple: Swift Charts pie/donut support](https://developer.apple.com/videos/play/wwdc2023/10037/)
- [USDA: FoodData Central API guide](https://fdc.nal.usda.gov/api-guide/)

Research and document the chosen calorie-estimation method before implementing target estimates. These integration references are not validation of an unimplemented nutrition formula.


## 12. Google sign-in implementation — version 0.10.0

Provider choice is now Google Sign-In using an iOS OAuth client ID. Added official GoogleSignIn/GoogleSignInSwift 10.0.0 dependencies (iOS 15 minimum), the SDK provider, official button on Login/Register, callback forwarding, non-interactive previous-session restoration, expiry refresh and SDK sign-out. The provider does not collect a Google password or create a separate email/password account. Basic profile/email are used; no journal or Health payload is sent by this adapter.

Added public-client-ID configuration through Config/GoogleSignIn.json or the GOOGLE_IOS_CLIENT_ID GitHub Actions variable. The build generator validates input and derives the callback scheme; no client secret is used. Missing/mismatched configuration cannot open a session. Configuration and provider-boundary tests cover unavailable settings, cancellation, restoration and logout.

**Still blocked for live sign-in:** an actual iOS OAuth client ID for com.personal.CalorieTracker has not been supplied. The checked-in ID is empty, not a fake credential. See Config/README.md for Windows/Cloud setup. Live device/Google consent and Keychain testing remain required, especially on the fake-signed TrollStore IPA. Current SDK credential storage is not proof it works under TrollStore signing.

A1 is implemented at the adapter/UI/configuration level but remains blocked on the real client ID and live validation. A2 is partial: SDK Keychain/restore/refresh/sign-out integration exists, but device persistence, account revocation/deletion and a deliberate shared-diary-versus-isolation decision remain open. Existing accounts use one shared on-device diary; no roles or cloud sync have been introduced. Future backend endpoints must independently validate Google ID tokens.

The phase/status tables above describe the pre-Google 0.9.0 audit baseline. This section records the new implementation and its outstanding activation requirements; do not mark authentication live until they pass.


## 13. Google OAuth client configured — version 0.10.1

The user supplied an iOS OAuth client ID from Google Cloud. It is now saved in Config/GoogleSignIn.json; the generator derives the matching reversed callback scheme. The default build is no longer missing its client ID. IPA packaging verifies that the built Info.plist contains the configured identifier and callback.

The Google Cloud screenshot states that OAuth access is restricted to test users. Add the intended Google account under Google Auth Platform -> Audience -> Test users before the phone test. Actual consent/callback, Keychain behavior on TrollStore, restoration, refresh and logout still require live device verification; configured credentials/build success are not proof of a successful login. No client secret was requested or embedded.

This supersedes the missing-client-ID activation blocker in section 12. A1 now has its configuration as well as its adapter/UI implementation; live verification remains open. A2 ownership/isolation and account lifecycle follow-up remain unchanged.
