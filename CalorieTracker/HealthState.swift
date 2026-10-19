import Foundation
import Combine

enum HealthMetric: String, CaseIterable, Identifiable {
    case steps, activeEnergy, height, weight
    var id: String { rawValue }
    var title: String { switch self { case .steps: return "Steps"; case .activeEnergy: return "Active energy"; case .height: return "Height"; case .weight: return "Weight" } }
    var unit: String { switch self { case .steps: return "steps"; case .activeEnergy: return "kcal"; case .height: return "cm"; case .weight: return "kg" } }
    var icon: String { switch self { case .steps: return "figure.walk"; case .activeEnergy: return "flame.fill"; case .height: return "ruler"; case .weight: return "scalemass" } }
    var isDaily: Bool { self == .steps || self == .activeEnergy }
}
struct HealthReading {
    let value: Double
    var sampleDate: Date?
    var source: String?
}
enum MetricStatus: String { case notConnected = "Not connected", loading = "Refreshing", available = "Available", noData = "No readable records", failed = "Refresh failed", unavailable = "Unavailable on this device", stale = "Needs refresh" }
struct MetricResult {
    var reading: HealthReading?
    var fetchedAt: Date?
    var queryDay: Date?
    var timeZoneID: String?
    var status: MetricStatus = .notConnected
    var error: String?
    func isFresh(for metric: HealthMetric, now: Date, calendar: Calendar = .current) -> Bool {
        guard status == .available, let fetchedAt, reading != nil else { return false }
        guard now.timeIntervalSince(fetchedAt) >= 0, now.timeIntervalSince(fetchedAt) < 15 * 60 else { return false }
        if metric.isDaily { guard let queryDay, calendar.isDate(queryDay, inSameDayAs: now), timeZoneID == calendar.timeZone.identifier else { return false } }
        return true
    }
}
@MainActor protocol HealthReadingProvider {
    var available: Bool { get }
    func requestAccess() async throws
    func read(_ metric: HealthMetric, now: Date) async throws -> HealthReading?
}
@MainActor final class HealthMonitor: ObservableObject {
    @Published private(set) var results: [HealthMetric: MetricResult] = [:]
    @Published private(set) var busy = false
    @Published private(set) var status = "Connect to Apple Health when you're ready."
    private let provider: HealthReadingProvider
    private let clock: () -> Date
    init(provider: HealthReadingProvider, clock: @escaping () -> Date = Date.init) { self.provider = provider; self.clock = clock }
    func result(_ metric: HealthMetric) -> MetricResult { results[metric] ?? MetricResult() }
    func value(_ metric: HealthMetric) -> Double? { let r = result(metric); return r.isFresh(for: metric, now: clock()) ? r.reading?.value : nil }
    func expireOldResults() {
        for metric in HealthMetric.allCases {
            var r = result(metric)
            if r.status == .available && !r.isFresh(for: metric, now: clock()) { r.status = .stale; results[metric] = r }
        }
    }
    func connect() async {
        guard !busy else { return }
        guard provider.available else { setUnavailable(); return }
        busy = true
        do { try await provider.requestAccess() }
        catch { busy = false; expireOldResults(); status = "Access request failed: \(error.localizedDescription)"; return }
        busy = false
        await refresh()
    }
    func refresh(_ only: HealthMetric? = nil) async {
        guard !busy else { return }
        guard provider.available else { setUnavailable(); return }
        busy = true
        let metrics = only.map { [$0] } ?? HealthMetric.allCases
        let now = clock()
        let timeZoneID = Calendar.current.timeZone.identifier
        for metric in metrics { var r = result(metric); r.status = .loading; r.error = nil; results[metric] = r }
        // Queries run independently: each result is committed as it finishes, even if another fails.
        await withTaskGroup(of: (HealthMetric, HealthReading?, String?).self) { group in
            for metric in metrics {
                group.addTask { @MainActor [provider] in
                    do { return (metric, try await provider.read(metric, now: now), nil) }
                    catch { return (metric, nil, error.localizedDescription) }
                }
            }
            for await (metric, reading, error) in group {
                var r = MetricResult()
                r.fetchedAt = clock(); r.queryDay = now; r.timeZoneID = timeZoneID
                if let error { r.status = .failed; r.error = error }
                else if let reading {
                    if reading.value.isFinite && reading.value >= 0 && (metric.isDaily || reading.value > 0) { r.reading = reading; r.status = .available }
                    else { r.status = .failed; r.error = "Health returned an invalid numeric value." }
                } else { r.status = .noData }
                results[metric] = r
            }
        }
        busy = false; expireOldResults()
        let failures = metrics.filter { result($0).status == .failed }.count
        status = failures > 0 ? "\(failures) metric(s) failed to refresh. Other results are still available." : "Refresh finished. Missing records do not tell us whether read permission was granted."
    }
    private func setUnavailable() {
        for metric in HealthMetric.allCases { results[metric] = MetricResult(status: .unavailable) }
        status = "Apple Health is unavailable on this device. Manual tracking still works."
    }
}
