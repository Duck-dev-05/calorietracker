import Foundation
import Combine

struct DiarySnapshot: Codable {
    var schemaVersion: Int? = 1
    var profile: Profile
    var foods: [Food]
    var water: [WaterEntry]? = []
    var weights: [WeightEntry]? = []
    var planned: [PlannedMeal]? = []
    static var empty: DiarySnapshot { DiarySnapshot(profile: Profile(), foods: []) }
    static let maxFileSize = 10 * 1024 * 1024
    var entryCount: Int { foods.count + (water?.count ?? 0) + (weights?.count ?? 0) + (planned?.count ?? 0) }
    func validated() throws -> DiarySnapshot {
        guard schemaVersion == nil || schemaVersion == 1 else { throw DiaryFailure.invalid("This backup uses a newer, unsupported format.") }
        guard profile.height.isFinite, (80...250).contains(profile.height), profile.weight.isFinite, (20...400).contains(profile.weight), profile.target.isFinite, (500...10000).contains(profile.target), (profile.name?.count ?? 0) <= 200 else { throw DiaryFailure.invalid("The profile contains invalid measurements or a calorie target outside 500–10,000.") }
        guard entryCount <= 100_000 else { throw DiaryFailure.invalid("The backup contains too many entries.") }
        let categories = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        func validName(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 500 }
        func validDate(_ value: Date) -> Bool { value.timeIntervalSinceReferenceDate.isFinite && value >= Date(timeIntervalSince1970: 0) && value < Date(timeIntervalSince1970: 4_102_444_800) }
        guard foods.allSatisfy({ validName($0.name) && (1...10000).contains($0.calories) && validDate($0.date) && ($0.category == nil || categories.contains($0.category!)) }),
              (water ?? []).allSatisfy({ (1...10000).contains($0.milliliters) && validDate($0.date) }),
              (weights ?? []).allSatisfy({ $0.kilograms.isFinite && (20...400).contains($0.kilograms) && validDate($0.date) }),
              (planned ?? []).allSatisfy({ validName($0.name) && (1...10000).contains($0.calories) && categories.contains($0.category) && validDate($0.date) }) else { throw DiaryFailure.invalid("The file contains an invalid entry, amount, date or meal category.") }
        guard Set(foods.map(\.id)).count == foods.count, Set((water ?? []).map(\.id)).count == (water ?? []).count, Set((weights ?? []).map(\.id)).count == (weights ?? []).count, Set((planned ?? []).map(\.id)).count == (planned ?? []).count else { throw DiaryFailure.invalid("The backup contains duplicate entry identifiers.") }
        var result = self
        result.schemaVersion = 1; result.water = water ?? []; result.weights = weights ?? []; result.planned = planned ?? []
        return result
    }
    static func decode(_ data: Data) throws -> DiarySnapshot {
        guard data.count <= maxFileSize else { throw DiaryFailure.invalid("Choose a backup smaller than 10 MB.") }
        return try JSONDecoder().decode(Self.self, from: data).validated()
    }
    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(try validated())
        guard data.count <= Self.maxFileSize else { throw DiaryFailure.invalid("Your diary exceeds this version's 10 MB storage limit. Export your current backup before adding more entries.") }
        return data
    }
}
enum DiaryFailure: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): return message } }
}

