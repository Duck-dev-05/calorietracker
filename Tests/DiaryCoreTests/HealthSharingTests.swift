import XCTest
@testable import DiaryCore

@MainActor private final class SharingFixture: HealthWritingProvider {
    var available = true
    var requestError = false
    var saveError = false
    var requested: [HealthMetric] = []
    var writes: [HealthMeasurement] = []
    var afterRequest: (() -> Void)?
    func requestWriteAccess(_ metric: HealthMetric) async throws {
        requested.append(metric)
        if requestError { throw DiaryFailure.invalid("Denied") }
        afterRequest?()
    }
    func save(_ measurement: HealthMeasurement) async throws {
        if saveError { throw DiaryFailure.invalid("Save failed") }
        writes.append(measurement)
    }
}
final class HealthSharingTests: XCTestCase {
    func testMeasurementValidationAndStableRetryIdentity() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let value = HealthMeasurement(metric: .height, value: 175, date: date)
        XCTAssertNoThrow(try value.validate())
        XCTAssertEqual(value.syncID, HealthMeasurement(metric: .height, value: 175, date: date).syncID)
        XCTAssertNotEqual(value.syncID, HealthMeasurement(metric: .height, value: 176, date: date).syncID)
        XCTAssertNotEqual(value.syncID, HealthMeasurement(metric: .weight, value: 175, date: date).syncID)
        for metric in [HealthMetric.steps, .activeEnergy] { XCTAssertThrowsError(try HealthMeasurement(metric: metric, value: 100, date: date).validate()) }
        for amount in [Double.nan, .infinity, 0, -1, 401] { XCTAssertThrowsError(try HealthMeasurement(metric: .weight, value: amount, date: date).validate()) }
        XCTAssertThrowsError(try HealthMeasurement(metric: .height, value: 175, date: Date().addingTimeInterval(3600)).validate())
    }
    @MainActor func testWritesOnlyReviewedTypeAndValue() async throws {
        let fixture = SharingFixture(), sample = HealthMeasurement(metric: .weight, value: 70.5, date: Date().addingTimeInterval(-60))
        let controller = HealthSharingController(provider: fixture, authorized: { true })
        try await controller.share(sample)
        XCTAssertEqual(fixture.requested, [.weight]); XCTAssertEqual(fixture.writes, [sample]); XCTAssertFalse(controller.busy)
    }
    @MainActor func testSignedOutCannotRequestOrSave() async {
        let fixture = SharingFixture()
        let controller = HealthSharingController(provider: fixture, authorized: { false })
        do { try await controller.share(HealthMeasurement(metric: .height, value: 170, date: Date())); XCTFail() } catch { }
        XCTAssertTrue(fixture.requested.isEmpty); XCTAssertTrue(fixture.writes.isEmpty)
    }
    @MainActor func testDeniedAndUnavailableNeverWrite() async {
        let fixture = SharingFixture()
        let controller = HealthSharingController(provider: fixture, authorized: { true })
        fixture.requestError = true
        do { try await controller.share(HealthMeasurement(metric: .height, value: 170, date: Date())); XCTFail() } catch { }
        XCTAssertTrue(fixture.writes.isEmpty); XCTAssertFalse(controller.busy)
        fixture.available = false
        do { try await controller.share(HealthMeasurement(metric: .height, value: 170, date: Date())); XCTFail() } catch { }
        XCTAssertEqual(fixture.requested.count, 1)
    }
    @MainActor func testLogoutDuringPermissionPromptStopsSave() async {
        let fixture = SharingFixture()
        var authenticated = true
        let controller = HealthSharingController(provider: fixture, authorized: { authenticated })
        fixture.afterRequest = { authenticated = false }
        do { try await controller.share(HealthMeasurement(metric: .weight, value: 70, date: Date())); XCTFail() } catch { }
        XCTAssertTrue(fixture.writes.isEmpty); XCTAssertFalse(controller.busy)
    }
    @MainActor func testSaveFailurePropagatesAndRetryRemainsAvailable() async throws {
        let fixture = SharingFixture()
        let controller = HealthSharingController(provider: fixture, authorized: { true })
        let sample = HealthMeasurement(metric: .weight, value: 70, date: Date())
        fixture.saveError = true
        do { try await controller.share(sample); XCTFail() } catch { }
        XCTAssertFalse(controller.busy); XCTAssertTrue(fixture.writes.isEmpty)
        fixture.saveError = false
        try await controller.share(sample)
        XCTAssertEqual(fixture.writes, [sample])
    }
}
