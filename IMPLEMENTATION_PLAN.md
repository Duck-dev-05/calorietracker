# Nourish Calorie Tracker — Implementation Plan

Reviewed: 20 October 2026. Implementation baseline: **0.13.0, build 20** (Phase 1 nutrition work below); latest prior verified application build: `4afb8e2`, v0.12.0.

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

**Current authentication:** production uses `DeviceAccountProvider`, combining device-local email/password accounts and the configured Google SDK provider. Local registration immediately signs in; local login uses stored password verifiers. Google uses the supplied real iOS OAuth client ID. These flows are implemented and compile; successful real-device operation is not established by CI.

**Important current limits:** local accounts do not verify email ownership, provide password recovery, synchronize between devices or restore a session after relaunch. Their sessions last up to 12 hours while the process remains active. Google supports SDK restoration/refresh. All authenticated accounts open the same on-device journal. Signing in with Google is a separate login method, **not recovery or linking of an existing local identity**. Do not claim account isolation or email recovery.

## 2. Completed and partial implementation audit

| Area | Status | What is implemented | What remains |
| --- | --- | --- | --- |
| Public launch | Implemented | Branded Home, tab bar and optional sign-in/register links; no forced Login at launch | Device navigation checks |
| Authentication screens | Implemented; device verification pending | Local name/email/password registration and login, Google sign-in, validation, password visibility, password help and account security | Actual provider/storage tests, device QA, password change/recovery policy and account deletion |
| Session access | Partial | Google SDK Keychain restore/refresh/sign-out; local 12-hour memory session; expiry guards, hidden snapshots and navigation reset | Device lifecycle tests, explicit local remember-me decision, provider revocation/unlink behavior |
| Data ownership | Partial | Legacy owner metadata is preserved; edits/imports cannot silently change that metadata | Shared diary is disclosed in Login/Register; decide whether to retain it or add isolated stores and reviewed legacy adoption before claiming private accounts |
| Profile | Implemented | Authenticated name/email/initials/provider, separate personal details/goals/preferences pages, optional measurements and manual calorie target | Account edit/change-password/deletion, formula-specific inputs, estimates and target history |
| Food diary | Partial | Dated entries, categories, detail/edit/delete, optional macros and nutrition snapshots | Saved-food picker, custom portion editor and daily macro aggregation |
| Nutrition arithmetic | Implemented foundation | Finite/range checks, compatible mass/volume conversions, unknown-versus-zero macros and boundary rounding | Full reference-serving UI, edit precision regression and explicit zero-energy-food policy |
| Saved meals | Partial | CRUD, search, vegetarian/exclusion filters, per-serving calories/macros and quarter-serving logging/planning | Arbitrary quantities, structured ingredients/source metadata, favorites and recent selection |
| Planning | Partial | Create/edit/reschedule/copy/delete, snapshot-preserving consumption and idempotent plan transfer | Full portion/macro editing, optional week view |
| Water and weight | Implemented | Custom dated records, edit/delete, weight source/time and current-weight reconciliation | Longer trends, display units and broader device verification |
| HealthKit | Partial | Steps, active energy, height and weight; independent reads, freshness, retry and permission/refresh separation | Workout queries, device checks, optional background updates and a defined activity budget policy |
| Storage | Implemented safeguards; partial tooling | Schema 3, legacy decoding, atomic validated writes, migration archives, stale-file checks, backup preview and recovery | Async serialized operations, archive browser/retention and expanded schema fixtures |
| UI and brand | Implemented shared refresh | Teal/mint palette, dark variants, shared cards/buttons, Today quick actions, compact meal cards, seven-day Progress and refreshed auth/Profile layouts; logo/icon assets | Small-screen/accessibility/iOS-version visual QA and remaining feature pages |
| Build | Implemented | CI domain tests, iOS 15 compile, IPA packaging and checks for AppIcon metadata/Assets.car | Recorded install/update and icon checks on supported devices |
| BMR/TDEE and macro targets | Not started | Manual calorie target remains available | Calculator, documented method, effective dates and reviewed target UI |
| Recommendations | Not started | Saved-meal search/filtering only; this is not a ranked recommendation engine | Eligibility, scoring, portion selection, explanations and review pages |
| USDA / AI / cloud sync | Not started | No production integration found | Separate adapters, configuration, privacy, failure handling and evaluation |

### Verified baseline

