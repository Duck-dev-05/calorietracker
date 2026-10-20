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
    @State private var previewRevision: UUID?
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
            NavigationLink(destination: RecoveryArchivesScreen()) {
                Surface { RouteRow(title: "Recovery copies", subtitle: "Browse, export or review preserved journals", icon: "clock.arrow.circlepath") }
            }.buttonStyle(.plain)
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
                previewRevision = diary.revision
                selectedName = url.lastPathComponent; message = nil
            } catch { message = "Could not import backup: \(error.localizedDescription)" }
        }
        .alert("Replace your journal?", isPresented: $confirmRestore) {
            Button("Replace journal", role: .destructive) {
                if let preview, diary.replace(with: preview, expectedRevision: previewRevision) { self.preview = nil; message = "Your journal was restored. The previous file has been preserved." }
                else { message = diary.storageError }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This replaces the profile, dated targets and all food, saved meal, water, weight and plan entries. A copy of the existing file is kept first.") }
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


struct RecoveryArchivesScreen: View {
    @EnvironmentObject var diary: Diary
    @State private var files: [URL] = []
    @State private var message: String?
    @State private var document = DiaryDocument()
    @State private var exporting = false
    @State private var preview: DiarySnapshot?
    @State private var previewRevision: UUID?
    @State private var selectedName = ""
    @State private var confirming = false
    var body: some View {
        List {
            Section {
                Text("Copies are preserved before migration, restore or reset. They remain on this device; export important copies before uninstalling. Accounts, passwords and Apple Health records are not journal backups.")
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
            }
            if let preview {
                Section("Restore preview") {
                    Text(selectedName).font(.caption)
                    ValueRow(title: "Journal entries", value: "\(preview.entryCount)")
                    ValueRow(title: "Food / saved meals", value: "\(preview.foods.count) / \(preview.savedMeals?.count ?? 0)")
                    ValueRow(title: "Dated targets", value: "\(preview.targets?.count ?? 0)")
                    Text("Replaces the current journal after preserving another recovery copy. No entries are merged.")
                        .font(.footnote)
                    Button("Restore reviewed copy", role: .destructive) { confirming = true }
                    Button("Cancel preview") { self.preview = nil }
                }
            }
            Section("Preserved files") {
                if files.isEmpty { Text("No recovery copies yet.").foregroundStyle(.secondary) }
                ForEach(files, id: \.lastPathComponent) { file in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(file.lastPathComponent).font(.caption).fixedSize(horizontal: false, vertical: true)
                        if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) {
                            if let date = values.contentModificationDate { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline) }
                            if let size = values.fileSize { Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)).font(.caption).foregroundStyle(.secondary) }
                        }
                        Button("Export original bytes") {
                            do { document = DiaryDocument(data: try diary.recoveryData(named: file.lastPathComponent)); exporting = true }
                            catch { message = error.localizedDescription }
                        }
                        Button("Review for restore") {
                            self.preview = nil
                            do {
                                preview = try DiarySnapshot.decode(diary.recoveryData(named: file.lastPathComponent))
                                previewRevision = diary.revision; selectedName = file.lastPathComponent; message = nil
                            } catch { message = "This copy cannot be restored: \(error.localizedDescription) You can still export its original bytes." }
                        }
                    }.padding(.vertical, 4)
                }
            }
            if let message { Section { Text(message).font(.footnote).fixedSize(horizontal: false, vertical: true) } }
        }
        .navigationTitle("Recovery copies").navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Nourish-recovery-copy") { result in
            switch result { case .success: message = "Recovery copy exported."; case .failure(let error): message = error.localizedDescription }
        }
        .alert("Replace your journal?", isPresented: $confirming) {
            Button("Restore copy", role: .destructive) {
                if let preview, diary.replace(with: preview, expectedRevision: previewRevision) {
                    self.preview = nil; message = "Restored. The previous journal was preserved."; reload()
                } else { message = diary.storageError }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("The reviewed copy will replace all profile and journal data, including targets. Your existing file is archived first.") }
    }
    private func reload() {
        do { files = try diary.recoveryFiles() } catch { message = error.localizedDescription }
    }
}
