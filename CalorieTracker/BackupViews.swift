import SwiftUI
import UniformTypeIdentifiers

struct DiaryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw DiaryFailure.invalid("This is not a readable file.") }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct BackupScreen: View {
    @EnvironmentObject var diary: Diary
    @State private var exporting = false
    @State private var importing = false
    @State private var document = DiaryDocument()
    @State private var preview: DiarySnapshot?
    @State private var selectedName = ""
    @State private var confirmRestore = false
    @State private var message: String?
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Your information", title: "Keep a copy. Keep control.", detail: "Back up your journal to Files, or restore a previous copy.")
            Surface {
                SectionHeading(title: "Export your journal", subtitle: "Profile, targets, foods, saved meals, water, weights and plans")
                ValueRow(title: "Entries on this device", value: "\(diary.snapshot.entryCount)")
                Button { exportCurrent() } label: { Label("Save a backup to Files", systemImage: "square.and.arrow.up") }.buttonStyle(PrimaryAction()).disabled(diary.storageBlocked || !diary.can(.exportJournal))
                Text("Your backup contains personal information and is not encrypted by Nourish. Choose a storage location you trust. App appearance and Health permissions are not included.").font(.footnote).foregroundStyle(.secondary)
            }
            Surface {
                SectionHeading(title: "Restore a backup", subtitle: "Choose a Nourish JSON file, up to 10 MB")
                Button { importing = true } label: { Label("Choose backup", systemImage: "folder") }.buttonStyle(.bordered).disabled(!diary.can(.restoreJournal))
                if let preview {
                    Divider()
                    Text(selectedName).font(.headline).lineLimit(2)
                    ValueRow(title: "Food entries", value: "\(preview.foods.count)")
                    ValueRow(title: "Saved meals", value: "\(preview.savedMeals?.count ?? 0)")
                    ValueRow(title: "Water / weights / plans", value: "\(preview.water?.count ?? 0) / \(preview.weights?.count ?? 0) / \(preview.planned?.count ?? 0)")
                    ValueRow(title: "Dated targets", value: "\(preview.targets?.count ?? 0)")
                    ValueRow(title: "Profile", value: preview.profile.name ?? "Unnamed")
                    Text("Restoring replaces your current journal. A recovery copy of the existing file is saved on this device first; entries are not merged.").font(.footnote).foregroundStyle(.secondary)
                    Button("Replace journal with this backup", role: .destructive) { confirmRestore = true }.buttonStyle(.bordered).disabled(!diary.can(.restoreJournal))
                    Button("Cancel selection") { self.preview = nil }
                }
            }
            if diary.lastArchiveURL != nil {
                Surface {
                    SectionHeading(title: "Before your last replacement")
                    Text("The previous file was preserved on this device. Export it before uninstalling the app.").font(.footnote).foregroundStyle(.secondary)
                    Button("Export previous file") {
                        do { document = DiaryDocument(data: try diary.archivedData()); exporting = true }
                        catch { message = error.localizedDescription }
                    }
                }
            }
            if let message { Surface { Label(message, systemImage: "info.circle").font(.subheadline).accessibilityLabel(message) } }
        }.navigationTitle("Backup & restore").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Nourish-backup-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
            switch result { case .success: message = "File exported successfully."; case .failure(let error): message = "Export failed: \(error.localizedDescription)" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            preview = nil
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= DiarySnapshot.maxFileSize else { throw DiaryFailure.invalid("Choose a backup smaller than 10 MB.") }
                preview = try DiarySnapshot.decode(Data(contentsOf: url))
                selectedName = url.lastPathComponent; message = nil
            } catch { message = "Could not import backup: \(error.localizedDescription)" }
        }
        .alert("Replace your journal?", isPresented: $confirmRestore) {
            Button("Replace journal", role: .destructive) {
                if let preview, diary.replace(with: preview) { self.preview = nil; message = "Your journal was restored. The previous file has been preserved." }
                else { message = diary.storageError }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This replaces the profile and all food, saved meal, water, weight and plan entries. A copy of the existing file is kept first.") }
    }
    private func exportCurrent() {
        do { document = DiaryDocument(data: try diary.backupData()); exporting = true; message = nil }
        catch { message = error.localizedDescription }
    }
}
struct StorageRecoveryScreen: View {
    @EnvironmentObject var diary: Diary
    @State private var exporting = false
    @State private var document = DiaryDocument()
    @State private var confirmReset = false
    @State private var message: String?
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Storage recovery", title: "Let's protect your journal.", detail: "Your saved file couldn't be opened. Editing is paused so it cannot be overwritten.")
            Surface {
                IconTile(icon: "externaldrive.badge.exclamationmark", color: NourishStyle.peach)
                Text(diary.storageError ?? "The file remains preserved on this device.").font(.subheadline)
                Button("Try opening the diary again") { diary.retryLoad() }.buttonStyle(PrimaryAction())
                Text("If your phone was locked, unlock it and retry. This does not change the saved file.").font(.footnote).foregroundStyle(.secondary)
            }
            Surface {
                SectionHeading(title: "Save the original file")
                Text("Export the original bytes for safekeeping, even if the file is damaged.").font(.subheadline).foregroundStyle(.secondary)
                Button { do { document = DiaryDocument(data: try diary.originalData()); exporting = true } catch { message = error.localizedDescription } } label: { Label("Export original file", systemImage: "square.and.arrow.up") }
                Divider()
                NavigationLink(destination: BackupScreen()) { RouteRow(title: "Restore a known backup", subtitle: "Preview a backup before replacing anything", icon: "arrow.counterclockwise") }.buttonStyle(.plain)
            }
            Surface {
                SectionHeading(title: "Start a new journal")
                Text("Use this only if retry and restore cannot help. The original file is archived first. If archiving fails, the journal is not reset.").font(.footnote).foregroundStyle(.secondary)
                Button("Archive original and start fresh", role: .destructive) { confirmReset = true }.disabled(!diary.can(.restoreJournal))
            }
            if let message { Text(message).font(.subheadline).foregroundStyle(.secondary) }
        }.navigationTitle("Recover journal").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Nourish-original-recovery") { result in
            switch result { case .success: message = "Original file exported."; case .failure(let error): message = error.localizedDescription }
        }
        .alert("Start a new journal?", isPresented: $confirmReset) {
            Button("Archive and reset", role: .destructive) { if !diary.resetJournal() { message = diary.storageError } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("The original file will be kept in a recovery copy. Your current profile and journal will be replaced with an empty journal.") }
    }
}
