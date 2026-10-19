import Foundation
import Combine

struct DiarySnapshot: Codable {
    var schemaVersion: Int? = 3
    var ownerAccountID: String? = nil
    var profile: Profile
    var foods: [Food]
    var water: [WaterEntry]? = []
    var weights: [WeightEntry]? = []
    var planned: [PlannedMeal]? = []
    var savedMeals: [Meal]? = []
    static var empty: DiarySnapshot { DiarySnapshot(profile: Profile(), foods: []) }
    static let maxFileSize = 10 * 1024 * 1024
    var entryCount: Int {
        let counts: [Int] = [foods.count, water?.count ?? 0, weights?.count ?? 0, planned?.count ?? 0, savedMeals?.count ?? 0]
        return counts.reduce(0, +)
    }
    func validated() throws -> DiarySnapshot {
        guard schemaVersion == nil || schemaVersion == 1 || schemaVersion == 2 || schemaVersion == 3 else { throw DiaryFailure.invalid("This backup uses a newer, unsupported format.") }
        if let ownerAccountID, ownerAccountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ownerAccountID.count > 300 { throw DiaryFailure.invalid("Invalid journal owner identifier.") }
        for (value, range) in [(profile.height, 80.0...250.0), (profile.weight, 20.0...400.0), (profile.target, 500.0...10000.0)] {
            if let value, !value.isFinite || !range.contains(value) { throw DiaryFailure.invalid("A measurement or calorie target is outside the supported input range.") }
        }
        guard (profile.name?.count ?? 0) <= 200 else { throw DiaryFailure.invalid("Keep your name under 200 characters.") }

        if let age = profile.age, !(1...120).contains(age) { throw DiaryFailure.invalid("Age must be a whole number from 1 to 120, or left blank.") }
        if let weight = profile.goalWeight, !weight.isFinite || !(20...400).contains(weight) { throw DiaryFailure.invalid("Goal weight must be between 20 and 400 kg, or left blank.") }
        guard (profile.activityLevel?.count ?? 0) <= 80, (profile.goalNote?.count ?? 0) <= 500,
              (profile.excludedIngredients?.count ?? 0) <= 20,
              (profile.excludedIngredients ?? []).allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 50 }) else { throw DiaryFailure.invalid("Keep your goal note under 500 characters and ingredient exclusions to 20 short terms.") }
        guard entryCount <= 100_000 else { throw DiaryFailure.invalid("The backup contains too many entries.") }
        let categories = ["Breakfast", "Lunch", "Dinner", "Snacks"]
        func validName(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 500 }
        func validDate(_ value: Date) -> Bool { value.timeIntervalSinceReferenceDate.isFinite && value >= Date(timeIntervalSince1970: 0) && value < Date(timeIntervalSince1970: 4_102_444_800) }
        if let measured = profile.weightMeasuredAt, !validDate(measured) { throw DiaryFailure.invalid("The current weight has an invalid measurement date.") }
        guard (profile.weightSource?.count ?? 0) <= 300, (weights ?? []).allSatisfy({ ($0.source?.count ?? 0) <= 300 }) else { throw DiaryFailure.invalid("A measurement source is too long.") }

        guard foods.allSatisfy({ validName($0.name) && (1...10000).contains($0.calories) && validDate($0.date) && ($0.category == nil || categories.contains($0.category!)) }),
              (water ?? []).allSatisfy({ (1...10000).contains($0.milliliters) && validDate($0.date) }),
              (weights ?? []).allSatisfy({ $0.kilograms.isFinite && (20...400).contains($0.kilograms) && validDate($0.date) }),
              (planned ?? []).allSatisfy({ validName($0.name) && (1...10000).contains($0.calories) && categories.contains($0.category) && validDate($0.date) }) else { throw DiaryFailure.invalid("The file contains an invalid entry, amount, date or meal category.") }
        guard Set(foods.map(\.id)).count == foods.count, Set((water ?? []).map(\.id)).count == (water ?? []).count, Set((weights ?? []).map(\.id)).count == (weights ?? []).count, Set((planned ?? []).map(\.id)).count == (planned ?? []).count else { throw DiaryFailure.invalid("The backup contains duplicate entry identifiers.") }
        guard (savedMeals ?? []).allSatisfy({ validName($0.name) && !$0.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.detail.count <= 2000 && (1...10000).contains($0.calories) }), Set((savedMeals ?? []).map(\.id)).count == (savedMeals ?? []).count else { throw DiaryFailure.invalid("A saved meal contains invalid details, calories or duplicate identifiers.") }
        for food in foods { try food.nutrition?.validate(calories: food.calories) }
        for meal in savedMeals ?? [] { try meal.nutrition?.validate(calories: meal.calories) }
        for plan in planned ?? [] { try plan.nutrition?.validate(calories: plan.calories) }
        var result = self
        result.schemaVersion = 3; result.water = water ?? []; result.weights = weights ?? []; result.planned = planned ?? []; result.savedMeals = savedMeals ?? []
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
    @Published private var storedSnapshot: DiarySnapshot = .empty
    private let account: AccountStore
    private var accessSubscription: AnyCancellable?
    var snapshot: DiarySnapshot { can(.readJournal) ? storedSnapshot : .empty }
    var canReadJournal: Bool { can(.readJournal) }
    func can(_ permission: AppPermission) -> Bool { account.allows(permission, ownerAccountID: storedSnapshot.ownerAccountID) }
    private func require(_ permission: AppPermission) throws { try account.require(permission, ownerAccountID: storedSnapshot.ownerAccountID) }
    @Published private(set) var now = Date()
    private var timeZoneID = TimeZone.current.identifier
    @Published var storageError: String?
    @Published private(set) var storageBlocked = false
    @Published private(set) var lastArchiveURL: URL?
    private var diskBaseline: Data?
    private var migrationPending = false
    private var externalConflict = false
    private let url: URL
    private let writer: (Data, URL) throws -> Void
    // Computed bindings preserve current UI while all writes use a validated candidate snapshot.
    var savedMeals: [Meal] { snapshot.savedMeals ?? [] }
    var profile: Profile { get { snapshot.profile } set { _ = transaction { $0.profile = newValue } } }
    var foods: [Food] { get { snapshot.foods } set { _ = transaction { $0.foods = newValue } } }
    var water: [WaterEntry] { get { snapshot.water ?? [] } set { _ = transaction { $0.water = newValue } } }
    var weights: [WeightEntry] { get { snapshot.weights ?? [] } set { _ = transaction { $0.weights = newValue } } }
    var planned: [PlannedMeal] { get { snapshot.planned ?? [] } set { _ = transaction { $0.planned = newValue } } }
    init(url: URL? = nil, account: AccountStore? = nil, writer: @escaping (Data, URL) throws -> Void = Diary.writeFile) {
        self.account = account ?? AccountStore(provider: UnconfiguredAccountProvider())
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("diary.json")
        self.writer = writer
        accessSubscription = self.account.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
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
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try readDisk()
                let loaded = try DiarySnapshot.decode(data)
                let version = try JSONDecoder().decode(DiarySnapshot.self, from: data).schemaVersion
                storedSnapshot = loaded; diskBaseline = data; migrationPending = version != 3
            } else { storedSnapshot = .empty; diskBaseline = nil; migrationPending = false }
            storageBlocked = false; externalConflict = false; storageError = nil
        } catch { storageBlocked = true; storageError = "Your diary could not be opened. The original file is preserved. \(error.localizedDescription)" }
    }
    @discardableResult func transaction(_ change: (inout DiarySnapshot) throws -> Void) -> Bool {
        guard !storageBlocked else { storageError = "Storage is locked. Open recovery to restore access before saving."; return false }
        do {
            try require(.editJournal)
            var candidate = storedSnapshot
            try change(&candidate)
            guard candidate.ownerAccountID == storedSnapshot.ownerAccountID else { throw DiaryFailure.invalid("Journal ownership cannot be changed by an edit or role claim.") }
            candidate = try candidate.validated()
            let data = try candidate.encoded()
            try verifyDiskBaseline()
            if migrationPending { try archiveOriginal() }
            try writer(data, url)
            diskBaseline = data; migrationPending = false
            storedSnapshot = candidate; storageError = nil
            return true
        } catch { storageError = "Changes were not saved. \(error.localizedDescription)"; return false }
    }
    @discardableResult func upsertFood(_ food: Food) -> Bool {
        guard food.date <= now.addingTimeInterval(60) else { storageError = "Food cannot be logged in the future."; return false }
        return transaction { saved in
            if let index = saved.foods.firstIndex(where: { $0.id == food.id }) { saved.foods[index] = food }
            else { saved.foods.append(food) }
        }
    }
    @discardableResult func deleteFood(_ id: UUID) -> Bool { transaction { $0.foods.removeAll { $0.id == id } } }
    @discardableResult func consumePlan(_ id: UUID) -> Bool {
        // A second tap after a committed transfer is a no-op.
        guard let meal = planned.first(where: { $0.id == id }) else { return true }
        guard Calendar.current.startOfDay(for: meal.date) <= Calendar.current.startOfDay(for: now) else { storageError = "Future meals cannot be marked as eaten."; return false }
        return transaction {
            let date = Calendar.current.isDate(meal.date, inSameDayAs: now) ? now : Calendar.current.startOfDay(for: meal.date)
            $0.foods.append(Food(name: meal.name, calories: meal.calories, date: date, category: meal.category, nutrition: meal.nutrition))
            $0.planned?.removeAll { $0.id == id }
        }
    }
    @discardableResult func logWeight(_ entry: WeightEntry) -> Bool { upsertWeight(entry) }
    @discardableResult func upsertWeight(_ entry: WeightEntry) -> Bool {
        guard entry.date <= now.addingTimeInterval(60) else { storageError = "A weight measurement cannot be in the future."; return false }
        return transaction { saved in
            let old = (saved.weights ?? []).first { $0.id == entry.id }
            let wasCurrent = old?.id == saved.profile.weightEntryID && old != nil
            var entries = saved.weights ?? []
            if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = entry } else { entries.append(entry) }
            saved.weights = entries
            if wasCurrent { saved.profile.weight = nil; saved.profile.weightMeasuredAt = nil; saved.profile.weightSource = nil; saved.profile.weightEntryID = nil }
            Self.reconcileWeight(&saved)
        }
    }
    @discardableResult func deleteWeight(_ id: UUID) -> Bool {
        transaction { saved in
            let old = (saved.weights ?? []).first { $0.id == id }
            let wasCurrent = old?.id == saved.profile.weightEntryID && old != nil
            saved.weights?.removeAll { $0.id == id }
            if wasCurrent { saved.profile.weight = nil; saved.profile.weightMeasuredAt = nil; saved.profile.weightSource = nil; saved.profile.weightEntryID = nil }
            Self.reconcileWeight(&saved)
        }
    }
    private static func reconcileWeight(_ saved: inout DiarySnapshot) {
        guard let latest = (saved.weights ?? []).max(by: { $0.date < $1.date }) else { return }
        // Unknown legacy provenance is replaced only after an explicit history operation.
        if latest.date >= (saved.profile.weightMeasuredAt ?? .distantPast) {
            saved.profile.weight = latest.kilograms; saved.profile.weightMeasuredAt = latest.date; saved.profile.weightSource = latest.source ?? "Manual weight log"; saved.profile.weightEntryID = latest.id
        }
    }
    @discardableResult func importWeight(_ value: Double, measuredAt date: Date, source: String) -> Bool {
        guard date <= now.addingTimeInterval(60) else { storageError = "The measurement has a future date."; return false }
        if let current = profile.weightMeasuredAt, date < current { storageError = "This Health measurement is older than your current profile measurement. Your current value was kept."; return false }
        return transaction { $0.profile.weight = value; $0.profile.weightMeasuredAt = date; $0.profile.weightSource = source; $0.profile.weightEntryID = nil }
    }
    @discardableResult func updateClock(to newNow: Date = Date(), calendar: Calendar = .current) -> Bool {
        let changed = !calendar.isDate(now, inSameDayAs: newNow) || timeZoneID != calendar.timeZone.identifier
        timeZoneID = calendar.timeZone.identifier; now = newNow
        return changed
    }
    @discardableResult func upsertWater(_ entry: WaterEntry) -> Bool {
        guard entry.date <= now.addingTimeInterval(60) else { storageError = "Water cannot be logged in the future."; return false }
        return transaction { saved in
            var entries = saved.water ?? []
            if let i = entries.firstIndex(where: { $0.id == entry.id }) { entries[i] = entry } else { entries.append(entry) }
            saved.water = entries
        }
    }
    @discardableResult func deleteWater(_ id: UUID) -> Bool { transaction { $0.water?.removeAll { $0.id == id } } }
    @discardableResult func upsertPlan(_ plan: PlannedMeal) -> Bool {
        transaction { saved in
            var plans = saved.planned ?? []
            if let i = plans.firstIndex(where: { $0.id == plan.id }) { plans[i] = plan } else { plans.append(plan) }
            saved.planned = plans
        }
    }
    @discardableResult func deletePlan(_ id: UUID) -> Bool { transaction { $0.planned?.removeAll { $0.id == id } } }
    @discardableResult func copyPlan(_ id: UUID, to date: Date) -> Bool {
        guard var plan = planned.first(where: { $0.id == id }) else { storageError = "This plan no longer exists."; return false }
        plan.id = UUID(); plan.date = date
        return upsertPlan(plan)
    }
    /// Optimistic concurrency guard: never overwrite bytes changed since load/save.
    private func readDisk() throws -> Data {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= DiarySnapshot.maxFileSize else { throw DiaryFailure.invalid("The diary exceeds the 10 MB limit. Preserve/export the original file before recovery.") }
        return try Data(contentsOf: url)
    }
    private func verifyDiskBaseline() throws {
        let current = FileManager.default.fileExists(atPath: url.path) ? try readDisk() : nil
        guard current == diskBaseline else {
            storageBlocked = true; externalConflict = true
            throw DiaryFailure.invalid("The diary file changed outside this session. Your changes were not written. Reopen/reload the diary before retrying.")
        }
    }
    @discardableResult func logMeal(_ id: UUID, servings: Double, category: String, plannedDate: Date? = nil) -> Bool {
        do {
            guard let meal = savedMeals.first(where: { $0.id == id }) else { throw DiaryFailure.invalid("This saved meal no longer exists.") }
            let nutrition = try meal.portion(servings)
            let calories = try nutrition.roundedCalories()
            if let date = plannedDate { return upsertPlan(PlannedMeal(date: date, name: meal.name, calories: calories, category: category, nutrition: nutrition)) }
            return upsertFood(Food(name: meal.name, calories: calories, date: now, category: category, nutrition: nutrition))
        } catch { storageError = error.localizedDescription; return false }
    }
    func backupData() throws -> Data { try require(.exportJournal); guard !storageBlocked else { throw DiaryFailure.invalid("Export the original file from recovery instead.") }; return try snapshot.encoded() }
    private func authorizeFileExport(_ data: Data) throws {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let owner = object["ownerAccountID"], !(owner is NSNull) {
                guard let owner = owner as? String else { throw AccessDenied(permission: .exportJournal) }
                try account.require(.exportJournal, ownerAccountID: owner)
            } else { try account.require(.exportJournal, ownerAccountID: nil) }
        } else if account.session != nil { throw AccessDenied(permission: .exportJournal) }
        // Damaged non-JSON local files remain recoverable by this device's local owner.
    }
    func originalData() throws -> Data {
        try require(.exportJournal)
        let data = try Data(contentsOf: url)
        try authorizeFileExport(data)
        return data
    }
    func archivedData() throws -> Data {
        try require(.exportJournal)
        guard let url = lastArchiveURL else { throw DiaryFailure.invalid("No recovery file is available.") }
        let data = try Data(contentsOf: url)
        // Archives may belong to a different owner; never assume current ownership.
        try authorizeFileExport(data)
        return data
    }
    private func archiveOriginal() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let archive = url.deletingLastPathComponent().appendingPathComponent("Recovery", isDirectory: true).appendingPathComponent("diary-before-replace-\(UUID().uuidString).json")
        try Self.writeFile(Data(contentsOf: url), archive)
        lastArchiveURL = archive
    }
    @discardableResult func resetJournal() -> Bool {
        var empty = DiarySnapshot.empty
        empty.ownerAccountID = storedSnapshot.ownerAccountID
        return replace(with: empty)
    }
    @discardableResult func replace(with replacement: DiarySnapshot) -> Bool {
        do {
            try require(.restoreJournal)
            guard replacement.ownerAccountID == storedSnapshot.ownerAccountID else { throw DiaryFailure.invalid("This backup belongs to a different journal owner. Account-data adoption is not enabled.") }
            guard !externalConflict else { throw DiaryFailure.invalid("Reload the changed diary before replacing it. Your newer file has been preserved.") }
            let candidate = try replacement.validated()
            let data = try candidate.encoded()
            // If preserving the old bytes fails, do not replace the active diary.
            // Recovery may deliberately replace a damaged file. Normal restore must
            // still protect external changes since the last successful load.
            if !storageBlocked { try verifyDiskBaseline() }
            try archiveOriginal()
            try writer(data, url)
            diskBaseline = data; migrationPending = false
            storedSnapshot = candidate; storageBlocked = false; externalConflict = false; storageError = nil
            return true
        } catch { storageError = "Diary was not replaced. \(error.localizedDescription)"; return false }
    }
    var today: [Food] { foods.filter { Calendar.current.isDate($0.date, inSameDayAs: now) } }
    var consumed: Int { today.reduce(0) { $0 + $1.calories } }
    var remaining: Int? { profile.target.map { Int($0) - consumed } }
}
