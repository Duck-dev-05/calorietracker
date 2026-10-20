import XCTest
@testable import DiaryCore

@MainActor private final class SaveGateProbe {
    var diary: Diary?
    var rejected = false
}
final class PhaseOneTests: XCTestCase {
    private func temporaryURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PhaseOne-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("diary.json")
    }
    private func ingredient(_ name: String, calories: Double, protein: Double?) -> RecipeIngredient {
        let snapshot = NutritionSnapshot(referenceQuantity: 100, referenceUnit: .gram,
            referenceNutrients: NutrientValues(calories: calories, protein: protein, carbohydrate: 20, fat: 0),
            quantity: 50, unit: .gram, source: "Test label",
            provenance: NutritionProvenance(kind: .label, provider: "Test manufacturer", sourceID: name, version: "label-1"))
        return RecipeIngredient(name: name, nutrition: IngredientNutrition(snapshot))
    }
    func testExplicitMappingsAndMissingBridge() throws {
        let mapping = PortionMapping(gramsPerServing: 30, millilitersPerServing: 60, gramsPerMilliliter: 0.5)
        XCTAssertEqual(try mapping.converted(2, from: .serving, to: .gram), 60)
        XCTAssertEqual(try mapping.converted(0.12, from: .liter, to: .serving), 2)
        XCTAssertEqual(try mapping.converted(25, from: .gram, to: .milliliter), 50)
        XCTAssertThrowsError(try PortionMapping().converted(1, from: .serving, to: .gram))
        XCTAssertThrowsError(try PortionMapping(gramsPerServing: 30, millilitersPerServing: 60, gramsPerMilliliter: 1).validate())
        XCTAssertThrowsError(try PortionMapping(gramsPerMilliliter: .nan).validate())
        let snapshot = NutritionSnapshot(referenceQuantity: 100, referenceUnit: .gram,
            referenceNutrients: NutrientValues(calories: 200), quantity: 2, unit: .serving, source: "Test", mapping: mapping)
        XCTAssertEqual(try snapshot.totals().calories, 120)
    }
    func testRecipeYieldKnownZeroAndUnknownCoverage() throws {
        let recipe = RecipeSnapshot(ingredients: [ingredient("A", calories: 200, protein: 10), ingredient("B", calories: 100, protein: nil)], yieldServings: 3)
        let snapshot = try recipe.snapshot()
        XCTAssertEqual(try snapshot.totals().calories, 50)
        XCTAssertNil(try snapshot.totals().protein)
        XCTAssertEqual(try snapshot.totals().fat, 0)
        XCTAssertEqual(try snapshot.totals().carbohydrate!, 20.0 / 3, accuracy: 0.000001)
        let meal = Meal(name: "Test recipe", detail: "Test ingredients", calories: 50, vegetarian: true, nutrition: snapshot)
        let portion = try meal.portion(2.5)
        XCTAssertEqual(try portion.totals().calories, 125)
        XCTAssertEqual(portion.recipe, recipe)
        XCTAssertEqual(portion.recipe?.ingredients.first?.nutrition.provenance?.sourceID, "A")
        var diary = DiarySnapshot.empty; diary.savedMeals = [meal]; diary.foods = [Food(name: meal.name, calories: 125, nutrition: portion)]
        let restored = try DiarySnapshot.decode(diary.encoded())
        XCTAssertEqual(restored.foods[0].nutrition, portion)
        var edited = NutritionDraft(snapshot); edited.calories = "999"
        XCTAssertThrowsError(try edited.snapshot())
        edited.recipe = nil
        XCTAssertNoThrow(try edited.snapshot())
    }
    func testRecipeInvalidYieldDuplicateAndInconsistentSourceRejected() throws {
        let item = ingredient("A", calories: 100, protein: 1)
        XCTAssertThrowsError(try RecipeSnapshot(ingredients: [], yieldServings: 1).snapshot())
        XCTAssertThrowsError(try RecipeSnapshot(ingredients: [item], yieldServings: 0).snapshot())
        XCTAssertThrowsError(try RecipeSnapshot(ingredients: [item, item], yieldServings: 1).snapshot())
        let recipe = RecipeSnapshot(ingredients: [item], yieldServings: 2)
        let forged = NutritionSnapshot(referenceQuantity: 2, referenceUnit: .serving,
            referenceNutrients: NutrientValues(calories: 999), quantity: 1, unit: .serving, source: "Bad", recipe: recipe)
        XCTAssertThrowsError(try forged.totals())
    }
    func testExternalAttributionValidationAndUnchangedDraftPrecision() throws {
        let record = NutritionProvenance(kind: .external, provider: "Test", sourceID: "record-1", version: "1", retrievedAt: Date(timeIntervalSince1970: 1_700_000_000), url: "https://example.com/food/1")
        let snapshot = NutritionSnapshot(referenceQuantity: 100, referenceUnit: .gram,
            referenceNutrients: NutrientValues(calories: 200, protein: 1.2345678901234567), quantity: 125, unit: .gram,
            source: "Test external source", provenance: record, mapping: PortionMapping(gramsPerServing: 25.123456789012345))
        XCTAssertEqual(try NutritionDraft(snapshot).snapshot(), snapshot)
        var invalid = record; invalid.sourceID = ""
        XCTAssertThrowsError(try invalid.validate())
        invalid = record; invalid.url = "https://user:password@example.com"
        XCTAssertThrowsError(try invalid.validate())
    }
    func testNoDoubleCountingActivityPolicy() throws {
        for active in [nil, 0, 500, Double.nan, Double.infinity] as [Double?] {
            XCTAssertEqual(try ActivityBudgetPolicy.target(baseline: 2000, activeEnergy: active, workoutEnergy: 500), 2000)
        }
        XCTAssertNil(try ActivityBudgetPolicy.target(baseline: nil, activeEnergy: 500, workoutEnergy: 500))
        XCTAssertThrowsError(try ActivityBudgetPolicy.target(baseline: -1, activeEnergy: 0, workoutEnergy: 0))
    }
    func testAllLegacyFileFixturesDecodeWithoutInventingNutrition() throws {
        for name in ["legacy", "1", "2", "3", "4"] {
            let path = try XCTUnwrap(Bundle.module.url(forResource: "schema-\(name)", withExtension: "json"))
            let snapshot = try DiarySnapshot.decode(Data(contentsOf: path))
            XCTAssertEqual(snapshot.schemaVersion, 5)
            XCTAssertEqual(snapshot.foods[0].id.uuidString, "11111111-1111-4111-8111-111111111111")
            XCTAssertEqual(snapshot.foods[0].date, Date(timeIntervalSinceReferenceDate: 700000000))
            XCTAssertEqual(snapshot.profile.weight, 58.5123456789)
            XCTAssertNil(snapshot.foods[0].nutrition?.provenance)
            XCTAssertNil(snapshot.foods[0].nutrition?.recipe)
            XCTAssertNil(snapshot.foods[0].nutrition?.mapping)
            let restored = try DiarySnapshot.decode(snapshot.encoded())
            XCTAssertEqual(restored.foods[0].nutrition, snapshot.foods[0].nutrition)
        }
    }
    @MainActor func testAsyncMigrationArchivesOriginalAndFailedCommitDoesNotPublish() async throws {
        let account = try await signedInTestAccount()
        let url = try temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let fixture = try XCTUnwrap(Bundle.module.url(forResource: "schema-4", withExtension: "json"))
        let original = try Data(contentsOf: fixture); try original.write(to: url)
        let diary = Diary(url: url, account: account)
        let migrated = await diary.transactionAsync { $0.profile.name = "Updated" }
        XCTAssertTrue(migrated)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(diary.lastArchiveURL)), original)
        XCTAssertEqual(try DiarySnapshot.decode(Data(contentsOf: url)).schemaVersion, 5)
        let bytes = try Data(contentsOf: url)
        let failed = Diary(url: url, account: account, writer: { _, _ in throw DiaryFailure.invalid("Disk full") })
        let committed = await failed.transactionAsync { $0.profile.name = "Do not publish" }
        XCTAssertFalse(committed)
        XCTAssertEqual(failed.profile.name, "Updated")
        XCTAssertFalse(failed.isSaving)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    @MainActor func testAsyncGateRejectsConcurrentWritesAndRestorePreviewChanges() async throws {
        let account = try await signedInTestAccount()
        let url = try temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var original = DiarySnapshot.empty; original.foods = [Food(name: "Initial", calories: 100)]
        try original.encoded().write(to: url)
        let probe = SaveGateProbe()
        let release = DispatchSemaphore(value: 0)
        let diary = Diary(url: url, account: account, writer: { data, target in
            Task { @MainActor in
                probe.rejected = !(probe.diary?.upsertFood(Food(name: "Competing", calories: 100)) ?? true)
                release.signal()
            }
            guard release.wait(timeout: .now() + 5) == .success else { throw DiaryFailure.invalid("Test save gate timed out.") }
            try Diary.writeFile(data, target)
        })
        probe.diary = diary
        let revision = diary.revision
        let result = await diary.transactionAsync { $0.profile.name = "Async" }
        XCTAssertTrue(result)
        XCTAssertTrue(probe.rejected)
        XCTAssertEqual(diary.foods.count, 1)
        let restored = await diary.replaceAsync(with: .empty, expectedRevision: revision)
        XCTAssertFalse(restored)
        let bytes = try await diary.backupDataAsync()
        XCTAssertEqual(try DiarySnapshot.decode(bytes).profile.name, "Async")
    }
    @MainActor func testAsyncExportRestoreRepresentativeJournalRoundTrip() async throws {
        let account = try await signedInTestAccount()
        let url = try temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let diary = Diary(url: url, account: account)
        let recipe = try RecipeSnapshot(ingredients: [ingredient("Test", calories: 200, protein: 10)], yieldServings: 2).snapshot()
        var fixture = DiarySnapshot.empty
        fixture.foods = (0..<2000).map { Food(name: "Test record \($0)", calories: 50, nutrition: recipe) }
        let success = await diary.replaceAsync(with: fixture, expectedRevision: diary.revision)
        XCTAssertTrue(success)
        let export = try await diary.backupDataAsync()
        let decoded = try await JournalIO.perform { try DiarySnapshot.decode(export) }
        XCTAssertEqual(decoded.foods.count, 2000)
        XCTAssertEqual(decoded.foods[1999].nutrition, recipe)
        let reloaded = Diary(url: url, account: account)
        XCTAssertEqual(reloaded.foods.count, 2000)
    }
}