- [Successful application build and IPA](https://github.com/Duck-dev-05/calorietracker/actions/runs/39233214163) corresponds to `4afb8e2`.
- Latest CI configuration tests, Swift core tests and iOS IPA compile/package/upload passed. Core account tests use provider fixtures; `DeviceAccountProvider.swift` is excluded from the core test target, so its real PBKDF2/Keychain database behavior is not covered by those tests.
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

- [x] Shared Nutrition & Portion editor accepts serving/per-100 g/per-100 mL or custom reference amount/unit, label/source and optional macros, with a computed preview and explicit Apply. Used by food, saved meals and plans.
- [x] Support arbitrary positive quantities within calculation limits; meal details accepts decimal servings. Only mass-to-mass and volume-to-volume conversion is supported. Explicit serving weights/density bridges remain deferred; none are guessed.
- [x] `NutritionDraft` preserves exact stored values for untouched fields even when display formatting rounds them; regression covers changing one macro, reference precision and provenance.
- [x] Removed automatic macro clearing. Nutrition editor keeps fields independent and asks the user to review the common reference; Cancel discards editor changes and Apply updates only the parent draft until Save.
- [x] Explicit current policy: reject entries/portions rounding below 1 kcal with an explanation; never coerce them to one. Zero-energy food support remains deferred pending a compatible validation/schema decision.
- [ ] Extend the source string into attributed source metadata when integrating external foods: external ID, basis, retrieval/version information and ingredient provenance.
- [ ] Add structured ingredients/dietary metadata and recipe yield aggregation when those features are built. Substring exclusions are not verified allergy protection.
- [ ] Add dated target records, manual/estimated mode, macro allocation and calculation method/version.
- [ ] Implement and research `NutritionCalculator` for supported BMR/TDEE inputs, valid ranges, applicability and explicit review before Apply.
- [ ] Define activity accounting before enabling dynamic targets. Do not add workouts again when represented in active energy; keep stale/mismatched-day activity out of adjustments.
- [ ] Keep historical targets unknown when no historical record exists; do not backfill current values as facts.
- [ ] Move expensive persistence/import work to a serialized async boundary without weakening atomic writes or failure recovery.
- [x] Added legacy/nil/schema 1/2/3 round-trip coverage for IDs, dates, owner, unknown nutrition and absent collections; existing tests reject future schemas. More production-file fixtures remain useful.

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
| Login / Register / Password help | Implemented; device verification pending | Validate local/Google flows on device; password help accurately states local recovery is unavailable |
| Account & security | Partial | Add local password change/account deletion; distinguish Google versus local session help and shared-journal behavior |
| Personal details / Goals / Preferences | Implemented manual editors | Formula inputs, target history and estimates; keep existing pages |
| Choose food | Not started | Search actual saved foods/recent items and preserve selected day/category |
| Portion editor | Implemented foundation | Shared reference/portion editor and arbitrary servings; device usability checks and any explicit serving-weight bridge remain |
| Saved-meal nutrition editor | Partial | Reference basis/unit and source editor implemented; structured external provenance/ingredients remain |
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

UI checks still needed: small/large iPhones, Dynamic Type, VoiceOver labels/order, light/dark/system, contrast, Reduce Motion/Transparency, long names, keyboard dismissal, sheet scrolling, unsaved drafts and repeated saves. The v0.12.0 shared UI refresh is implemented, not proof these checks passed. Keep the completed redesign; prioritize layout fixes found by QA over another broad visual rewrite.

## 7. Phase 4 — Connected services and release

**Status: Build/branding implemented; external integrations and device release validation pending.**

### 7.1 Authentication — finish reliability and lifecycle

Already implemented:

- [x] Device-local registration/login and Google sign-in in production, with public Home at launch.
- [x] Local records in the private device-only Keychain: stable ID, normalized email, name, random salt, PBKDF2-HMAC-SHA256 verifier (600,000 iterations), persisted failed-attempt lockout.
- [x] No persisted plaintext passwords; hashing runs off the main thread; database write succeeds before authentication is returned.
- [x] Five failed attempts temporarily lock a local account for 15 minutes.
- [x] Google client ID/callback configuration, SDK restoration/refresh/sign-out, scoped TrollStore Keychain entitlements and build validation.
- [x] Both methods supply Profile name/email/provider, without overwriting diary measurements or targets.
- [x] Password help states local recovery is unavailable; Google recovery link is separate.

Remaining:

- [ ] Extract injectable account repository, credential derivation and clock boundaries so real local-account behavior can be tested without production Keychain access. Do not treat mock-provider tests as database tests.
- [ ] Test register -> logout -> login, duplicate normalized email, wrong password, fifth failure, lockout persistence/expiry, corrupt records, denied Keychain, failed writes, Unicode passwords and cancellation during hashing.
- [ ] Record phone checks for local relaunch login, Google consent/callback, SDK restoration/refresh, logout/expiry, account switching and update-in-place data preservation.
- [ ] Keep local sessions memory-only unless a deliberate remember-me design is implemented. Never persist a bare authenticated flag or derive a session from unverified profile data.
- [ ] Decide shared journal versus per-account storage. Isolation requires separate files, validated account IDs and explicit legacy-journal adoption; never silently copy or delete existing data.
- [ ] Build Change password using the current password, verifier replacement and recoverable write failure; require recent authentication for sensitive account actions.
- [ ] Define local recovery before adding a reset flow. A recovery code or an actual verified backend is a separate design; Google login must not silently link by matching email.
- [ ] Build Delete local account with explicit explanation that account deletion and shared-journal deletion are separate. Do not delete other accounts or the shared journal automatically.
- [ ] Clarify Google sign-out versus revocation/disconnect, and provide deliberate disconnect behavior if added.
- [ ] Update Account & security, Config/README.md and older README sections that still describe Google-only/unconfigured authentication; remove obsolete reset claims.
- [ ] Define and test account-record format migration/backup limitations before changing the stored record layout. Journal exports intentionally contain no credential records.

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
| P0 Critical | A1 | Validate actual local/Google authentication and failure behavior | Both implemented; add real credential/repository tests and physical-device evidence |
| P0 Critical | A2 | Confirm session/account-switching behavior and journal ownership policy | Shared journal is disclosed; isolation/linking/recovery are not implemented; no roles |
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
| P1 High | H9 | Local change-password, account deletion and accurate account/help documentation | Current-password verification; preserve shared diary and unrelated accounts; recovery requires a separate design |
| P2 Medium | M1 | Daily summary, target-history browsing and longer trends | Effective-dated targets; current weekly progress uses the current target |
| P2 Medium | M2 | Recovery archive browser/retention | Existing archive/export/recovery behavior remains available after sign-in |
| P2 Medium | M3 | Async serialized persistence and large-import responsiveness | Keep commit ordering/failure guarantees; promote demonstrated correctness failures to P0 |
| P2 Medium | M4 | Workout history/query and optional background delivery | Build only with a defined use case and tested energy policy |
| P2 Medium | M5 | USDA integration | H1–H2 and C6 |
| P2 Medium | M6 | Optional AI pilot/settings/secured adapter | H5–H6 and C6 |
| P2 Medium | M8 | Structured ingredients and recipe yield calculations | Stable serving model and traceable source data |
| P3 Low | L1 | Favorites and richer recent-food shortcuts | Reliable Choose food flow |
| P3 Low | L2 | Display-unit preferences | Tested canonical unit conversions |
| P3 Low | L3 | Optional food/water reminders and notification preferences | Stable daily flows and explicit opt-in |
| P3 Low | L4 | Week planner and extra trend filters | Existing planner/history correctness |
| P3 Low | L5 | Additional donut styling/chart interaction | Accurate accessible macro values first; guarded iOS APIs |
| P3 Low | L6 | AI history, broader summaries and natural-language convenience | Evaluated pilot, retention policy and reviewed writes |

## 9. Updated build order

1. **Verify existing accounts and protect data:** actual local-provider tests, TrollStore/device login and update checks, journal ownership decision and accurate account documentation. Authentication is already connected; preserve public Home and signed-out Profile behavior.
2. **Complete account lifecycle:** current-password-protected password change and local-account deletion with clear shared-diary effects. Choose recovery/isolation policy before implementing those extensions.
3. **Close nutrition gaps:** reference-serving editor, arbitrary portion handling, untouched-field precision tests, zero-energy policy and expanded migration fixtures.
4. **Complete logging:** Choose food -> Portion review -> dated/category-aware Save; reuse actual saved meals and preserve snapshots.
5. **Implement targets:** documented calculator/activity policy -> dated targets -> macro allocation -> review/apply UI.
6. **Show honest daily values:** macro aggregation with coverage, dashboard and historical comparisons; avoid treating current targets as historical facts.
7. **Implement local suggestions:** deterministic eligibility/ranking -> list/detail -> reviewed Log/Plan, including planner nutrition editing.
8. **Improve history/recovery:** summaries, archive browser, measured persistence performance and required workout support.
9. **Connect food data:** USDA with provenance, serving/unit mapping and offline behavior.
10. **Add optional AI:** consent/settings, secured adapter and evaluated saved-meal pilot; expand only after passing quality/privacy checks.
11. **Add conveniences:** favorites, display units, reminders, week view and chart polish.

Run relevant regression/compile checks and device validation throughout, not only at the end. Do not restart the completed logo, basic login UI, dated weight/water pages, plan CRUD or snapshot foundation as if they were unimplemented.

## 10. Source evidence and boundaries

| Evidence | Main files |
| --- | --- |
| Public launch and personal routing | `ContentView.swift`, `AccessViews.swift`, `ProfileViews.swift` |
| Authentication contract and session gate | `AccountState.swift`, `DeviceAccountProvider.swift`, `GoogleAccountProvider.swift`, `GoogleConfiguration.swift`, `AccountViews.swift`, `CalorieTrackerApp.swift` |
| Actual persisted models and schema | `Models.swift`, `Diary.swift` |
| Portion calculations/snapshots and editor limits | `Nutrition.swift`, `NutritionViews.swift`, `MealAndProgressViews.swift` |
| Profile/plan/measurement editing | `PersonalizationViews.swift`, `CriticalViews.swift` |
| Health states and adapter | `HealthState.swift`, `HealthService.swift` |
| Backup/recovery | `BackupViews.swift`, `Diary.swift` |
| UI/brand/iOS adaptations | `DesignSystem.swift`, `AdaptiveInterface.swift`, `Assets.xcassets/`, `Brand/` |
| Build configuration and packaging | `project.yml`, `.github/workflows/build-ipa.yml`, `scripts/build-trollstore.sh` |
| Domain regression coverage | `Tests/DiaryCoreTests/` |

This audit is documentation only. It updates implemented/remaining status against current code; it does not add features, rerun the IPA build or establish new device test results. Latest application build evidence is linked above.

Explicitly outside the initial scope: subscriptions, social feeds, administrator roles, photo-based nutrition estimates, barcode scanning, cloud diary sync and dietary writes to Health. Revisit these only as separately agreed features.

## 11. Reference documentation

- [Apple: HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Apple: Swift Charts pie/donut support](https://developer.apple.com/videos/play/wwdc2023/10037/)
- [USDA: FoodData Central API guide](https://fdc.nal.usda.gov/api-guide/)

Research and document the chosen calorie-estimation method before implementing target estimates. These integration references are not validation of an unimplemented nutrition formula.


## 12. Remaining pages in implementation order

Create these pages only after their corresponding models/services and tests are ready. Existing Personal details, Goals, Preferences, login, diary details and history pages should be extended rather than duplicated.

| Order | Page / existing page extension | Priority | Required behavior |
| --- | --- | --- | --- |
| 1 | Account & security improvements | Critical verification / High implementation | Provider-specific details, shared-journal disclosure, session expectations and accurate password help |
| 2 | Change password | High | Verify current local password, validate confirmation, save new verifier atomically; never ask for Google password |
| 3 | Delete local account | High | Recent authentication, clear scope, deliberate confirmation, preserve diary/other accounts unless separately authorized |
| 4 | Reference nutrition editor | High | Real basis/quantity/unit, source, optional macros and preserved precision |
| 5 | Choose food / recent foods | High | Actual saved records, search, chosen date/category and empty state |
| 6 | Portion review | High | Arbitrary supported quantity, computed nutrients, correct unit conversion and explicit Log/Plan |
| 7 | Goals: estimate review and dated macro targets | High | Documented supported inputs/method, manual alternative, effective date and explicit Apply |
| 8 | Today: macro summary | High | Known totals plus coverage/missing states; no invented zero values |
| 9 | What should I eat? | High | Deterministic ranked real meals and explicit no-target/no-candidate states |
| 10 | Suggestion review | High | Source meal, portion, calculated values, reason, selected day/category and one-time commit |
| 11 | Planner nutrition editing | High | Reuse portion editor and preserve historical snapshots |
| 12 | Daily summary / target history | Medium | Effective historical targets, missing-day explanations and inspectable entries |
| 13 | Recovery archive browser | Medium | Actual files/date/size, validated restore/export, reviewed removal and retention |
| 14 | External food search/detail | Medium | USDA provenance, serving selection, accurate mapping, caching and offline errors |
| 15 | AI settings / consent and reviewed suggestion UI | Medium / later | Opt-in sharing, secured adapter, valid source IDs, app-owned arithmetic, cancellation and review |
| 16 | Favorites, display units, reminders, week planner | Low | Add after reliable core workflows; reminders require opt-in |

### Immediate acceptance checklist

- [ ] Verify local register/sign-out/relogin and Google sign-in on the actual TrollStore phone.
- [ ] Add direct local account database/credential/lockout tests; core mock tests alone are insufficient.
- [ ] Confirm or change the disclosed shared-journal model; test switching identities without data loss.
- [ ] Fix nutrient edit precision before expanding nutrition editing; add a regression for changing one macro while retaining the others exactly.
- [ ] Check v0.12.0 UI on a small iPhone, larger Dynamic Type, dark mode, keyboard and VoiceOver; record device/OS results.
- [ ] Correct outdated setup/privacy/account copy throughout supporting documentation and provider-specific help.

Recommended next implementation slice: account test boundaries + focused lifecycle/UI corrections, then nutrition reference/portion editing. AI/LLM remains a later phase after deterministic recommendations and trusted nutrition data are usable.


## 13. Phase 1 critical nutrition implementation — v0.13.0

Completed: shared Nutrition & Portion page with isolated draft/Cancel/Apply, immutable reference snapshots, arbitrary quantities and decimal meal servings, full precision preservation for untouched fields, no automatic macro deletion, explicit below-1-kcal rejection, legacy metadata-only editing, food/meal/plan integration and expanded regression coverage. No diary schema, bundle ID, account identity or stored-record rewrite is introduced. Save still uses validated atomic transactions; failed saves preserve memory/disk.

Phase 1 is still partial overall: dated calorie/macro targets, researched calculator/review UI, structured source/ingredient metadata, optional serving-weight conversion and serialized asynchronous persistence remain. Dynamic activity budgets stay disabled until dated targets and duplicate-energy policy are implemented. Do not treat this critical nutrition slice as completed BMR/TDEE or recommendation functionality. Physical-device editor/keyboard/Cancel/save-failure checks remain required.


## Create meal workflow — v0.13.1

Meals has Create Meal entry points at the top, navigation toolbar and empty state. The editor guides name -> multiline ingredients/serving -> reviewed nutrition -> Save Meal, with validation and explicit collection-only behavior. A successful save confirmation opens the exact saved meal to log/plan it, even if dietary filters hide it in the list. Failed writes leave the editor open with its draft and error. No mock meals or inferred ingredient nutrition are added.


## Usability simplification — v0.14.0

New food/meal/plan drafts accept calories directly in the main form; optional macros are collapsed and detailed label/portion editing remains available separately. Existing precise snapshots and legacy unknown nutrition are retained until deliberately edited. Food and meal editors use one persistent primary Save action, explain incomplete requirements and confirm Cancel when applied draft changes exist; swipe dismissal is disabled for those dirty forms. Today removes its tall marketing block and duplicate water destination. Meals keeps one Create action; Profile uses clear labels; account pages are shorter with optional Google sharing details. Initial onboarding can be postponed from its first page without writing measurements or targets. Blank fields do not show red errors before any input. No storage/account schema or nutrition arithmetic changes.

Verification: quick-entry domain regression plus existing configuration/core tests and iOS compilation; actual iPhone small-screen/Dynamic Type/keyboard/VoiceOver and task-completion checks remain pending. Unsaved un-applied label-editor text can still be discarded within that editor; no claim of global draft persistence or full usability testing.


## Reviewed Apple Health measurements — v0.15.0

User-approved scope now includes both importing and sharing height/weight. Health → Height/Weight reviews source/date/current profile before import; older weight protection stays in place. Personal-details height editing preserves an intervening import when the draft field was untouched and rejects conflicting edits. Height/weight sharing has its own value/date form and confirmation; it requests write access only for the selected type, checks permission/session/ranges/dates again, and writes only after confirmation. UI reports success only after HealthKit save returns. Deterministic type/date/value sync IDs and fixed sync version make exact retries idempotent in HealthKit. It does not save workouts, active energy, steps, rings or goals, and never deletes other Health records. Sharing does not also change the local profile; local edits/deletions do not remove Health samples.

Includes domain/controller tests for validation, stable retry identity, signed-out/denied/unavailable access, logout during permission request and save failure/retry. Real HealthKit read/write authorization, visible samples, denied/revoked permissions and retries still require testing on the user's TrollStore phone; CI cannot prove device permissions. The import remains a reviewed profile measurement, not a bulk height/weight history sync. This explicitly supersedes previous read-only/no-Health-writes scope statements. Fitness display and Apple's use of measurements remain controlled by iOS.

References: https://developer.apple.com/documentation/healthkit/saving-data-to-healthkit and https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier
