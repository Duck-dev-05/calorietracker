# Nourish — next implementation plan

Reviewed: 18 October 2026. Baseline: version 0.4.0, source commit `65e07e5`. This plan replaces the earlier roadmap; it describes future work, not features already implemented.

## Product direction

Build on the existing five tabs — Today, Diary, Meals, Progress and You. Add secondary pages only when a task needs a dedicated screen. Keep iOS 15 support, adaptive system presentation, optional Apple Health access, local-first storage and blank first-use data.

No seeded food catalog, numeric body defaults, invented Health values or automatic calorie target may return. Missing information stays missing. Synthetic test inputs remain restricted to the test target.

## What already exists

| Area | Current implementation | Remaining gap |
| --- | --- | --- |
| Setup | Draft profile; blank/optional measurements, target and preferences | Better review of missing information; avoid implying setup is required to log food |
| Today | Calorie ring, missing-target state, activity/water summaries, today's plans | Recent entries, freshness indicators and shared day rollover |
| Diary | Date selection, meal groups, manual food entry, detail/edit/delete | Saved-meal picker, recent/favorite foods, portion metadata, undo |
| Meals | Empty user-owned collection; create/edit/delete, search, food-style/exclusion filters | Reference serving quantities/units, fractional portions and favorites |
| Meal details | Whole-serving logging and planning; user-provided calories | Portion accuracy, historical snapshots and more direct date/meal choice |
| Planner | Date selection, remove, atomic/idempotent mark-as-eaten | Edit, reschedule, copy, custom plan entry and optional week view |
| Progress | Seven-day calorie totals and weight list | Longer ranges, missing-day states, actual weight trend and consistent measurements |
| Water | Today-only quick additions and deletion | Custom amounts, editing and past-day history |
| Profile | Optional measurements/age/activity, manual target, optional goal weight/note, preference filters | Measurement source/time and historical target records |
| Health | Read height, weight, steps and active energy; manual/foreground refresh | Independent metric states, timestamps, stale/error handling and permission/refresh separation |
| Backup/recovery | Versioned JSON export, import preview, confirmed replacement, original-file archives, retry/export/reset | Archive browser, import detail, retention and off-main-thread work |
| UI/build | Shared design system, docked personal-editor Save, iOS availability wrappers, IPA workflow | Device UI coverage, app icon assets and release details |
| Tests | 13 domain tests and successful baseline IPA build | UI tests, mocked Health failures, date/measurement/portion coverage |

Baseline build: https://github.com/Duck-dev-05/calorietracker/actions/runs/39121250706

The user confirmed an earlier IPA launches on their iPhone. Individual workflows and every supported OS layout are not all device-verified.

## Build order

| Release group | Priority | Outcome | Depends on |
| --- | --- | --- | --- |
| A. Trustworthy daily state | P0 | Correct day, measurement and Health status everywhere | Current transaction store |
| B. Fast and accurate logging | P1 | Choose a real saved item, enter a portion and log once | Serving model, migrations |
| C. Editable planning and history | P1 | Reschedule plans and manage dated body/water records | A and B |
| D. Useful insights and data controls | P2 | Honest trends, target history and recovery archive management | A–C, target-history model |
| E. Optional conveniences | P2/P3 | Opt-in reminders, units and researched target estimates | Stable daily-use flows |
| F. Optional AI / LLM assistance | P1 pilot, then P2 | Explain and suggest from real saved meals; review every proposed action | A/B, consent settings, deterministic calculations and a secured service |

Recommended next task: group A, followed by a saved-meal picker and portion editor. Do not rebuild existing profile or backup pages just to add more screens.

## New pages and sheets to create

