import XCTest
@testable import DiaryCore

final class NutritionTargetTests: XCTestCase {
    private func url() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TargetTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("diary.json")
    }
    func testMacroAllocationAndUnknowns() throws {
        let ratio = MacroAllocation(protein: 25, carbohydrate: 50, fat: 25)
        let grams = try ratio.grams(calories: 2000)
        XCTAssertEqual(grams.protein, 125); XCTAssertEqual(grams.carbohydrate, 250)
        XCTAssertEqual(grams.fat!, 500 / 9, accuracy: 0.000001)
        XCTAssertThrowsError(try MacroAllocation(protein: 25, carbohydrate: 50, fat: 24).validate())
        XCTAssertThrowsError(try MacroAllocation(protein: -1, carbohydrate: 51, fat: 50).validate())
        XCTAssertThrowsError(try MacroAllocation(protein: Int.max, carbohydrate: 1, fat: 0).validate())
    }
    func testEstimatePublishedSimplifiedEquationAndApplicability() throws {
        let value = EnergyEstimate(age: 30, heightCM: 180, weightKG: 80, maleCoefficient: true, activityFactor: 1.5, applicable: true)
        XCTAssertNoThrow(try value.validate()); XCTAssertEqual(value.resting, 1780); XCTAssertEqual(value.maintenance, 2670)
        let female = EnergyEstimate(age: 30, heightCM: 180, weightKG: 80, maleCoefficient: false, activityFactor: 1.5, applicable: true)
        XCTAssertEqual(female.resting, 1614)
        for invalid in [
            EnergyEstimate(age: 18, heightCM: 180, weightKG: 80, maleCoefficient: true, activityFactor: 1.5, applicable: true),
            EnergyEstimate(age: 30, heightCM: 180, weightKG: 80, maleCoefficient: true, activityFactor: .nan, applicable: true),
            EnergyEstimate(age: 30, heightCM: 180, weightKG: 80, maleCoefficient: true, activityFactor: 1.5, applicable: false)
        ] { XCTAssertThrowsError(try invalid.validate()) }
        let target = NutritionTarget(effectiveDay: "2026-10-20", calories: 2500, allocation: nil, method: "mifflin-st-jeor-v1", estimate: value)
        XCTAssertThrowsError(try target.validate())
    }
    func testDailyMacrosShowCoverageAndKnownZeroSeparately() throws {
        let foods = [Food(name: "Known", calories: 100, nutrition: .manual(calories: 100, protein: 0, carbohydrate: 10)), Food(name: "Legacy", calories: 200)]
        let summary = try DailyNutrition(foods: foods)
        XCTAssertEqual(summary.calories, 300); XCTAssertEqual(summary.protein.known, 0)
        XCTAssertEqual(summary.protein.knownEntries, 1); XCTAssertEqual(summary.protein.totalEntries, 2)
        XCTAssertFalse(summary.protein.complete); XCTAssertEqual(summary.fat.knownEntries, 0)
        XCTAssertFalse(try DailyNutrition(foods: []).protein.complete)
        XCTAssertThrowsError(try DailyNutrition(foods: [Food(name: "Bad", calories: Int.max)]))
    }
    func testEffectiveDatesAndSameDayRevisionsDoNotRewritePast() throws {
        let first = NutritionTarget(effectiveDay: "2026-10-20", calories: 2000, allocation: nil, method: "manual-v1")
        let later = NutritionTarget(effectiveDay: "2026-10-22", calories: 2200, allocation: nil, method: "manual-v1")
        let revision = NutritionTarget(effectiveDay: "2026-10-22", calories: 2300, allocation: nil, method: "manual-v1")
        let disabled = NutritionTarget(effectiveDay: "2026-10-24", calories: nil, allocation: nil, method: "manual-v1")
        let records = [first, later, revision, disabled]
        XCTAssertNil(NutritionTarget.effective(in: records, day: "2026-10-19"))
        XCTAssertEqual(NutritionTarget.effective(in: records, day: "2026-10-21")?.calories, 2000)
        XCTAssertEqual(NutritionTarget.effective(in: records, day: "2026-10-22")?.id, revision.id)
        XCTAssertNil(NutritionTarget.effective(in: records, day: "2026-10-25")?.calories)
        XCTAssertFalse(NutritionTarget.validDay("2026-02-30")); XCTAssertFalse(NutritionTarget.validDay("20-10-2026"))
        XCTAssertTrue(NutritionTarget.validDay("2024-02-29"))
    }
    func testTargetsAndEstimateRoundTripAndInvalidRestoreRejected() throws {
        let estimate = EnergyEstimate(age: 30, heightCM: 180, weightKG: 80, maleCoefficient: true, activityFactor: 1.5, applicable: true)
        let target = NutritionTarget(effectiveDay: "2026-10-20", calories: 2670, allocation: MacroAllocation(protein: 25, carbohydrate: 50, fat: 25), method: "mifflin-st-jeor-v1", estimate: estimate)
        var snapshot = DiarySnapshot.empty; snapshot.targets = [target]
        let restored = try DiarySnapshot.decode(snapshot.encoded())
        XCTAssertEqual(restored.targets, [target]); XCTAssertEqual(restored.schemaVersion, 4)
        snapshot.targets = [target, target]; XCTAssertThrowsError(try snapshot.encoded())
        snapshot.targets = [NutritionTarget(effectiveDay: "bad", calories: 2000, allocation: nil, method: "manual-v1")]
        XCTAssertThrowsError(try snapshot.encoded())
    }
    func testLegacyMigrationNeverInventsTargetHistoryAndArchivesOriginal() async throws {
        let account = try await signedInTestAccount()
        try await MainActor.run {
            let path = try url(); defer { try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
            var old = DiarySnapshot.empty; old.schemaVersion = 3; old.profile.target = 2000
            let original = try JSONEncoder().encode(old); try original.write(to: path)
            let diary = Diary(url: path, account: account)
            XCTAssertTrue(diary.targetRecords.isEmpty); XCTAssertEqual(diary.currentTargetCalories, 2000)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: diary.now)!
            XCTAssertNil(diary.targetCalories(on: yesterday))
            let future = Calendar.current.date(byAdding: .day, value: 2, to: diary.now)!
            XCTAssertTrue(diary.saveTarget(NutritionTarget(effectiveDay: NutritionTarget.dayKey(future), calories: 2200, allocation: nil, method: "manual-v1")))
            XCTAssertEqual(diary.currentTargetCalories, 2000); XCTAssertEqual(diary.targetCalories(on: future), 2200)
            XCTAssertNil(diary.targetCalories(on: yesterday))
            XCTAssertEqual(try Data(contentsOf: XCTUnwrap(diary.lastArchiveURL)), original)
            XCTAssertEqual(try DiarySnapshot.decode(Data(contentsOf: path)).schemaVersion, 4)
            XCTAssertEqual(Diary(url: path, account: account).targetRecords, diary.targetRecords)
        }
    }
    func testFailedTargetWriteAndStaleEditorLeaveRecordsUntouched() async throws {
        let account = try await signedInTestAccount()
        try await MainActor.run {
            let path = try url(); defer { try? FileManager.default.removeItem(at: path.deletingLastPathComponent()) }
            let bytes = try DiarySnapshot.empty.encoded(); try bytes.write(to: path)
            let failed = Diary(url: path, account: account, writer: { _, _ in throw DiaryFailure.invalid("Disk full") })
            let record = NutritionTarget(effectiveDay: NutritionTarget.dayKey(failed.now), calories: 2000, allocation: nil, method: "manual-v1")
            XCTAssertFalse(failed.saveTarget(record)); XCTAssertTrue(failed.targetRecords.isEmpty)
            XCTAssertNil(failed.profile.target); XCTAssertEqual(try Data(contentsOf: path), bytes)
            let diary = Diary(url: path, account: account)
            XCTAssertTrue(diary.saveTarget(record, expectedRecords: []))
            let stored = try Data(contentsOf: path)
            XCTAssertFalse(diary.saveTarget(NutritionTarget(effectiveDay: record.effectiveDay, calories: 2500, allocation: nil, method: "manual-v1"), expectedRecords: []))
            XCTAssertEqual(diary.targetRecords, [record]); XCTAssertEqual(try Data(contentsOf: path), stored)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: diary.now)!
            XCTAssertFalse(diary.saveTarget(NutritionTarget(effectiveDay: NutritionTarget.dayKey(yesterday), calories: 1800, allocation: nil, method: "manual-v1")))
        }
    }
}
