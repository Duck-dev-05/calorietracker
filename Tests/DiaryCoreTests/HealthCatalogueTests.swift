import XCTest
@testable import DiaryCore

final class HealthCatalogueTests: XCTestCase {
    func testDayQueriesRespectDaylightSavingAndStopAtNow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let later = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: day))
        let window = try HealthBrowseWindow(day: day, now: later, calendar: calendar)
        XCTAssertEqual(window.end.timeIntervalSince(try XCTUnwrap(window.start)), 23 * 3600)
        let current = try HealthBrowseWindow(day: day, now: day, calendar: calendar)
        XCTAssertEqual(current.end, day)
        XCTAssertThrowsError(try HealthBrowseWindow(day: later, now: day, calendar: calendar))
        let latest = try HealthBrowseWindow(day: nil, now: day, calendar: calendar)
        XCTAssertNil(latest.start); XCTAssertEqual(latest.end, day)
    }
    func testMissingRecordsAreNotRepresentedAsZero() {
        let result = HealthBrowseResult()
        XCTAssertTrue(result.records.isEmpty)
        XCTAssertNil(result.error)
        let failure = HealthBrowseResult(error: "Restricted or unavailable")
        XCTAssertTrue(failure.records.isEmpty)
        XCTAssertNotNil(failure.error)
    }
}