| Page / sheet | Entry point | Main functions | Priority |
| --- | --- | --- | --- |
| Choose food | Diary → Add; Today → Log a meal | Search actual saved meals; recent diary entries; manual entry; preserve selected day/category | P1 |
| Portion editor | Choose food; meal details | Reference serving, entered quantity/unit, live calorie calculation, date/category, explicit save | P1 |
| Planned meal editor | Tap a planned row | Change name/portion/category/day, copy to another date, remove or mark eaten when allowed | P1 |
| Weight history & edit | Progress → Weight | Dated list, edit/delete, source labels, latest-value reconciliation | P1 |
| Water entry & history | Water → Add custom; date control | Arbitrary valid mL, timestamp/category-free logging, edit/delete, past dates | P1 |
| Daily summary | Progress → selected day | Logged food by meal, actual totals, target effective that day when known, missing-data explanation | P2 |
| Target history | Goals → Target history | Effective dates, manual-target changes and periods with no target | P2 |
| Recovery archives | Settings → Backup & restore → Previous files | List real archives, dates/sizes, export, validated restore preview, explicit removal | P2 |
| Health metric detail | Tap a metric on Health/Today | Actual result freshness, sample date where available, source where available, error/retry and explanation | P1; may be a sheet rather than a full page |
| Notification preferences | Settings → Reminders | Optional local food/water reminders, schedule and authorization state | P2; build after daily flows |
| Calorie estimate review | Goals → Optional estimated target | Required inputs, method/source/assumptions, supported-profile checks, preview and explicit Apply | P2; research and calculation tests required first |

Do not add login, subscription, social, administrator or cloud-account pages to the current local personal app.

## AI pages to create

| Page / sheet | Entry point | Functions | Priority |
| --- | --- | --- | --- |
| What can I eat? | Meals → Ask for suggestions; Today shortcut | Optional request text, selected meal time, relevant preferences, actual available meal collection and an optional real remaining budget | P1 pilot |
| Suggestion review | Open an AI suggestion | Show saved-meal source, portion, app-calculated calories when known, reason for the suggestion, and editable Log / Plan drafts | P1 pilot |
| AI settings & privacy | You → Settings → AI assistance | Opt-in, provider/service disclosure, data-sharing scope, usage state, history controls and disable action | P1 prerequisite |
| AI conversation/history | Assistant → History | Reopen actual saved suggestions, clear conversations and report an unhelpful result; never prefill fake chats | P2 |

## A — daily-state correctness

### A1. Health freshness and partial failures

Observed: `HealthService.connect()` requests authorization and then reads four metrics sequentially. One failure stops later queries. Old values can remain visible, and no fetch/sample timestamps are shown.

Implement:

- Separate requestAccess() from refresh(); foreground refresh must not run the permission-request flow unnecessarily.
- Store a metric result with value, loading/error state, fetchedAt and sample date/source when actually available.
- Refresh metrics independently. A failed weight query must not suppress available steps or height.
- On failure, either clear the value or label its last known value as stale. Never show stale daily totals as current-day data.
- Distinguish no result, unavailable device and query error. Do not claim to detect denied read access from empty results.
- Display freshness on Today/Health and add a focused retry/detail sheet.
- Keep dietary writes and imported food calories outside this release to avoid duplicate counting.

Done when: simulated partial failures, empty queries, day changes and relaunches show honest states; manual refresh and available measurement imports work on the user's iPhone.

### A2. Shared day and timezone context

Observed: Today has a minute timer; other screens call Date directly or retain a date selected when the screen opened. Health activity can belong to an earlier day until refreshed.

Implement:

- Introduce a shared clock/day context injected into date-sensitive features.
- Refresh on foreground, local day changes and timezone changes.
- Follow Today automatically only when the user was viewing Today; preserve an intentionally selected historical date.
- Define how historical entries group after travel/timezone changes. Document the policy before migration changes.
- Recompute calories, water, planned meals, progress ranges and daily Health status together.

Done when: leaving the app open over midnight and reopening after a day away produce the correct day without moving explicitly selected past-day entries.

### A3. Weight consistency

Observed: logging a new dated weight can update the profile, but removing a weight does not reconcile it. Profile edits and Health imports have no measurement timestamp/source.

Implement:

- Introduce measurement provenance: user profile edit, dated manual entry or Health import, with a real timestamp.
- Define the chosen/current measurement explicitly; do not simply pick the largest array position.
- Route add/edit/delete/import through store operations that update history and profile in one transaction where appropriate.
- Deleting the latest measurement must choose the next eligible measurement or leave current weight unset; never manufacture a replacement.
- Protect a newer explicit profile measurement from an older imported or backdated value.

Done when: editing/deleting the latest entry, logging a past measurement and importing older Health data all preserve the documented current-weight rule.

### A4. Storage responsiveness and failure feedback

Observed: commit-before-publish and atomic writes exist. Encoding and file writes still run synchronously on the main actor, and some views mutate computed collection setters directly.

Implement:

