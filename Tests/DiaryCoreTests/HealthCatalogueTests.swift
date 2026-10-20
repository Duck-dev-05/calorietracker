import XCTest
@testable import DiaryCore

final class HealthCatalogueTests: XCTestCase {
    func testCatalogueHasUniqueIDsAndCompleteGroups() {
        XCTAssertEqual(HealthDataKind.allCases.count, 26)
        XCTAssertEqual(Set(HealthDataKind.allCases.map(\.id)).count, 26)
        for kind in HealthDataKind.allCases {
            XCTAssertFalse(kind.title.isEmpty)
            XCTAssertTrue(HealthDataKind.groups.contains(kind.group))
        }
        for group in HealthDataKind.groups { XCTAssertTrue(HealthDataKind.allCases.contains { $0.group == group }) }
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
