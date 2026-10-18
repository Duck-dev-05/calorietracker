import XCTest
@testable import DiaryCore

final class DiaryTests: XCTestCase {
    private func temporaryURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NourishTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("diary.json")
    }
    func testLegacyFileMigratesAndRoundTrips() throws {
        let data = Data("{\"profile\":{\"height\":170,\"weight\":70,\"target\":2000,\"goal\":\"Maintain\",\"preferences\":\"Balanced\"},\"foods\":[]}".utf8)
        let snapshot = try DiarySnapshot.decode(data)
        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertNotNil(snapshot.water)
        XCTAssertNotNil(snapshot.weights)
        XCTAssertNotNil(snapshot.planned)
        XCTAssertEqual(try DiarySnapshot.decode(snapshot.encoded()).profile.target, 2000)
    }
    func testInvalidAndNewerBackupsAreRejected() throws {
        var snapshot = DiarySnapshot.empty
        snapshot.profile.target = -1
        XCTAssertThrowsError(try snapshot.encoded())
        snapshot = .empty; snapshot.schemaVersion = 99
        XCTAssertThrowsError(try snapshot.encoded())
        XCTAssertThrowsError(try DiarySnapshot.decode(Data("not json".utf8)))
        snapshot = .empty
        let food = Food(name: "Rice", calories: 200)
        snapshot.foods = [food, food]
        XCTAssertThrowsError(try snapshot.encoded())
        XCTAssertThrowsError(try DiarySnapshot.decode(Data(repeating: 0, count: DiarySnapshot.maxFileSize + 1)))
    }
    func testFailedFoodWriteDoesNotPublishOrChangeDisk() async throws {
        try await MainActor.run {
            let url = try temporaryURL()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let original = try DiarySnapshot.empty.encoded()
            try original.write(to: url)
            let diary = Diary(url: url, writer: { _, _ in throw DiaryFailure.invalid("Disk full") })
            XCTAssertFalse(diary.upsertFood(Food(name: "Rice", calories: 200)))
            XCTAssertTrue(diary.foods.isEmpty)
            XCTAssertEqual(try Data(contentsOf: url), original)
            XCTAssertNotNil(diary.storageError)
        }
    }
    func testPlanTransferIsAtomicIdempotentAndPersists() async throws {
        try await MainActor.run {
            let url = try temporaryURL()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            var fail = false
            var writes = 0
            let diary = Diary(url: url, writer: { data, target in
                if fail { throw DiaryFailure.invalid("Simulated failure") }
                writes += 1; try Diary.writeFile(data, target)
            })
            let meal = PlannedMeal(date: Date(), name: "Lunch", calories: 500, category: "Lunch")
            XCTAssertTrue(diary.transaction { $0.planned = [meal] })
            let baseline = writes
            fail = true
            XCTAssertFalse(diary.consumePlan(meal.id))
            XCTAssertEqual(diary.planned.count, 1); XCTAssertTrue(diary.foods.isEmpty)
            fail = false
            XCTAssertTrue(diary.consumePlan(meal.id))
            XCTAssertEqual(writes, baseline + 1)
            XCTAssertTrue(diary.consumePlan(meal.id))
            XCTAssertEqual(writes, baseline + 1)
            let reloaded = Diary(url: url)
            XCTAssertTrue(reloaded.planned.isEmpty); XCTAssertEqual(reloaded.foods.count, 1)
            XCTAssertEqual(reloaded.consumed, 500)
        }
    }
    func testCorruptStorageIsBlockedAndResetPreservesOriginal() async throws {
        try await MainActor.run {
            let url = try temporaryURL()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let corrupt = Data("original damaged file".utf8)
            try corrupt.write(to: url)
            let diary = Diary(url: url)
            XCTAssertTrue(diary.storageBlocked)
            XCTAssertFalse(diary.upsertFood(Food(name: "Rice", calories: 100)))
            XCTAssertEqual(try diary.originalData(), corrupt)
            XCTAssertTrue(diary.replace(with: .empty))
            XCTAssertFalse(diary.storageBlocked)
            let archive = try XCTUnwrap(diary.lastArchiveURL)
            XCTAssertEqual(try Data(contentsOf: archive), corrupt)
            XCTAssertEqual(Diary(url: url).lastArchiveURL, archive)
        }
    }
    func testRestoreRoundTripPreservesRecordsAndArchive() async throws {
        try await MainActor.run {
            let url = try temporaryURL()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let diary = Diary(url: url)
            let entry = Food(name: "Breakfast", calories: 350, category: "Breakfast")
            XCTAssertTrue(diary.upsertFood(entry))
            let export = try diary.backupData()
            XCTAssertTrue(diary.upsertFood(Food(name: "Snack", calories: 100)))
            XCTAssertTrue(diary.replace(with: try DiarySnapshot.decode(export)))
            XCTAssertEqual(diary.foods.map(\.id), [entry.id])
            let archive = try XCTUnwrap(diary.lastArchiveURL)
            XCTAssertEqual(try DiarySnapshot.decode(Data(contentsOf: archive)).foods.count, 2)
        }
    }
    func testFailedRestoreLeavesExistingDiaryAndPreservesArchive() async throws {
        try await MainActor.run {
            let url = try temporaryURL()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let original = try DiarySnapshot.empty.encoded()
            try original.write(to: url)
            let diary = Diary(url: url, writer: { _, _ in throw DiaryFailure.invalid("Disk full") })
            var replacement = DiarySnapshot.empty; replacement.foods = [Food(name: "Rice", calories: 200)]
            XCTAssertFalse(diary.replace(with: replacement))
            XCTAssertTrue(diary.foods.isEmpty)
            XCTAssertEqual(try Data(contentsOf: url), original)
            XCTAssertEqual(try Data(contentsOf: XCTUnwrap(diary.lastArchiveURL)), original)
        }
    }
    func testFuturePlanCannotBeConsumedAndBackdatedWeightDoesNotReplaceLatest() async throws {
        try await MainActor.run {
            let url = try temporaryURL()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let diary = Diary(url: url)
            let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
            let future = PlannedMeal(date: tomorrow, name: "Tomorrow", calories: 400, category: "Dinner")
            XCTAssertTrue(diary.transaction { $0.planned = [future] })
            XCTAssertFalse(diary.consumePlan(future.id)); XCTAssertEqual(diary.planned.count, 1)
            XCTAssertTrue(diary.logWeight(WeightEntry(kilograms: 72)))
            XCTAssertTrue(diary.logWeight(WeightEntry(date: Date().addingTimeInterval(-86400), kilograms: 75)))
            XCTAssertEqual(diary.profile.weight, 72)
        }
    }
}