- Keep the successful transaction semantics; serialize encoding/writes off the main thread.
- Represent pending saves explicitly, prevent duplicate submissions and publish only committed state.
- Move remaining array mutations behind named store operations with returned results.
- Treat locked-device protection errors as retryable, preserving drafts and originals.
- Keep archive creation and replacement ordered; a failed archive must still block replacement.

Done when: a realistically large diary does not freeze editing, consecutive writes stay ordered, and failure injection leaves the last committed snapshot intact.

## B — faster logging and real portions

### B1. Extend the existing meal model, rather than create a duplicate catalog

Current saved meals already provide reusable names, ingredients, calories and vegetarian classification. Add:

- Reference serving amount and unit, with optional gram weight when supplied by the user.
- Optional user-entered macro values and nutrition source. Unknown macros remain nil.
- Fractional consumed portions with consistent rounding for display and totals.
- Entry snapshots of the selected serving/nutrition values. Editing/deleting a saved meal must not rewrite historical intake.
- Stable links to the source meal when present; the snapshot must remain usable when that source is removed.
- Favorites/recent usage derived from actual user activity.

Migration: legacy calorie-only foods and meals remain usable as manual totals or explicitly labeled unspecified servings. Never invent grams, ingredients or macros for them.

### B2. Add the Choose food and Portion editor flows

- Offer saved meals, recent entries and manual logging from the same entry point.
- Keep the day and meal category chosen in Diary.
- Show computed calories before committing; reject zero/non-finite/invalid portions with field-level feedback.
- Offer re-log/duplicate actions that open a reviewable draft, rather than immediately add another entry.
- Start empty with a Create meal action when the user has no saved content.

Done when: a half/double serving calculates correctly, saved entries survive relaunch, a past-day quick-add stays on that day, and editing a library item leaves previous entries unchanged.

### B3. Improve the existing diary and dashboard

- Diary: previous/next day and Today shortcuts, per-meal subtotals, search and undo deletion.
- Today: recent real entries with edit links, actual plan summary, Health freshness and missing-target guidance.
- Keep zero logged entries distinct from a complete day of recorded zero intake. Avoid treating a missing target as zero.

Done when: deleting/undoing restores the original entry ID/date, and empty/unset states stay accurate after edits and target clearing.

## C — editable planning and history

### C1. Planned meal editor

Current plan entries preserve copied meal names/calories but cannot be edited or moved.

- Open a plan row to edit its snapshot, date, category and portion.
- Copy to another day with a new identity; move with the original identity.
- Keep existing atomic/idempotent consume behavior and block future eaten-food entries at the store boundary, not only in the UI.
- Preserve plans when a saved meal is edited or deleted; offer an explicit update action if needed.

Done when: edit/move/copy/delete and failed saves preserve the right IDs and dates; repeatedly marking eaten still logs exactly once.

### C2. Weight and water entry/history

- Weight history: add an editor and a readable trend after provenance rules are implemented.
- Water: custom amount/date, past-day browsing, edit and undo delete. A hydration goal is optional and user-set.
- Both: drafts, validation, source/time where applicable, honest empty states and successful-save-dependent dismissal.

Done when: backdating, cancelling, editing, deleting and relaunching preserve totals and measurement consistency.

## D — insights and data control

### D1. Daily summary, trends and target history

- Record changes to manual targets with effective dates, including explicitly unset targets.
- Do not retroactively invent targets for older entries. Clearly label older comparisons as unavailable or current-target comparisons.
- Add 7/30-day calorie views, a weight trend from actual measurements and drill-down to a daily summary.
- Show logging coverage; do not calculate an apparent low average by silently counting unlogged days as zero consumption.
- Keep summaries descriptive. Do not extrapolate unsupported completion dates from a few weigh-ins.

Done when: target changes do not rewrite past meaning; sparse records and missing targets remain understandable; VoiceOver can read chart values without needing to see a graph.

### D2. Archive browser and backup improvements

- List actual retained recovery files with modification dates and sizes.
- Preview validated content when readable; allow original-byte export when unreadable.
- Restore using the existing confirmation and archive-before-replace path.
- Add explicit archive deletion/retention controls; never silently delete the only recovery copy.
- Expand backup previews to cover all collections and date ranges when actually present.
- Consider merge only after deduplication rules exist; retain replace-only restore until then.

Done when: multiple real archives are accessible across relaunches, cancelled restore changes nothing, and corrupt archives can still be exported safely.

## E — optional features, after core flows

### E1. Units and reminders

