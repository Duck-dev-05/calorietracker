import Foundation

/// A single background queue serializes expensive journal encoding and file work.
/// Diary holds its main-actor save gate until each operation finishes.
enum JournalIO {
    private static let queue = DispatchQueue(label: "com.personal.CalorieTracker.journal", qos: .userInitiated)
    static func perform<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try work()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
    static func read(_ url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= DiarySnapshot.maxFileSize else {
            throw DiaryFailure.invalid("Choose a regular Nourish JSON file no larger than 10 MB.")
        }
        let data = try Data(contentsOf: url)
        guard data.count <= DiarySnapshot.maxFileSize else { throw DiaryFailure.invalid("The file exceeds 10 MB.") }
        return data
    }
    static func check(_ url: URL, baseline: Data?) throws {
        let current = FileManager.default.fileExists(atPath: url.path) ? try read(url) : nil
        guard current == baseline else { throw DiaryFailure.invalid("The diary file changed outside this session. Reload before retrying; no newer data was overwritten.") }
    }
    struct Outcome {
        var archive: URL?
        var error: Error?
    }
    static func commit(_ data: Data, to url: URL, baseline: Data?, archive: Bool, writer: (Data, URL) throws -> Void) -> Outcome {
        var outcome = Outcome()
        do {
            try check(url, baseline: baseline)
            if archive, let baseline {
                let target = url.deletingLastPathComponent().appendingPathComponent("Recovery", isDirectory: true)
                    .appendingPathComponent("diary-before-replace-\(UUID().uuidString).json")
                try Diary.writeFile(baseline, target)
                outcome.archive = target
            }
            try check(url, baseline: baseline)
            try writer(data, url)
        } catch { outcome.error = error }
        return outcome
    }
}
