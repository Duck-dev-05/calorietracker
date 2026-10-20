import XCTest
@testable import DiaryCore

final class NutritionEditingTests: XCTestCase {
    func testQuickEntryOnlyNeedsCaloriesAndNeverInventsMacros() throws {
        var draft = NutritionDraft()
        XCTAssertThrowsError(try draft.snapshot())
        draft.calories = "250"
        XCTAssertEqual(try draft.snapshot(), .manual(calories: 250))
        draft.calories = "invalid"
        XCTAssertNil(try? draft.snapshot())
        draft.calories = "250"; draft.protein = "bad"
        XCTAssertNil(try? draft.snapshot())
    }
    private func sample() -> NutritionSnapshot {
        NutritionSnapshot(referenceQuantity: 100, referenceUnit: .gram,
            referenceNutrients: NutrientValues(calories: 123.45678901234567, protein: 0.000000000000000123, carbohydrate: 12.345678901234567, fat: 0),
            quantity: 155.55555555555554, unit: .gram, source: "Original label", sourceMealID: UUID())
    }
    func testUnchangedDraftPreservesExactSnapshot() throws {
        let original = sample()
        XCTAssertEqual(try NutritionDraft(original).snapshot(), original)
    }
    func testEditingOneMacroPreservesEveryUntouchedValueExactly() throws {
        let original = sample()
        var draft = NutritionDraft(original)
        draft.fat = NutritionDraft.text(8.25)
        let edited = try draft.snapshot()
        XCTAssertEqual(edited.referenceNutrients.fat, 8.25)
        XCTAssertEqual(edited.referenceNutrients.protein, original.referenceNutrients.protein)
        XCTAssertEqual(edited.referenceNutrients.carbohydrate, original.referenceNutrients.carbohydrate)
        XCTAssertEqual(edited.referenceNutrients.calories, original.referenceNutrients.calories)
        XCTAssertEqual(edited.quantity, original.quantity)
        XCTAssertEqual(edited.sourceMealID, original.sourceMealID)
        XCTAssertEqual(original.referenceNutrients.fat, 0) // Draft never mutates source.
    }
    func testBlankAndZeroRemainDistinctAndCalorieEditsDoNotDeleteMacros() throws {
        var draft = NutritionDraft(.manual(calories: 100, protein: 5, fat: 0))
        draft.calories = NutritionDraft.text(120)
        draft.protein = ""
        let edited = try draft.snapshot()
        XCTAssertNil(edited.referenceNutrients.protein)
        XCTAssertNil(edited.referenceNutrients.carbohydrate)
        XCTAssertEqual(edited.referenceNutrients.fat, 0)
        XCTAssertEqual(try edited.roundedCalories(), 120)
    }
    func testPerHundredGramEditorConvertsKilogramsAndKeepsUnknowns() throws {
        var draft = NutritionDraft()
        draft.referenceQuantity = "100"; draft.referenceUnit = .gram
        draft.calories = "200"; draft.protein = "10"
        draft.quantity = NutritionDraft.text(0.175); draft.unit = .kilogram
        let snapshot = try draft.snapshot()
        XCTAssertEqual(try snapshot.roundedCalories(), 350)
        XCTAssertEqual(try snapshot.totals().protein, 17.5)
        XCTAssertNil(try snapshot.totals().fat)
        draft.unit = .milliliter
        XCTAssertThrowsError(try draft.snapshot())
    }
    func testInvalidReferenceAndExplicitZeroEnergyPolicy() throws {
        for value in ["", "NaN", "inf", "-1", "1junk", "1e309"] {
            var draft = NutritionDraft(); draft.calories = value
            XCTAssertThrowsError(try draft.snapshot(), value)
        }
        var draft = NutritionDraft(); draft.calories = "0"
        XCTAssertThrowsError(try draft.snapshot())
        draft.calories = "1"; draft.quantity = NutritionDraft.text(0.1)
        XCTAssertThrowsError(try draft.snapshot())
        draft.quantity = "1"; draft.referenceQuantity = "0"
        XCTAssertThrowsError(try draft.snapshot())
        draft.referenceQuantity = "1"; draft.source = " "
        XCTAssertThrowsError(try draft.snapshot())
    }
    func testArbitraryServingsAndReferenceSnapshotsRoundTrip() throws {
        let meal = Meal(name: "Own meal", detail: "Label", calories: 200, vegetarian: true, nutrition: .manual(calories: 200, protein: 10))
        let portion = try meal.portion(1.37)
        XCTAssertEqual(try portion.roundedCalories(), 274)
        XCTAssertEqual(try portion.totals().protein!, 13.7, accuracy: 0.0000001)
        var diary = DiarySnapshot.empty
        diary.foods = [Food(name: meal.name, calories: 274, nutrition: portion)]
        diary.planned = [PlannedMeal(date: Date(), name: meal.name, calories: 274, category: "Lunch", nutrition: portion)]
        let restored = try DiarySnapshot.decode(diary.encoded())
        XCTAssertEqual(restored.foods.first?.nutrition, portion)
        XCTAssertEqual(restored.planned?.first?.nutrition, portion)
    }
    func testAllSupportedLegacySchemasPreserveIDsDatesUnknownsAndOwner() throws {
        let versions: [Int?] = [nil, 1, 2, 3]
        for version in versions {
            var snapshot = DiarySnapshot.empty; snapshot.schemaVersion = version
            snapshot.ownerAccountID = "legacy-owner"
            snapshot.foods = [Food(name: "Existing", calories: 123, date: Date(timeIntervalSince1970: 1_700_000_000))]
            snapshot.water = nil; snapshot.weights = nil; snapshot.planned = nil; snapshot.savedMeals = nil
            let data = try JSONEncoder().encode(snapshot)
            let restored = try DiarySnapshot.decode(data)
            XCTAssertEqual(restored.foods[0].id, snapshot.foods[0].id)
            XCTAssertEqual(restored.foods[0].date, snapshot.foods[0].date)
            XCTAssertEqual(restored.foods[0].calories, 123)
            XCTAssertNil(restored.foods[0].nutrition)
            XCTAssertNil(restored.profile.target)
            XCTAssertEqual(restored.ownerAccountID, "legacy-owner")
            XCTAssertEqual(restored.schemaVersion, 3)
            XCTAssertEqual(try DiarySnapshot.decode(restored.encoded()).foods[0].id, snapshot.foods[0].id)
        }
    }
}