- Units: optional imperial display with one canonical internal measurement format and tested conversions. No change to underlying values merely from changing display units.
- Reminders: local notifications only after explicit opt-in, editable schedules and accurate authorization status. No default notification schedule.

### E2. Research-backed target estimation

This remains part of the original product direction, but current age/activity fields are context only.

Before coding, select an authoritative estimation method and document required inputs, assumptions, supported population and unsupported-profile behavior. Add explicit input collection, calculation tests, an explanation/review page and an Apply action. Preserve manual mode and absent targets. New Health measurements must not silently overwrite a target. Decide activity accounting so exercise is not counted twice.

No formula, calorie floor, weight-change pace or goal deadline is prescribed by this planning document.

## F — AI and LLM implementation plan

### F1. Purpose and boundaries

The first AI feature answers **“What can I eat from my saved meals?”** It should help the user choose and understand an option, while the app owns facts, calculations and writes.

- Suggestions are optional. Manual logging, planning, profile editing and backups remain available without AI or a network connection.
- Start with the real user-created meal collection, actual logged totals, explicit preferences and any existing manual target. Do not add a demonstration catalog to make the assistant appear useful.
- Separate three states in the UI: **saved user meal**, **AI-generated idea**, and **logged/planned entry**. An idea is not a measured food record.
- When data is missing, ask for the missing information or explain that it cannot be calculated. Do not invent calories, macros, serving weights, Health activity or targets.
- Keep automatic calorie-target prescriptions, diagnoses and claims of verified allergen safety outside the AI pilot. The AI must not silently change goals based on body measurements or exercise.

### F2. Suggestion features, in order

| Feature | Input | Output / action | Stage |
| --- | --- | --- | --- |
| Saved-meal suggestions | Saved meals, food style, exclusions, optional requested meal and real remaining calories | Up to three valid meal IDs with a concise explanation; actual nutrition is computed/displayed by the app | First pilot |
| Portion-aware alternatives | Saved serving definitions and a user-selected budget | Valid portions and comparisons; arithmetic and limits are deterministic, not model-authored | After serving editor |
| Natural-language logging assistance | User description plus matching saved meals | An editable food-entry draft; unknown amounts/calories remain blank | P2 |
| Daily/weekly explanation | Aggregated real logs, logging coverage and known targets | Descriptive summary of recorded data, with missing days clearly acknowledged | P2 |
| New meal ideas from user ingredients | Ingredients explicitly supplied by the user | Labeled generated recipe/meal draft, not added to the library or diary automatically; nutrition remains unknown until supported by actual inputs or a verified source | P2 |

For the initial release, prefer “find and explain a matching saved meal” over unrestricted diet chat. Recipe generation and photo-based estimates are not required to ship this assistant.

### F3. Suggested interaction

1. User opens What can I eat? and chooses the context they want to use.
2. The app shows a compact context summary: saved-meal count, chosen preferences and target/budget availability. AI sharing is off until opted in.
3. The user enters a request, or explicitly taps a request action such as Suggest from my saved meals. Action labels are controls; no sample conversation is stored.
4. The app filters/ranks eligible saved meals and calculates known calorie values before asking the model for a structured explanation.
5. A response is validated against the permitted meal IDs and constraints. Unknown IDs, unsupported values and invalid portions are rejected.
6. Suggestion review displays the actual source meal, calculated nutrition where available and a short reason. It identifies generated content clearly.
7. The user can adjust a portion, open the original meal, or prepare a Log / Plan draft. Nothing enters the diary, meal collection or planner without an explicit confirmation and successful store transaction.
8. With no saved meals or no eligible matches, show a real empty state and Create meal / Change filters actions. Do not fabricate a replacement meal or force a budget match.

### F4. Architecture

**Deterministic app layer**

- Build a SuggestionContext from the minimum selected data: eligible meal IDs, serving information, user preferences and known budget. Missing values stay nil.
- Apply exclusions, input validation, maximum portions and calorie arithmetic outside the model. Text-based exclusions still cannot establish allergen safety.
- Introduce a SuggestionService protocol. The assistant UI should not depend directly on one model provider or network client.
- Represent suggestions as drafts with source references and a review status. Use the existing transaction store only after user confirmation.

**Optional online service**

