import XCTest
@testable import DiaryCore

final class NutritionTests: XCTestCase {
    private func temporaryURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NutritionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("diary.json")
    }
    func testFractionalPortionAndUnknownMacrosRoundTrip() throws {
        let item = NutritionSnapshot(referenceQuantity: 100, referenceUnit: .gram, referenceNutrients: NutrientValues(calories: 180, protein: 12, fat: 0), quantity: 0.15, unit: .kilogram, source: "Test label")
        let totals = try item.totals()
        XCTAssertEqual(totals.calories, 270, accuracy: 0.000001)
        XCTAssertEqual(totals.protein!, 18, accuracy: 0.000001)
        XCTAssertNil(totals.carbohydrate); XCTAssertEqual(totals.fat, 0)
        var saved = DiarySnapshot.empty
        saved.foods = [Food(name: "Test portion", calories: 270, nutrition: item)]
        let restored = try DiarySnapshot.decode(saved.encoded())
        XCTAssertEqual(restored.foods.first?.nutrition, item)
    }
    func testNoInferredMassVolumeOrServingConversion() throws {
        XCTAssertEqual(try NutritionUnit.liter.converted(0.25, to: .milliliter), 250)
        XCTAssertThrowsError(try NutritionUnit.gram.converted(100, to: .milliliter))
        XCTAssertThrowsError(try NutritionUnit.serving.converted(1, to: .gram))
    }
    func testInvalidAndOverflowingNutritionRejected() throws {
        for amount in [Double.nan, .infinity, -1] {
            XCTAssertThrowsError(try NutrientValues(calories: amount).validated())
            XCTAssertThrowsError(try NutrientValues(calories: 100, protein: amount).validated())
        }
        for quantity in [Double.nan, .infinity, 0, -1, 1_000_001] {
            let item = NutritionSnapshot(referenceQuantity: 1, referenceUnit: .serving, referenceNutrients: NutrientValues(calories: 100), quantity: quantity, unit: .serving, source: "Test")
            XCTAssertThrowsError(try item.roundedCalories())
        }
        XCTAssertThrowsError(try NutrientValues(calories: 5000).multiplied(by: Double.greatestFiniteMagnitude))
        XCTAssertThrowsError(try NutrientValues(calories: 100, fat: 2501).validated())
    }
    func testRoundingOnlyAtEntryBoundaryAndMismatchRejected() throws {
        let meal = Meal(name: "Test", detail: "Test serving", calories: 101, vegetarian: true)
        let portion = try meal.portion(0.5)
        XCTAssertEqual(try portion.totals().calories, 50.5)
        XCTAssertEqual(try portion.roundedCalories(), 51)
        var saved = DiarySnapshot.empty
        saved.foods = [Food(name: "Test", calories: 50, nutrition: portion)]
        XCTAssertThrowsError(try saved.encoded())
        saved.foods[0].calories = 51
        XCTAssertNoThrow(try saved.encoded())
        XCTAssertThrowsError(try meal.portion(0.00001))
    }
    func testLegacyMigrationKeepsUnknownsIDsDatesAndCalories() throws {
        var legacy = DiarySnapshot.empty; legacy.schemaVersion = 1
        let food = Food(name: "Legacy entry", calories: 321, date: Date(timeIntervalSince1970: 1_700_000_000))
        legacy.foods = [food]
        let oldBytes = try JSONEncoder().encode(legacy)
        let restored = try DiarySnapshot.decode(oldBytes)
        XCTAssertEqual(restored.schemaVersion, 3)
        XCTAssertEqual(restored.foods.first?.id, food.id)
        XCTAssertEqual(restored.foods.first?.date, food.date)
        XCTAssertEqual(restored.foods.first?.calories, 321)
        XCTAssertNil(restored.foods.first?.nutrition)
        XCTAssertNil(restored.profile.target)
        XCTAssertEqual(try DiarySnapshot.decode(restored.encoded()).foods.first?.id, food.id)
    }
    func testMigrationArchivesExactOriginalBeforeFirstWrite() async throws {
        try await MainActor.run {
            let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            var legacy = DiarySnapshot.empty; legacy.schemaVersion = 1
            legacy.foods = [Food(name: "Legacy", calories: 123)]
            let bytes = try JSONEncoder().encode(legacy); try bytes.write(to: url)
            let diary = Diary(url: url)
            XCTAssertEqual(try Data(contentsOf: url), bytes) // Loading never rewrites.
            XCTAssertTrue(diary.upsertFood(Food(name: "New", calories: 222)))
            XCTAssertEqual(try Data(contentsOf: XCTUnwrap(diary.lastArchiveURL)), bytes)
            XCTAssertEqual(Diary(url: url).foods.count, 2)
        }
    }
    func testArchiveFailurePreventsMigrationWrite() async throws {
        try await MainActor.run {
            let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            var legacy = DiarySnapshot.empty; legacy.schemaVersion = 1
            let bytes = try JSONEncoder().encode(legacy); try bytes.write(to: url)
            // A file at the Recovery directory path makes archiving impossible.
            try Data("blocked".utf8).write(to: url.deletingLastPathComponent().appendingPathComponent("Recovery"))
            let diary = Diary(url: url)
            XCTAssertFalse(diary.upsertFood(Food(name: "New", calories: 123)))
            XCTAssertTrue(diary.foods.isEmpty); XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }
    func testStaleInstanceCannotOverwriteNewerFileOrBypassWithRestore() async throws {
        try await MainActor.run {
            let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let first = Diary(url: url), stale = Diary(url: url)
            XCTAssertTrue(first.upsertFood(Food(name: "Newest", calories: 123)))
            let newest = try Data(contentsOf: url)
            XCTAssertFalse(stale.upsertFood(Food(name: "Stale", calories: 456)))
            XCTAssertTrue(stale.storageBlocked)
            XCTAssertFalse(stale.replace(with: .empty))
            XCTAssertEqual(try Data(contentsOf: url), newest)
            stale.retryLoad()
            XCTAssertEqual(stale.foods.count, 1)
            XCTAssertTrue(stale.upsertFood(Food(name: "After reload", calories: 456)))
            XCTAssertEqual(Diary(url: url).foods.count, 2)
        }
    }
    func testDeletedFileIsNotSilentlyRecreatedFromStaleState() async throws {
        try await MainActor.run {
            let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let diary = Diary(url: url)
            XCTAssertTrue(diary.upsertFood(Food(name: "Original", calories: 100)))
            try FileManager.default.removeItem(at: url)
            XCTAssertFalse(diary.upsertFood(Food(name: "Stale", calories: 200)))
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
            XCTAssertEqual(diary.foods.count, 1)
        }
    }
    func testMealChangesAndPlanTransferKeepHistoricalNutrition() async throws {
        try await MainActor.run {
            let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let diary = Diary(url: url)
            let meal = Meal(name: "Test", detail: "Label", calories: 200, vegetarian: true, nutrition: .manual(calories: 200, protein: 10, carbohydrate: 20, fat: 0))
            XCTAssertTrue(diary.transaction { $0.savedMeals = [meal] })
            XCTAssertTrue(diary.logMeal(meal.id, servings: 0.5, category: "Lunch"))
            XCTAssertTrue(diary.logMeal(meal.id, servings: 1.5, category: "Dinner", plannedDate: diary.now))
            let plan = try XCTUnwrap(diary.planned.first)
            XCTAssertTrue(diary.transaction { $0.savedMeals = [] })
            XCTAssertTrue(diary.consumePlan(plan.id)); XCTAssertTrue(diary.consumePlan(plan.id))
            let loaded = Diary(url: url)
            XCTAssertEqual(loaded.foods.count, 2)
            XCTAssertEqual(loaded.foods.map(\.calories), [100, 300])
            XCTAssertEqual(try loaded.foods[0].nutrition?.totals().protein, 5)
            XCTAssertEqual(loaded.foods[1].nutrition, plan.nutrition)
            XCTAssertFalse(diary.logMeal(meal.id, servings: 1, category: "Lunch"))
        }
    }
    func testFailedNutritionSaveDoesNotChangeMemoryOrDisk() async throws {
        try await MainActor.run {
            let url = try temporaryURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let original = try DiarySnapshot.empty.encoded(); try original.write(to: url)
            let diary = Diary(url: url, writer: { _, _ in throw DiaryFailure.invalid("Disk full") })
            XCTAssertFalse(diary.upsertFood(Food(name: "Test", calories: 100, nutrition: .manual(calories: 100, protein: 5))))
            XCTAssertTrue(diary.foods.isEmpty); XCTAssertEqual(try Data(contentsOf: url), original)
        }
    }
}