@MainActor final class Diary: ObservableObject {
    @Published private(set) var snapshot: DiarySnapshot = .empty
    @Published var storageError: String?
    @Published private(set) var storageBlocked = false
    @Published private(set) var lastArchiveURL: URL?
    private let url: URL
    private let writer: (Data, URL) throws -> Void
    // Computed bindings preserve current UI while all writes use a validated candidate snapshot.
    var profile: Profile { get { snapshot.profile } set { _ = transaction { $0.profile = newValue } } }
    var foods: [Food] { get { snapshot.foods } set { _ = transaction { $0.foods = newValue } } }
    var water: [WaterEntry] { get { snapshot.water ?? [] } set { _ = transaction { $0.water = newValue } } }
    var weights: [WeightEntry] { get { snapshot.weights ?? [] } set { _ = transaction { $0.weights = newValue } } }
    var planned: [PlannedMeal] { get { snapshot.planned ?? [] } set { _ = transaction { $0.planned = newValue } } }
    init(url: URL? = nil, writer: @escaping (Data, URL) throws -> Void = Diary.writeFile) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("diary.json")
        self.writer = writer
        retryLoad()
        let directory = self.url.deletingLastPathComponent().appendingPathComponent("Recovery", isDirectory: true)
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) {
            lastArchiveURL = files.filter { $0.pathExtension == "json" }.max {
                ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
            }
        }
    }
    nonisolated static func writeFile(_ data: Data, _ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
    func retryLoad() {
        do {
            if FileManager.default.fileExists(atPath: url.path) { snapshot = try DiarySnapshot.decode(Data(contentsOf: url)) }
            else { snapshot = .empty }
            storageBlocked = false; storageError = nil
        } catch { storageBlocked = true; storageError = "Your diary could not be opened. The original file is preserved. \(error.localizedDescription)" }
    }
    @discardableResult func transaction(_ change: (inout DiarySnapshot) throws -> Void) -> Bool {
        guard !storageBlocked else { storageError = "Storage is locked. Open recovery to restore access before saving."; return false }
        do {
            var candidate = snapshot
            try change(&candidate)
            candidate = try candidate.validated()
            try writer(candidate.encoded(), url)
            snapshot = candidate; storageError = nil
            return true
        } catch { storageError = "Changes were not saved. \(error.localizedDescription)"; return false }
    }
    @discardableResult func upsertFood(_ food: Food) -> Bool {
        transaction { saved in
            if let index = saved.foods.firstIndex(where: { $0.id == food.id }) { saved.foods[index] = food }
            else { saved.foods.append(food) }
        }
    }
    @discardableResult func deleteFood(_ id: UUID) -> Bool { transaction { $0.foods.removeAll { $0.id == id } } }
    @discardableResult func consumePlan(_ id: UUID) -> Bool {
        // A second tap after a committed transfer is a no-op.
        guard let meal = planned.first(where: { $0.id == id }) else { return true }
        guard Calendar.current.startOfDay(for: meal.date) <= Calendar.current.startOfDay(for: Date()) else { storageError = "Future meals cannot be marked as eaten."; return false }
        return transaction {
            let date = Calendar.current.isDateInToday(meal.date) ? Date() : Calendar.current.startOfDay(for: meal.date)
            $0.foods.append(Food(name: meal.name, calories: meal.calories, date: date, category: meal.category))
            $0.planned?.removeAll { $0.id == id }
        }
    }
    @discardableResult func logWeight(_ entry: WeightEntry) -> Bool {
        transaction {
            if entry.date >= (($0.weights ?? []).map(\.date).max() ?? .distantPast) { $0.profile.weight = entry.kilograms }
            $0.weights = ($0.weights ?? []) + [entry]
        }
    }
    func backupData() throws -> Data { guard !storageBlocked else { throw DiaryFailure.invalid("Export the original file from recovery instead.") }; return try snapshot.encoded() }
    func originalData() throws -> Data { try Data(contentsOf: url) }
    private func archiveOriginal() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let archive = url.deletingLastPathComponent().appendingPathComponent("Recovery", isDirectory: true).appendingPathComponent("diary-before-replace-\(UUID().uuidString).json")
        try Self.writeFile(Data(contentsOf: url), archive)
        lastArchiveURL = archive
    }
    @discardableResult func replace(with replacement: DiarySnapshot) -> Bool {
        do {
            let candidate = try replacement.validated()
            let data = try candidate.encoded()
            // If preserving the old bytes fails, do not replace the active diary.
            try archiveOriginal()
            try writer(data, url)
            snapshot = candidate; storageBlocked = false; storageError = nil
            return true
        } catch { storageError = "Diary was not replaced. \(error.localizedDescription)"; return false }
    }
    var today: [Food] { foods.filter { Calendar.current.isDateInToday($0.date) } }
    var consumed: Int { today.reduce(0) { $0 + $1.calories } }
    var remaining: Int { Int(profile.target) - consumed }
}