- A cloud LLM requires a new backend/service boundary. The current app has no backend; do not imply AI already works locally or offline.
- Keep provider credentials on the server. Never embed a secret API key in Swift source, the IPA, GitHub commits or exported backups.
- Add authenticated/controlled access, input-size limits, request quotas, timeouts and cancellation. A public unrestricted proxy is not acceptable.
- Keep the provider and model configurable; select them after evaluating supported output validation, quality, latency, privacy terms and measured cost. No particular vendor/model is selected by this plan.
- Return a bounded structured response: known source meal IDs, explanation text, optional supported portion proposal and explicit missing-data flags. The client validates again before display/action.
- Treat user text, meal descriptions and any retrieved content as data, not instructions. The model has no direct storage, Health, notification or account-management permissions.

**Offline behavior**

- Offer deterministic filtering/ranking from the saved meal collection when AI is unavailable. Label it as local matching, not an AI response.
- On failed, timed-out or cancelled requests, keep the user's draft and allow retry or manual selection. Never show a simulated successful answer.
- Optional on-device models are a separate later evaluation. Do not assume every iOS 15 device supports an on-device LLM.

### F5. Privacy and user control

- Implement AI settings before the first provider request. Show what leaves the device, who processes it and why.
- Default to sharing only the chosen meal/preference context. Raw Health samples, full historical diaries, name, age and body measurements are not part of the initial suggestion payload.
- If later features need additional personal data, specify that scope and request explicit opt-in rather than silently widening the payload.
- Confirm provider retention and processing behavior during provider selection; do not promise zero retention or confidentiality without evidence and the correct service configuration.
- Keep diagnostic logs free of full personal prompts, Health records and secrets. Use minimal request metadata for reliability/cost monitoring.
- Allow disabling AI, clearing locally stored conversations and cancelling in-flight requests. Explain whether any provider-side deletion is supported; local deletion must not be described as deleting all provider records.
- Decide separately whether AI history is included in backups. Default to excluding conversations until that choice and its export implications are explicit.
- Update Privacy & storage and Help before release, because enabling online AI changes the current local-only data flow.

### F6. Rules for suggestions and nutritional accuracy

- The app calculates the remaining budget only from an explicitly set target and actual logged entries. An unset target does not become zero or a guessed default.
- Calories/macros shown as facts come from user-entered serving data or a separately integrated, attributed source. Model-generated numbers must not be presented as verified nutrition.
- Display the reason an option was suggested using actual context. Avoid claims that a meal is medically suitable or guaranteed safe.
- If a user asks for a meal beyond their remaining budget, explain the constraint without refusing ordinary food logging; keep the manual target a user-controlled guide.
- Summaries describe recorded data, not assumed full intake. Missing logging days are not evidence of fasting or zero consumption.
- No automatic diet changes, diary writes or notifications follow from an AI response. Any proposed change opens a reviewable draft.

### F7. Evaluation and release checks

Build an isolated test/evaluation set; never ship those examples as user data. Include:

- Empty meal collection, no target, missing nutrition and incomplete portions.
- Correct eligibility for vegetarian/exclusion constraints; no unknown saved-meal IDs.
- Incorrect model arithmetic or invented nutrition: the app rejects/replaces it with deterministic facts or unknown values.
- Sparse logging, absent Health results and stale measurements.
- Prompt-injection text inside meal names/descriptions; it cannot alter permissions or trigger a write.
- Invalid structured responses, unrelated answers, request errors, offline mode, cancellation and repeated taps.
- A proposed Log / Plan action is committed once, only after confirmation, and remains recoverable on save failure.
- Data-sharing payload tests proving excluded personal/Health fields are absent.
- Measured response time, cost per request and user feedback on whether the suggestion was useful. Set service limits from the measured pilot rather than inventing pricing figures.

AI release gate: deterministic checks pass, a provider/service and privacy configuration are selected, secret handling and quotas are verified, all writes require review, and the user can still complete the same task without AI.

### F8. Delivery stages

1. Build local matching and SuggestionService contracts after the portion model is stable.
2. Build AI settings/consent and the What can I eat? / Suggestion review pages with honest unavailable states.
3. Implement a secured provider adapter and structured-result validation; evaluate against the isolated cases.
4. Release a small opt-in saved-meal suggestion pilot, measure usefulness and failure rates.
5. Add natural-language drafts, summaries and ingredient-based ideas only after the pilot passes its quality/privacy gates.

AI idea generation does not reverse the no-mock-data requirement: generated drafts are clearly labeled, contain no fabricated nutrition, and become saved records only through an explicit user action.

