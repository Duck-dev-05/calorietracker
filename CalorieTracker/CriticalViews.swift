import SwiftUI

struct HealthMetricScreen: View {
    @EnvironmentObject var health: HealthService
    @EnvironmentObject var diary: Diary
    let metric: HealthMetric
    @State private var imported = false
    private var result: MetricResult { health.result(metric) }
    var body: some View {
        PageCanvas {
            PageIntro(eyebrow: "Apple Health", title: metric.title, detail: metric.isDaily ? "Available activity for the current local day." : "Your most recent readable measurement.")
            Surface {
                HStack { IconTile(icon: metric.icon); Spacer(); Pill(text: result.status.rawValue) }
                if let value = health.monitor.value(metric) { Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) \(metric.unit)").font(.system(.largeTitle, design: .rounded).weight(.bold)) }
                else { Text("Unavailable").font(.title2.bold()); Text("No current value is shown. Refresh to check for available records.").font(.subheadline).foregroundStyle(.secondary) }
                if result.status == .loading { ProgressView("Reading Health data…") }
                if let error = result.error { Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.red) }
                Button("Refresh this metric") { Task { await health.refresh(metric) } }.buttonStyle(.bordered).disabled(health.busy)
            }
            Surface {
                SectionHeading(title: "Where this value comes from")
                if let fetched = result.fetchedAt { ValueRow(title: "Last checked", value: fetched.formatted(date: .abbreviated, time: .shortened)) }
                if let sampled = result.reading?.sampleDate { ValueRow(title: "Measurement date", value: sampled.formatted(date: .abbreviated, time: .shortened)) }
                if let source = result.reading?.source { ValueRow(title: "Recorded by", value: source) }
                if metric.isDaily { Text("This is a cumulative Apple Health total. A single recording source and sample time are not available for this aggregate.").font(.footnote) }
                Text("Results are marked for refresh after 15 minutes. Daily activity also expires when the local day or timezone changes. Old values aren't shown as current.").font(.footnote).foregroundStyle(.secondary)
            }
            if (metric == .height || metric == .weight), let value = health.monitor.value(metric) {
                Surface {
                    Text("Review the measurement date before importing. An older weight cannot replace a newer profile measurement.").font(.footnote)
                    Button("Use this measurement in my profile") {
                        if metric == .height { imported = diary.transaction { $0.profile.height = value } }
                        else if let date = result.reading?.sampleDate { imported = diary.importWeight(value, measuredAt: date, source: result.reading?.source.map { "Apple Health · \($0)" } ?? "Apple Health") }
                    }.buttonStyle(PrimaryAction())
                    if imported { Label("Profile updated", systemImage: "checkmark.circle").font(.subheadline) }
                    if let error = diary.storageError { Text(error).font(.footnote).foregroundStyle(.red) }
                }
            }
            Surface {
                Text("HealthKit does not disclose whether an empty query means no records or restricted read access. Manage permissions in Apple Health → your profile → Apps → Nourish. Manual tracking continues without Health access.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle(metric.title).navigationBarTitleDisplayMode(.inline)
        .onAppear { health.expireOldResults() }
    }
}
struct WeightHistoryScreen: View {
    @EnvironmentObject var diary: Diary
    @State private var adding = false
    var body: some View {
        List {
            Section("Current profile") {
                ValueRow(title: "Weight", value: diary.profile.weight.map { "\($0.formatted()) kg" } ?? "Not set")
                if let date = diary.profile.weightMeasuredAt { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption) }
                Text(diary.profile.weightSource ?? "Source/date not recorded in the older profile.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Measurements") {
                if diary.weights.isEmpty { EmptyCard(title: "No measurements yet", message: "Log a dated weight to begin your history.", icon: "scalemass") }
                ForEach(diary.weights.sorted { $0.date > $1.date }) { entry in
                    NavigationLink(destination: WeightEntryScreen(entry: entry)) {
                        VStack(alignment: .leading, spacing: 5) { ValueRow(title: entry.date.formatted(date: .abbreviated, time: .shortened), value: "\(entry.kilograms.formatted()) kg"); Text(entry.source ?? "Manual log · legacy source").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            Section { Text("Editing or deleting the current dated measurement reconciles your profile with the next eligible record. A newer explicit profile edit or Health import is preserved.").font(.footnote) }
        }.navigationTitle("Weight history").toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Log weight") }
        .sheet(isPresented: $adding) { WeightLogScreen().adaptiveEntrySheet() }
    }
}
struct WeightEntryScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    let entry: WeightEntry
    @State private var weight = ""
    @State private var date = Date()
    @State private var loaded = false
    @State private var deleting = false
    var body: some View {
        Form {
            Section("Measurement") { NumberDraftField(title: "Weight (kg)", text: $weight, range: 20...400); DatePicker("Measured", selection: $date, in: ...diary.now) }
            Section { Text("Saving changes the dated record. Your profile is reconciled only after the save succeeds.").font(.footnote) }
            Button("Delete measurement", role: .destructive) { deleting = true }
            if let error = diary.storageError { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Edit weight").toolbar { Button("Save") {
            guard let value = NumberDraftField.value(weight, range: 20...400) else { return }
            var updated = entry; updated.kilograms = value; updated.date = date; updated.source = "Edited manual measurement"
            if diary.upsertWeight(updated) { dismiss() }
        }.disabled(NumberDraftField.value(weight, range: 20...400) == nil) }
        .onAppear { if !loaded { weight = entry.kilograms.formatted(.number.grouping(.never)); date = entry.date; loaded = true } }
        .alert("Delete this measurement?", isPresented: $deleting) { Button("Delete", role: .destructive) { if diary.deleteWeight(entry.id) { dismiss() } }; Button("Cancel", role: .cancel) { } } message: { Text("This removes only the selected record and may update the current profile weight.") }
    }
}
struct WaterEntryScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    var existing: WaterEntry? = nil
    var initialDate = Date()
    @State private var amount = ""
    @State private var date = Date()
    @State private var loaded = false
    @State private var deleting = false
    @FocusState private var focused: Bool
    private var validAmount: Int? { guard let value = Int(amount), (1...10000).contains(value) else { return nil }; return value }
    var body: some View {
        AdaptiveNavigation {
            Form {
                Section("Water entry") { TextField("Amount (mL)", text: $amount).keyboardType(.numberPad).focused($focused); DatePicker("When", selection: $date, in: ...diary.now) }
                if let existing { Button("Delete entry", role: .destructive) { deleting = true }.accessibilityLabel("Delete \(existing.milliliters) milliliter entry") }
                if let error = diary.storageError { Text(error).foregroundStyle(.red) }
            }.navigationTitle(existing == nil ? "Log water" : "Edit water").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { guard let amount = validAmount else { return }; var entry = WaterEntry(date: date, milliliters: amount); if let existing { entry.id = existing.id }; if diary.upsertWater(entry) { dismiss() } }.disabled(validAmount == nil) }
                ToolbarItemGroup(placement: .keyboard) { if focused { Spacer(); Button("Done") { focused = false } } }
            }.alert("Delete water entry?", isPresented: $deleting) { Button("Delete", role: .destructive) { if let existing, diary.deleteWater(existing.id) { dismiss() } }; Button("Cancel", role: .cancel) { } }
        }.onAppear { if !loaded { amount = existing.map { String($0.milliliters) } ?? ""; date = existing?.date ?? min(initialDate, diary.now); loaded = true } }
    }
}
struct PlannedMealEditorScreen: View {
    @EnvironmentObject var diary: Diary
    @Environment(\.dismiss) private var dismiss
    var existing: PlannedMeal? = nil
    var initialDate = Date()
    @State private var name = ""
    @State private var calories = ""
    @State private var category = "Lunch"
    @State private var date = Date()
    @State private var copyDate = Date()
    @State private var loaded = false
    @State private var deleting = false
    @FocusState private var energyFocused: Bool
    private var energy: Int? { guard let n = Int(calories), (1...10000).contains(n) else { return nil }; return n }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 500 && energy != nil }
    var body: some View {
        Form {
            Section("Planned meal") { TextField("Meal name", text: $name); TextField("Planned calories (kcal)", text: $calories).keyboardType(.numberPad).focused($energyFocused); Picker("Meal", selection: $category) { ForEach(mealCategories, id: \.self) { Text($0) } }; DatePicker("Planned day", selection: $date, displayedComponents: .date) }
            Section { NutritionSnapshotRows(snapshot: existing?.nutrition); Text("Changing planned calories clears the old portion/macros rather than retaining incorrect nutrition. These are planned values you enter. Changing the day moves the same plan; it does not add food to your diary.").font(.footnote) }
            if let existing {
                Section("Copy to another day") { DatePicker("Copy day", selection: $copyDate, displayedComponents: .date); Button("Copy saved plan") { if diary.copyPlan(existing.id, to: copyDate) { dismiss() } }; Text("Copies the last saved values. Save your draft first to include changes.").font(.caption) }
                if Calendar.current.startOfDay(for: existing.date) <= Calendar.current.startOfDay(for: diary.now) { Button("Mark saved plan as eaten") { if diary.consumePlan(existing.id) { dismiss() } } }
                Button("Delete plan", role: .destructive) { deleting = true }
            }
            if let error = diary.storageError { Text(error).foregroundStyle(.red) }
        }.navigationTitle(existing == nil ? "Create plan" : "Edit planned meal").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { if energyFocused { Spacer(); Button("Done") { energyFocused = false } } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { guard valid, let energy else { return }; var plan = PlannedMeal(date: date, name: name.trimmingCharacters(in: .whitespacesAndNewlines), calories: energy, category: category); if let existing { plan.id = existing.id; if energy == existing.calories { plan.nutrition = existing.nutrition } }; if diary.upsertPlan(plan) { dismiss() } }.disabled(!valid) } }
        .onAppear { if !loaded { name = existing?.name ?? ""; calories = existing.map { String($0.calories) } ?? ""; category = existing?.category ?? "Lunch"; date = existing?.date ?? initialDate; copyDate = date; loaded = true } }
        .alert("Delete this plan?", isPresented: $deleting) { Button("Delete", role: .destructive) { if let existing, diary.deletePlan(existing.id) { dismiss() } }; Button("Cancel", role: .cancel) { } }
    }
}
