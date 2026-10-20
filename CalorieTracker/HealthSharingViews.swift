import SwiftUI

/// Local profile commit precedes independent, reviewed Health writes.
struct CombinedMeasurementsScreen: View {
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var health: HealthService
    @Environment(\.dismiss) private var dismiss
    @State private var includeHeight = true
    @State private var includeWeight = true
    @State private var height = ""
    @State private var weight = ""
    @State private var heightDate = Date()
    @State private var weightDate = Date()
    @State private var shareToHealth = false
    @State private var loaded = false
    @State private var reviewing = false
    @State private var busy = false
    @State private var localSaved = false
    @State private var reviewed: [HealthMeasurement] = []
    @State private var completed: Set<String> = []
    @State private var errors: [String: String] = [:]
    @State private var localError: String?
    @State private var originalHeight: Double?
    @State private var originalWeight: Double?
    @State private var originalWeightDate: Date?
    private var draft: [HealthMeasurement]? {
        var values: [HealthMeasurement] = []
        if includeHeight {
            guard let value = height == originalHeight.map(NutritionDraft.text) ? originalHeight : NutritionDraft.number(height) else { return nil }
            values.append(HealthMeasurement(metric: .height, value: value, date: heightDate))
        }
        if includeWeight {
            guard let value = weight == originalWeight.map(NutritionDraft.text) ? originalWeight : NutritionDraft.number(weight) else { return nil }
            values.append(HealthMeasurement(metric: .weight, value: value, date: weightDate))
        }
        guard !values.isEmpty, values.allSatisfy({ (try? $0.validate()) != nil }) else { return nil }
        return values
    }
    private var allShared: Bool { !reviewed.isEmpty && reviewed.allSatisfy { completed.contains($0.syncID) } }
    var body: some View {
        Form {
            Section {
                Toggle("Include height", isOn: $includeHeight)
                if includeHeight {
                    NumberDraftField(title: "Height (cm)", text: $height, range: 80...250, placeholder: "Enter height")
                    DatePicker("Height measured", selection: $heightDate, in: ...Date())
                }
                Toggle("Include weight", isOn: $includeWeight)
                if includeWeight {
                    NumberDraftField(title: "Weight (kg)", text: $weight, range: 20...400, placeholder: "Enter weight")
                    DatePicker("Weight measured", selection: $weightDate, in: ...Date())
                }
            } header: { Text("Measurements") } footer: {
                Text("Starts with your saved profile. Confirm each value and its actual measurement date. Unselected measurements stay unchanged.")
            }.disabled(localSaved || busy)
            Section {
                Toggle("Also save to Apple Health", isOn: $shareToHealth).disabled(localSaved || busy)
                Text("Your profile is saved locally first. If enabled, each measurement is then added to Apple Health under Nourish after write permission is granted. Existing Health records and Medical ID stay unchanged.")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Weight updates your current profile measurement; it does not create a separate Progress log. The height date is used for Health sharing, not stored in your local profile.")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let localError { Section { Label(localError, systemImage: "exclamationmark.triangle").foregroundStyle(.red) } }
            if localSaved {
                Section("Results") {
                    Label("Selected measurements saved in Nourish", systemImage: "checkmark.circle.fill")
                    if shareToHealth {
                        ForEach(reviewed, id: \.syncID) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Label("\(item.metric.title): \(completed.contains(item.syncID) ? "Saved to Apple Health" : "Not saved to Apple Health")",
                                      systemImage: completed.contains(item.syncID) ? "checkmark.circle" : "exclamationmark.circle")
                                if let error = errors[item.syncID] { Text(error).font(.caption).foregroundStyle(.red) }
                            }.fixedSize(horizontal: false, vertical: true)
                        }
                        if !allShared {
                            Button("Retry unsaved Health measurements") { Task { await sharePending() } }.disabled(busy)
                        }
                        Text("Local saving and Health sharing are separate. A Health failure does not undo your saved profile.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    Button("Review measurements") { reviewed = draft ?? []; reviewing = !reviewed.isEmpty }
                        .buttonStyle(PrimaryAction()).disabled(draft == nil || busy)
                }
            }
            if busy { Section { ProgressView("Saving measurements…") } }
        }
        .navigationTitle("Height & weight").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }.disabled(busy)
            }
        }
        .navigationBarBackButtonHidden(busy)
        .interactiveDismissDisabled(busy)
        .onAppear {
            guard !loaded else { return }; loaded = true
            originalHeight = diary.profile.height; originalWeight = diary.profile.weight
            originalWeightDate = diary.profile.weightMeasuredAt
            height = originalHeight.map(NutritionDraft.text) ?? ""
            weight = originalWeight.map(NutritionDraft.text) ?? ""
            if let date = originalWeightDate, date <= Date() { weightDate = date }
        }
        .confirmationDialog("Save these measurements?", isPresented: $reviewing, titleVisibility: .visible) {
            Button(shareToHealth ? "Save profile & share to Health" : "Save profile only") {
                Task { await saveReviewed() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(reviewed.map { "\($0.metric.title): \($0.value.formatted()) \($0.metric.unit) · \($0.date.formatted(date: .abbreviated, time: .shortened))" }.joined(separator: "\n") +
                 (shareToHealth ? "\nSave locally, then request Health write access for each selected measurement." : "\nSave locally in Nourish only."))
        }
    }
    @MainActor private func saveReviewed() async {
        guard !busy, !localSaved, !reviewed.isEmpty else { return }
        busy = true; defer { busy = false }
        localError = nil
        let saved = diary.transaction { candidate in
            for item in reviewed {
                try item.validate()
                if item.metric == .height {
                    guard candidate.profile.height == originalHeight else {
                        throw DiaryFailure.invalid("Height changed while this page was open. Reopen Height & weight before saving.")
                    }
                    candidate.profile.height = item.value
                } else {
                    guard candidate.profile.weight == originalWeight, candidate.profile.weightMeasuredAt == originalWeightDate else {
                        throw DiaryFailure.invalid("Weight changed while this page was open. Reopen Height & weight before saving.")
                    }
                    guard candidate.profile.weightMeasuredAt.map({ item.date >= $0 }) ?? true else {
                        throw DiaryFailure.invalid("This weight is older than your current measurement. Use Progress to log an older weight.")
                    }
                    candidate.profile.weight = item.value; candidate.profile.weightMeasuredAt = item.date
                    candidate.profile.weightSource = "Manual measurement"; candidate.profile.weightEntryID = nil
                }
            }
        }
        guard saved else { localError = diary.storageError ?? "Nothing was saved. Try again."; return }
        localSaved = true
        if shareToHealth { await writePending() }
    }
    @MainActor private func sharePending() async {
        guard localSaved, shareToHealth, !busy else { return }
        busy = true; defer { busy = false }
        await writePending()
    }
    @MainActor private func writePending() async {
        for item in reviewed where !completed.contains(item.syncID) {
            errors[item.syncID] = nil
            do {
                try await health.share(item)
                completed.insert(item.syncID)
            } catch { errors[item.syncID] = error.localizedDescription }
        }
        await health.refresh()
    }
}
