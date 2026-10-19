# Nourish Calorie Tracker — Implementation Plan

Reviewed: 19 October 2026. Current baseline: version 0.6.0, build 7, commit `9da5213`.

This document consolidates the roadmap into four phases. Completed features are listed separately from planned work. It does not claim that nutrition calculations, recommendations, online authentication or AI are implemented.

## 1. Product scope

Build a personal calorie and nutrition tracker for iPhone, with SwiftUI, iOS 15 minimum support, optional Apple Health access and a TrollStore-compatible IPA build workflow. Maintain the five main tabs: Today, Diary, Meals, Progress and You.

Core principles:

- Start with an empty journal. Do not ship mock foods, invented measurements, fake Health readings or simulated conversations as user data.
- Missing calories, macros, measurements and targets remain unknown; they are not automatically zero.
- Require a valid sign-in session to unlock application data and tools. Health access and AI remain optional. No guest bypass.
- Preserve existing records, identifiers and timestamps through schema changes.
- Require review before applying estimated targets, importing replacement data or committing suggested food entries.

## 2. Current implementation

| Area | Implemented | Remaining work |
| --- | --- | --- |
| Profile | Optional name, age, activity, height, weight, goal weight, preferences and exclusions | Formula-specific inputs, units and reviewed target estimates |
| Diary | Dated calorie entries, categories, detail, editing and deletion | Serving definitions, fractional portions, optional macros and immutable nutrition snapshots |
| Saved meals | User-created meals, CRUD, search and preference/exclusion filtering | Structured ingredients, nutrition provenance, portions, favorites and recent selection |
| Planning | Create, edit, reschedule, copy, remove and mark a plan as eaten | Portion/macro integration and optional week view |
| Water and weight | Dated records, custom entries, editing/deletion and weight reconciliation | Longer-range trends and display-unit preferences |
| HealthKit | Steps, active energy, height and weight; independent results, freshness, retry and separate authorization/refresh | Workout history, documented budget policy and device verification |
| Storage | Versioned JSON, atomic writes, validation, backup/import preview and recovery archives | Serialized asynchronous operations, archive browser and retention controls |
| Account pages | Welcome, login, registration, reset-password and guest continuation | A real identity provider, secure sessions and account-data ownership |
| UI and build | Shared design system, adaptive navigation, iOS availability guards and CI IPA packaging | Nutrition/recommendation pages, accessibility/device coverage and release assets |
| Automated checks | Domain tests and successful iOS 15 IPA compilation | Coverage for each new model, migration, calculation and integration |