## Data model and engineering changes

| Change | Reason / migration rule |
| --- | --- |
| MetricResult / MeasurementSource | Honest freshness and consistent source/time handling |
| Shared DayContext | One day boundary for dashboard, diary, water, plans and Health |
| ServingDefinition + FoodEntry nutrition snapshot | Fractional portions without rewriting history |
| Favorite/recent usage metadata | Fast logging from the real saved collection |
| TargetChange records | Historical targets, including unknown/unset periods |
| Archive metadata | Browse actual files without creating placeholder records |
| SuggestionContext / SuggestionDraft / source references | Ground optional AI responses in actual meals and keep proposed actions uncommitted |
| AI consent scope and service configuration | Explicit online-data sharing and provider-independent integration |
| Async serialized persistence operations | UI responsiveness with current atomic commit guarantees |

Version the schema when introducing new meanings or units. Add explicit migration fixtures for every supported prior schema. Preserve identifiers, old numeric profile values, journal timestamps and user-created meals. Do not infer old values were mocks based solely on their numeric value.

Split the large multi-screen files as the relevant features change: Features/Diary, Features/Meals, Features/Progress, Features/Profile, Services and Persistence. Avoid an unrelated file-moving rewrite before functional changes are verified.

## Verification and release gates

Keep the existing 13 domain tests and add behavior coverage for each change:

- Health: independent failures, unavailable results, stale values, refresh concurrency and permission/refresh separation.
- Dates: midnight, foreground after a day away, intentional historical selection and timezone policy.
- Measurements: latest selection, edit/delete/import ordering and unset state.
- Portions: fractions, invalid inputs, optional macros, rounding and immutable history.
- Planning: edit/move/copy identity rules, future-date enforcement and idempotent consumption.
- Storage: concurrent save ordering, write failure, migration, locked-file handling and archive/restore cancellation.
- Insights: sparse logging, unknown historical targets and target clearing.

UI acceptance: small iPhone, large accessibility text, VoiceOver, light/dark/system, Reduce Motion/Transparency, long names, keyboard dismissal, docked Save and unsaved draft behavior. Run available simulator checks in CI and actual Health/file-picker tests on the user's phone. Report unavailable OS coverage rather than claiming it passed.

Each release must pass domain tests and IPA compilation, preserve the bundle identifier/data container, include a version/build and explain remaining limitations. Add real app icon assets and concise release notes; use Bundle metadata rather than fabricated version fallbacks.

## Explicitly deferred

Cloud accounts/sync, subscriptions, social feeds, AI food-photo estimates, barcode scanning, remote food search, background Health delivery and dietary writes. A real external food database may be evaluated later with source attribution and failure handling; never replace missing results with sample data.

## Next concrete work package

1. Implement independent Health states and freshness timestamps.
2. Add shared day context and measurement reconciliation.
3. Extend serving/snapshot models with migrations and domain tests.
4. Build Choose food and Portion editor, connected to the existing diary.
5. Add Planned meal editor and dated weight/water management.
6. Build local meal matching plus AI settings, then the opt-in saved-meal suggestion pilot described in group F.

This update is planning only. It does not change app behavior or initiate the above work.

## Critical-first implementation update — 19 October 2026

Version 0.5.0 implements the first critical page package: Health metric detail/status and per-metric retry, independent Health queries with freshness, permission/refresh separation, shared day refresh, Weight history and entry editing/deletion with current-measurement reconciliation, Water history/custom entry editing, and Planned meal editing/rescheduling/copying. These pages use actual stored/Health data and explicit persistence operations.

This is not a claim that the entire roadmap is complete. Async persistence in A4, full portion models and Choose food, target history, the archive browser and the optional AI/backend pilot remain open. Real iPhone testing of Health permissions, date changes, sources and the new editors is required after the cloud checks.

## User-requested account pages — 19 October 2026

Login/register were explicitly requested after the original local-only roadmap. Version 0.6.0 adds welcome, login, registration and password-reset pages, with a guest path that preserves the local diary. They use an AccountProvider boundary and a deliberately unconfigured production implementation that cannot claim account creation or authentication. No real backend or network identity service has been selected.

Before enabling live accounts: configure a provider; implement token lifecycle/Keychain, verification and reset; define data isolation/migration per account and explicit guest-diary handling; implement sign-out/deletion; update privacy disclosures and add integration tests. This does not imply cloud diary sync or a configured AI backend.
