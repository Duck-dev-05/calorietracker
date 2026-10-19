import XCTest
@testable import DiaryCore

@MainActor private final class TestHealthProvider: HealthReadingProvider {
    var available = true
    var requests = 0
    var reads = 0
    var failWeight = false
    var empty = false
    var failRequest = false
    func requestAccess() async throws { requests += 1; if failRequest { throw DiaryFailure.invalid("Test access failure") } }
    func read(_ metric: HealthMetric, now: Date) async throws -> HealthReading? {
        reads += 1
        if failWeight && metric == .weight { throw DiaryFailure.invalid("Test weight failure") }
        if empty { return nil }
        return HealthReading(value: metric == .steps ? 123 : 50, sampleDate: metric.isDaily ? nil : now.addingTimeInterval(-3600), source: metric.isDaily ? nil : "Test source")
    }
}
final class CriticalTests: XCTestCase {
    func testHealthPartialFailureDoesNotSuppressOtherResultsAndRefreshDoesNotAskPermission() async {
        let provider = await MainActor.run { TestHealthProvider() }
        let monitor = await MainActor.run { HealthMonitor(provider: provider) }
        await MainActor.run { provider.failWeight = true }
        await monitor.connect()
        await MainActor.run {
            XCTAssertEqual(provider.requests, 1); XCTAssertEqual(provider.reads, 4)
            XCTAssertEqual(monitor.value(.steps), 123); XCTAssertNil(monitor.value(.weight))
            XCTAssertEqual(monitor.result(.weight).status, .failed)
        }
        await monitor.refresh(.steps)
        await MainActor.run { XCTAssertEqual(provider.requests, 1); XCTAssertEqual(provider.reads, 5) }
    }
    func testHealthFailureAndEmptyResultRemoveOldValues() async {
        let provider = await MainActor.run { TestHealthProvider() }
        let monitor = await MainActor.run { HealthMonitor(provider: provider) }
        await monitor.refresh()
        await MainActor.run { XCTAssertNotNil(monitor.value(.weight)); provider.failWeight = true }
        await monitor.refresh(.weight)
        await MainActor.run { XCTAssertNil(monitor.value(.weight)); XCTAssertNil(monitor.result(.weight).reading); provider.empty = true }
        await monitor.refresh(.steps)
        await MainActor.run { XCTAssertNil(monitor.value(.steps)); XCTAssertEqual(monitor.result(.steps).status, .noData) }
    }
    func testHealthUnavailableDoesNotRequestOrRead() async {
        let provider = await MainActor.run { TestHealthProvider() }
        let monitor = await MainActor.run { HealthMonitor(provider: provider) }
        await MainActor.run { provider.available = false }
        await monitor.connect()
        await MainActor.run { XCTAssertEqual(provider.requests, 0); XCTAssertEqual(provider.reads, 0); XCTAssertEqual(monitor.result(.steps).status, .unavailable) }
    }
    func testDailyHealthExpiresAcrossMidnightTimezoneAndFifteenMinutes() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 23, minute: 59))!
        let result = MetricResult(reading: HealthReading(value: 100), fetchedAt: date, queryDay: date, timeZoneID: calendar.timeZone.identifier, status: .available)
        XCTAssertTrue(result.isFresh(for: .steps, now: date, calendar: calendar))
        XCTAssertFalse(result.isFresh(for: .steps, now: date.addingTimeInterval(120), calendar: calendar))
        XCTAssertFalse(result.isFresh(for: .height, now: date.addingTimeInterval(901), calendar: calendar))
        calendar.timeZone = TimeZone(secondsFromGMT: 3600)!
        XCTAssertFalse(result.isFresh(for: .steps, now: date, calendar: calendar))
    }
    func testWeightEditDeleteAndNewerProfileImport() async throws {
        try await MainActor.run {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("CriticalTests-\(UUID().uuidString)/diary.json")
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let diary = Diary(url: url)
            let now = diary.now
            var earlier = WeightEntry(date: now.addingTimeInterval(-7200), kilograms: 71, source: "Manual")
            let latest = WeightEntry(date: now.addingTimeInterval(-3600), kilograms: 70, source: "Manual")
            XCTAssertTrue(diary.logWeight(earlier)); XCTAssertTrue(diary.logWeight(latest))
            XCTAssertEqual(diary.profile.weightEntryID, latest.id)
            XCTAssertTrue(diary.deleteWeight(latest.id)); XCTAssertEqual(diary.profile.weight, 71)
            earlier.kilograms = 72
            XCTAssertTrue(diary.upsertWeight(earlier)); XCTAssertEqual(diary.profile.weight, 72)
            XCTAssertTrue(diary.importWeight(69, measuredAt: now, source: "Profile review"))
            XCTAssertFalse(diary.importWeight(80, measuredAt: now.addingTimeInterval(-1800), source: "Older Health sample"))
            XCTAssertTrue(diary.deleteWeight(earlier.id)); XCTAssertEqual(diary.profile.weight, 69)
            XCTAssertEqual(Diary(url: url).profile.weightSource, "Profile review")
        }
    }
    func testDeletingOnlyCurrentWeightLeavesUnset() async {
        await MainActor.run {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("CriticalTests-\(UUID().uuidString)/diary.json")
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let diary = Diary(url: url); let entry = WeightEntry(kilograms: 70)
            XCTAssertTrue(diary.logWeight(entry)); XCTAssertTrue(diary.deleteWeight(entry.id)); XCTAssertNil(diary.profile.weight)
        }
    }
    func testWaterAndPlanEditCopyPreserveIdentities() async {
        await MainActor.run {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("CriticalTests-\(UUID().uuidString)/diary.json")
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let diary = Diary(url: url)
            var water = WaterEntry(date: diary.now, milliliters: 125)
            XCTAssertTrue(diary.upsertWater(water)); water.milliliters = 250
            XCTAssertTrue(diary.upsertWater(water)); XCTAssertEqual(diary.water.count, 1); XCTAssertEqual(diary.water.first?.milliliters, 250)
            var plan = PlannedMeal(date: diary.now, name: "User plan", calories: 200, category: "Lunch")
            XCTAssertTrue(diary.upsertPlan(plan)); plan.calories = 300
            XCTAssertTrue(diary.upsertPlan(plan)); XCTAssertEqual(diary.planned.count, 1)
            XCTAssertTrue(diary.copyPlan(plan.id, to: diary.now.addingTimeInterval(86400)))
            XCTAssertEqual(diary.planned.count, 2); XCTAssertEqual(Set(diary.planned.map(\.id)).count, 2)
            XCTAssertTrue(diary.deleteWater(water.id)); XCTAssertTrue(diary.water.isEmpty)
        }
    }
    func testSharedClockRollsFoodTotalsAndRejectsFutureEntries() async {
        await MainActor.run {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("CriticalTests-\(UUID().uuidString)/diary.json")
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let diary = Diary(url: url); let now = diary.now
            XCTAssertTrue(diary.upsertFood(Food(name: "Logged entry", calories: 100, date: now)))
            XCTAssertFalse(diary.upsertFood(Food(name: "Future entry", calories: 100, date: now.addingTimeInterval(86400))))
            XCTAssertEqual(diary.consumed, 100)
            XCTAssertTrue(diary.updateClock(to: now.addingTimeInterval(86400))); XCTAssertEqual(diary.consumed, 0)
        }
    }
}