Current successful build: [GitHub Actions](https://github.com/Duck-dev-05/calorietracker/actions/runs/39192717419).

An earlier IPA was confirmed to launch on the user's iPhone. This does not establish that all workflows, Health permissions or supported iOS layouts have been device-tested.

## 3. Architecture and technology

- **UI:** SwiftUI with MVVM-style observable state using `@StateObject`, `@EnvironmentObject` and `@Published`.
- **Domain layer:** Pure calculation and recommendation services, independent of SwiftUI and HealthKit for testability.
- **Persistence:** Keep the current JSON implementation until a deliberate migration decision. Core Data is compatible with iOS 15, but is not required solely for that compatibility.
- **Repository boundary:** Isolate storage operations so a future Core Data implementation can preserve the same domain behavior.
- **Health:** Reuse the existing provider/monitor boundary; keep permission prompts separate from routine refresh.
- **Recommendations:** Deterministic eligibility and arithmetic first; optional LLM explanations behind a separate service boundary.
- **External services:** Separate clients for food search, identity and AI. Configure only services actually selected and connected.
- **Charts:** Swift Charts for supported systems; `SectorMark` pie/donut on iOS 17+. Provide SwiftUI Shape or progress-bar alternatives on iOS 15–16 and equivalent accessible text.

Suggested modules, extracted as features change: Features/Diary, Features/Meals, Features/Recommendations, Features/Profile, Domain/Nutrition, Services, and Persistence. Avoid an unrelated file-moving rewrite.

## 4. Phase 1 — Nutrition models, persistence and calculations

### 4.1 Data model

Extend existing models rather than creating a second disconnected food catalog.

- `ServingDefinition`: reference quantity, canonical unit, supported conversions and optional gram weight.
- `NutrientValues`: calories and optional protein, carbohydrate and fat; source basis such as per 100 g or per serving.
- `NutritionSource`: manual/API source, external identifier and retrieval/version metadata.
- `FoodEntrySnapshot`: consumed quantity, serving basis and nutrition at logging time. Later food edits must not rewrite history.
- Extend planned meals with the same portion/snapshot semantics.
- Add structured ingredient and dietary metadata; distinguish unknown information from verified information.
- `TargetChange`: effective date, manual/estimated mode, calorie/macro targets, calculation method/version and relevant inputs.
- Store measurement source/time and retain the existing reconciliation behavior.
- Define recipe ingredient aggregation and total yield before introducing recipe recommendations.

Use canonical g, mL, kcal, kg and cm internally. Display-unit conversion must not alter stored nutrition. Define rounding at display boundaries, valid ranges and fractional-serving behavior.

### 4.2 Storage and migration

- Version the schema and migrate every supported prior version without inventing missing macros or serving sizes.
- Preserve IDs, timestamps, nil fields, real saved meals and all journal records.
- Keep backup/export and recovery available before and after migration.
- Move expensive encoding/import operations off the UI thread through serialized transactions; publish state only after a successful commit.
- If adopting Core Data, define entities and relationships, versioned models, staged JSON import, reconciliation, rollback and failure recovery before switching production storage.
- Keep test fixtures in the test target; never seed them into the application database.

### 4.3 Nutrition calculator

Implement a pure `NutritionCalculator` with a documented, sourced BMR method and applicability rules. Collect only inputs required by that method. Support manual targets when inputs are incomplete or the user chooses not to use estimates.

Define the activity policy before implementing dynamic targets:

- **Fixed estimate:** use a documented activity-factor estimate without adding the same activity again.
- **Health-adjusted estimate:** use a clearly defined baseline that excludes the activity component being added, plus eligible Health activity.
- Never add workout energy separately when it is already represented in daily active energy.
- Do not treat activity recorded so far as a complete forecast for the entire day.
- Show the formula, assumptions and available data in a review screen before applying a target.

Calculate macro targets from an explicit user-reviewed allocation. Validate allocation totals and convert energy to grams using documented factors. Preserve over-target amounts separately from the nonnegative remaining allowance.

### 4.4 Completion criteria

Migration and backup round trips preserve existing records. Portion arithmetic, unit conversion, missing nutrition, invalid inputs, rounding, activity accounting and historical targets pass domain tests. Estimates do not silently replace manual targets.

## 5. Phase 2 — HealthKit and recommendation engine

### 5.1 HealthKit integration

- Reuse existing steps, active-energy, height and weight reads.
- Add workout authorization/query support only when the workout feature is implemented.
- Keep independent loading, no-data, unavailable, error and freshness states per metric.
- Do not infer denied read permission from an empty query or claim that a successful authorization request proves read access.
- Document local-day/timezone boundaries and preserve intentionally selected historical dates.
- Refresh on relevant foreground/day changes; add observer/background delivery only after foreground correctness is verified.
- Exclude stale or mismatched-day activity from current budget adjustments.
- Verify multiple data sources and workout accounting on a real phone. Do not write dietary data back to Health in this phase.

### 5.2 Recommendation inputs

Build a `SuggestionContext` from the selected day, effective target, logged nutrition, eligible activity, actual saved foods and explicit preferences. Decide whether planned food reserves budget through a visible policy; do not count it as consumed.

Required states: no target, missing profile inputs, unknown macros, empty collection, no eligible foods, stale Health data and already-exceeded budget.

### 5.3 Filtering and scoring

1. Filter invalid data and explicit dietary/ingredient exclusions before ranking.
2. Generate supported portions within documented bounds.
3. Apply calorie and fat constraints when the required values are known.
4. Rank eligible candidates by closeness to the remaining protein need.
5. Use closeness to the remaining calorie allowance as the next ranking criterion.
6. Define deterministic tie-breaking, tolerance and behavior when no candidate satisfies the constraints.

Unknown fat or protein cannot pass a rule that requires a known value. Text matching alone does not establish allergen safety; show ingredient provenance and uncertainty.

Return source food IDs, selected portions, app-calculated nutrients and a concise reason. Recommendations remain drafts until the user reviews Log or Plan. Repeated taps must not create duplicate entries.

### 5.4 Completion criteria

Tests cover missing versus zero values, fractional portions, exclusions, stable ranking, over-budget/no-match cases, stale Health results, day rollover, activity double counting and one-time commits. Local recommendations work without AI or network access.

## 6. Phase 3 — SwiftUI pages and complete user flows

| Page or improvement | Main behavior | Dependency |
| --- | --- | --- |
| Choose food | Search real saved foods, recent items and manual-entry option; retain selected date/category | Nutrition models |
| Portion editor | Quantity/unit selection, calculated nutrients, date/category and explicit Save | Serving conversion |
| Macro target editor | Validate allocation, preview grams and apply a dated target | Calculator/target history |
| Calorie estimate review | Show inputs, method, assumptions and manual alternative | Calculation policy |
| Dashboard macros | Consumed, target and remaining values with honest unknown states | Nutrition snapshots |
| What should I eat? | Local recommendations for a selected meal/day, filters and useful empty states | Recommendation engine |
| Suggestion detail | Source, portion, nutrient values, reason and editable Log/Plan review | Recommendation drafts |
| Daily summary | Recorded intake and target effective that day; explain incomplete data | Target history |
| Target history | Effective dates and periods with no target | Target records |
| Recovery archives | Real files with metadata, export, validated restore preview and explicit removal | Archive repository |
| AI settings and privacy | Opt-in, sharing scope, service state and disable controls | Phase 4 AI service |

Extend existing profile, planner, Health and history screens rather than rebuilding completed pages. Add portions/macros to planned meals and whole-serving logging flows.

For macro composition charts, explain whether values represent grams or energy contribution. Do not mix the two. Handle zero/unknown totals without drawing a misleading full donut.

Provide loading, error, offline, empty and incomplete-data states. Verify small screens, long names, Dynamic Type, VoiceOver, light/dark modes, keyboard behavior, Reduce Motion/Transparency and unsaved drafts.

**Completion flow:** profile or manual setup -> reviewed target -> food selection -> portion -> save -> updated diary/macros -> recommendation -> reviewed log. It must work without mock data; app access requires a valid sign-in session.

## 7. Phase 4 — Food API, optional AI and release

### 7.1 USDA FoodData Central

- Implement food search, detail and serving selection with source attribution.
- Map nutrient IDs and units explicitly; distinguish per-100g and per-serving data and missing nutrients.
- Preserve source IDs, retrieval metadata and immutable logged snapshots.
- Add caching, cancellation, pagination, throttling, retry and clear offline/error behavior.
- Do not assume complete coverage of local dishes; retain manual food and recipe entry.
- Define API-key handling and quotas. Do not embed a private backend/service credential in the IPA or repository.

### 7.2 AI and LLM assistance

AI is an optional layer after deterministic calculations and local recommendations are stable.

Delivery order:

1. Explain/rank eligible real saved meals using validated IDs and app-calculated nutrition.
2. Turn natural-language logging requests into editable drafts.
3. Summarize actual recorded patterns, clearly describing incomplete logging.
4. Consider ingredient-based ideas only with explicit uncertainty and verified nutrition before logging.

Architecture and controls:

- Introduce a provider-neutral `SuggestionService` and secured backend adapter; no provider/model is selected by this plan.
- Keep provider secrets server-side. Add controlled access, quotas, payload limits, timeouts and cancellation.
- Require opt-in and preview the minimum data-sharing scope. Do not send raw Health history by default.
- Use bounded structured responses with known food IDs, supported portions, explanations and missing-data flags; validate again on the client.
- Keep arithmetic, exclusions, eligibility and persistence outside the model. Model-generated nutrition is not verified nutrition.
- Treat food names, descriptions and retrieved text as untrusted data. The model cannot directly modify storage, Health, accounts or notifications.
- Require user review before any Log, Plan or target change.
- Offer deterministic local matching when online AI is unavailable; do not label local fallback as an AI response.
- Allow disabling AI, cancellation and clearing local history. Explain provider-side retention separately from local deletion.
- Exclude AI conversations from backups by default until the export policy is explicit. Keep sensitive prompts and Health records out of diagnostic logs.
- Evaluate invented nutrients, unknown IDs, prompt injection, invalid output, exclusions, sparse logs, offline failure, duplicates and data-sharing boundaries.
- Measure usefulness, latency and cost before expanding the pilot. On-device LLM support is a separate evaluation, not an assumed iOS 15 capability.

### 7.3 Accounts and privacy

Existing account pages use an unconfigured provider and cannot authenticate users. Before enabling them:

- Select/configure an identity service and implement registration, verification, password reset and error handling.
- Store session secrets in Keychain; implement refresh, expiry, sign-out and account deletion.
- Define per-account data isolation, explicit guest-diary adoption and backup ownership.
- Specify cloud sync separately, including conflicts and deletion propagation; login alone does not provide sync.
- Update privacy disclosures and add integration tests with mandatory sign-in and no guest bypass.

### 7.4 Release validation

- Run domain and migration tests plus iOS 15 IPA compilation for every release.
- Record real-device checks for Health access changes, multiple sources, workout accounting, stale data, foreground/background transitions and timezone/day changes.
- Test install/update through the user's supported TrollStore environment, data preservation, file import/export and recovery.
- Check representative supported iOS versions and accessibility layouts; report untested coverage honestly.
- Add real app icon assets, accurate Bundle version/build and concise release notes.
- Keep the bundle identifier/data container stable. Verify offline use and API failures.

Phase 4 is complete only when the selected integrations and device checks pass. AI and live accounts have separate release gates and must not be presented as working before their services are connected.

## 8. Priority review — Critical to Low

Priority describes impact and dependency, not phase number. Build the required Phase 3 screens alongside their Phase 1/2 services. Testing, privacy, iOS compatibility and data preservation are continuous release gates, not tasks postponed until Phase 4.

### 8.1 Priority definitions

| Level | Meaning | Scheduling rule |
| --- | --- | --- |
| P0 — Critical | Prevents data loss, incorrect nutrition/budget behavior or an incompatible release | Complete before shipping the affected feature |
| P1 — High | Required to complete the core nutrition tracking and local recommendation flow | Build immediately after its P0 prerequisites |
| P2 — Medium | Improves insights, food coverage or optional connected services | Build after the local core flow works; honor feature-specific gates |
| P3 — Low | Convenience or presentation improvements that do not block core use | Schedule after reliability and core usability |

Completed safeguards remain in place. An open verification task is not evidence of a confirmed production defect. Conditional P0 items block their own feature, not unrelated local diary improvements.

### 8.2 P0 — Critical foundations and release gates

| ID | Required work | Phase / section | Dependency | Completion evidence |
| --- | --- | --- | --- | --- |
| C1 | Versioned nutrition/serving schema, immutable diary snapshots and migration/restore protection | Phase 1 / 4.1–4.2 | Current transaction store | Prior-version fixtures retain IDs, dates, calories and unknown values; failed migration leaves recoverable originals |
| C2 | Validated portion/unit arithmetic, unknown-versus-zero handling and rounding | Phase 1 / 4.1–4.3 | C1 model contract | Fractional portions and invalid/missing inputs pass domain tests; no invented gram weights or nutrients |
| C3 | Explicit target/activity policy and effective-dated target records before dynamic budgets | Phase 1 / 4.3; Phase 2 / 5.1 | Target model and documented calculation method | Reproducible calculations; no duplicate workout/active-energy addition; stale/day-mismatched activity excluded; manual targets preserved |
| C4 | Recommendation eligibility, constraint validation and reviewed one-time commits | Phase 2 / 5.2–5.4 | C1–C3 and known nutrient inputs | Tests reject unsupported portions/unknown required nutrients, honor exclusions and prevent duplicate writes |
| C5 | Regression, iOS 15 compatibility, accessibility of essential controls and real-device release checks | Every phase / 7.4 | Each changed feature | Tests and IPA build pass; relevant install/update, data recovery and Health flows checked on device; untested coverage recorded |
| C6 | Secrets, consent and response/session validation before activating online services | Phase 4 / 7.1–7.3 | Selected USDA, AI or identity integration | Credentials handled appropriately, sharing disclosed and validated; account isolation/Keychain required before live authentication |

C3 is required before enabling calculated/dynamic budgets; manual calorie logging can continue without it. C4 is required before releasing recommendations. C6 is a mandatory gate when the corresponding optional service is enabled.

### 8.3 P1 — High: complete the core application

| ID | Page or function | Dependency | Completion evidence |
| --- | --- | --- | --- |
| H1 | Saved-meal nutrition editor with reference serving and optional macros | C1–C2 | User can create real nutrition data without seeded records |
| H2 | Choose food and Portion editor, including manual-entry fallback | H1 and C1–C2 | Date/category retained; preview matches the committed diary snapshot |
| H3 | Macro target editor, target history foundation and calorie-estimate review | C3 | Manual mode works; estimated targets require review; changes have effective dates |
| H4 | Daily nutrition aggregation and dashboard consumed/target/remaining values | H2–H3 | Missing macros remain visibly incomplete; historical dates use applicable targets |
| H5 | Deterministic local recommendation engine with stable ranking and explanations | C4, H1–H4 | Valid candidates or actionable no-result states without AI/network |
| H6 | What should I eat? and Suggestion detail/review pages | H5 | User can inspect portion/source and explicitly Log or Plan once |
| H7 | Portion/macro integration in existing meal details and planner | H2 and snapshot contract | Editing reusable meals does not rewrite consumed history; planning stays distinct from consumption |
| H8 | Foreground/day/timezone and Health budget integration verification | C3 and current Health monitor | Current data refreshes correctly while deliberate historical selections are retained |

Accessible text and simple macro progress indicators are High priority. A decorative donut is not required to complete H4.

### 8.4 P2 — Medium: insights and optional integrations

| ID | Page or function | Dependency / condition | Completion evidence |
| --- | --- | --- | --- |
| M1 | Daily summary, target-history browsing and longer calorie/weight trends | H3–H4 | Incomplete days and unknown historical targets are explained |
| M2 | Recovery archive browser, retention and import details | Existing backup/recovery | Real archives can be exported, previewed and deliberately restored/deleted |
| M3 | Serialized asynchronous persistence and large-import responsiveness | C1 transaction guarantees | Save ordering/failure behavior preserved; measured UI responsiveness improves |
| M4 | Workout history page and query support | Explicit workout product need | Real workout records and sources displayed without double counting; budget correctness itself remains P0 |
| M5 | USDA search/detail, nutrient mapping, caching and offline handling | H1–H2 and C6 | Attributed API foods create valid snapshots; errors do not produce fake results |
| M6 | AI settings/consent, secured adapter and saved-meal suggestion pilot | H5–H6 and C6 | Opt-in structured responses validated; deterministic fallback remains available |
| M7 | Live registration/login/reset, secure sessions and guest-data adoption | Identity provider selected and C6 | Real integration tests, sign-out/deletion and ownership rules pass; journal stays locked while signed out |
| M8 | Recipe ingredient/yield aggregation | Stable serving model and ingredient sources | Recipe portions have traceable calculated nutrition before recommendation eligibility |

If measured storage behavior risks lost/out-of-order writes, promote the relevant M3 correctness fix to P0. Cosmetic responsiveness work stays P2. AI and authentication are optional integrations, not prerequisites for local tracking.

### 8.5 P3 — Low: conveniences and visual enhancements

| ID | Page or function | Prerequisite |
| --- | --- | --- |
| L1 | Favorites and richer recent-food shortcuts | Reliable H1–H2 selection/logging |
| L2 | Display-unit preferences | Tested canonical unit conversions in C2 |
| L3 | Optional meal/water reminders and notification preferences | Stable daily flows and explicit notification opt-in |
| L4 | Week planner view and additional trend filters | Existing planner/history correctness |
| L5 | Macro donut styling and additional chart interaction | H4 with accessible textual values and guarded iOS APIs |
| L6 | AI conversation history, broader summaries and natural-language drafts | Evaluated M6 pilot, retention policy and reviewed-write controls |

App icon assets and basic readable layouts are release requirements under C5; additional visual polish is P3. Subscriptions, social feeds, food-photo estimates, barcode scanning, cloud sync and dietary Health writes remain separately scoped future work rather than promised low-priority deliverables.

### 8.6 Execution order and milestones

| Order | Work package | Priority | Release result |
| --- | --- | --- | --- |
| 1 | C1–C2: nutrition/serving contract, migrations, snapshots and arithmetic tests | Critical | Safe foundation; all existing records preserved |
| 2 | H1–H2: saved-meal nutrition editing, Choose food and Portion editor | High | Accurate manual/saved-food logging end to end |
| 3 | C3 then H3–H4: target policy, effective dates, reviewed estimates and macro dashboard | Critical -> High | Explainable budgets without duplicate activity accounting |
| 4 | C4 then H5–H7: local recommendation rules, review pages and planner integration | Critical -> High | Complete What should I eat? -> review -> Log/Plan flow |
| 5 | H8 and C5 throughout orders 1–4 | High / Critical gate | Relevant Health, regression, iOS and device checks before each release |
| 6 | M1–M4 and M8 according to demonstrated user need | Medium | Better history, recovery, responsiveness, workouts and recipes |
| 7 | M5 with C6 | Medium / Critical gate | Real food-source integration with attribution and offline behavior |
| 8 | M6 and/or M7 with C6, only when services are selected | Medium / Critical gate | Optional AI or real accounts with privacy/security validation |
| 9 | L1–L6 after their prerequisites | Low | Convenience and visual improvements |

**Next implementation task:** C1–C2, followed by H1–H2. Do not start AI, a Core Data rewrite or extra account screens before the nutrition logging foundation is reliable. Keep backups and no-mock-data behavior working; enforce sign-in before access at every milestone.

## 9. References

- [Apple: HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Apple: Pie charts and interactivity in Swift Charts](https://developer.apple.com/videos/play/wwdc2023/10037/)
- [USDA: FoodData Central API guide](https://fdc.nal.usda.gov/api-guide/)

Research the calculation method and its applicability before implementing numerical target estimates. These references support integration planning; they do not validate a specific nutrition formula or imply completed device testing.

## 10. Critical nutrition and data-safety implementation — version 0.7.0

Implemented C1–C2 foundation: schema 2 with legacy decoding; an exact original-file archive before the first migrated write; disk-baseline checks to reject stale-instance overwrites; validated nutrition units/quantities, optional macros and value-type portion snapshots. Existing legacy records retain IDs, dates and calories without invented macros or serving weights.

Manual food and saved-meal editors accept optional macros. Saved-meal details support quarter-serving increments and use the shared calculation path for logging/planning. Logged and planned nutrition stays independent of reusable meals. Plan consumption preserves its snapshot. A calorie edit clears old macros in manual editors; plan calorie edits clear the old snapshot. Metadata-only edits preserve nutrition provenance.

Added regression coverage for migration/archive/write failures, externally changed/deleted files, invalid/nonfinite inputs, unit compatibility, fractional portions, unknown versus zero macros, rounded calorie mismatches and immutable plan/log history. CI and device verification status must be checked separately before release.

Remaining: complete H1–H2 food-picker flow, daily macro aggregation, target history/activity policy, automatic target calculations and recommendation eligibility. No dynamic Health budget or nutrition inferred by AI has been enabled. Existing atomic storage remains synchronous; the external-change check is optimistic concurrency protection, not a cross-process file lock.

## 11. Authentication gate — version 0.8.1 (supersedes 0.8.0 roles)

User clarification: access depends only on whether the user is signed in. Local owner, Member, Viewer, Admin and Unknown roles and their screens have been removed.

- Signed out, invalid session or expired session: show welcome/login/register/reset-password pages. Deny journal reads/edits, Health access and backup/recovery operations.
- Valid session from AccountProvider: unlock the application, including the existing on-device diary. No role selection or role assignment is involved.
- Remove Continue without an account and ignore the former accountChoiceMade preference. A preference cannot unlock the application.
- Signing out invalidates pending sign-in requests, clears the local session and immediately hides journal data without deleting it. Session expiry automatically relocks the app.
- Settings -> Account & security shows session status and Sign out.
- Keep legacy schema/ownership metadata readable to preserve existing data, but do not use it to assign roles. This is one local on-device diary behind authentication, not per-user encrypted storage or multi-account data isolation.

Release limitation: production AccountProvider remains unconfigured. This build intentionally stays locked until a real authentication provider is connected; no fake or local-password login is introduced. Provider session persistence/refresh, Keychain storage and server token revocation must be implemented with that integration. UI and store tests use isolated test-only provider fixtures, never production identities.

Verification: signed-out access denied at both navigation and store boundaries; successful provider login/registration unlocks; expired/invalid sessions reject access; logout preserves file bytes and relocks; existing migration/nutrition tests run with explicitly authenticated test fixtures.
