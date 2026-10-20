import SwiftUI

struct ShareMeasurementScreen: View {
    @EnvironmentObject var diary: Diary
    @EnvironmentObject var health: HealthService
    let metric: HealthMetric
    @State private var amount = ""
    @State private var measured = Date()
    @State private var loaded = false
    @State private var reviewing = false
    @State private var reviewed: HealthMeasurement?
    @State private var error: String?
    @State private var saved = false
    private var measurement: HealthMeasurement? {
        guard let value = NutritionDraft.number(amount) else { return nil }
        let candidate = HealthMeasurement(metric: metric, value: value, date: measured)
        return (try? candidate.validate()) != nil ? candidate : nil
    }
    var body: some View {
        Form {
            Section("Measurement to share") {
                NumberDraftField(title: "\(metric.title) (\(metric.unit))", text: $amount, range: metric == .height ? 80...250 : 20...400)
                DatePicker("Measured", selection: $measured, in: ...Date())
                Text("Choose the date this was actually measured. Existing profile values may have no recorded date.").font(.caption).foregroundStyle(.secondary)
            }.disabled(health.sharingBusy || saved)
            Section {
                Text("Adds this measurement to Apple Health under Nourish. It does not change your local profile or delete other Health records.").font(.subheadline)
                Text("Only the selected height or weight write permission is requested. Activity and workouts are not written.").font(.caption).foregroundStyle(.secondary)
                if let error { Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red) }
                if saved {
                    Label("Saved to Apple Health", systemImage: "checkmark.circle.fill").foregroundStyle(NourishStyle.accent)
                    Text("You can inspect or delete it in Health → Browse → Body Measurements → \(metric.title) → Show All Data.").font(.footnote)
                } else {
                    Button(health.sharingBusy ? "Saving…" : "Review sharing") { reviewed = measurement; reviewing = reviewed != nil }.buttonStyle(PrimaryAction()).disabled(measurement == nil || health.sharingBusy)
                }
            }
        }.navigationTitle("Share \(metric.title.lowercased())").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }; loaded = true
            let value = metric == .height ? diary.profile.height : diary.profile.weight
            amount = value.map(NutritionDraft.text) ?? ""
            if metric == .weight, let date = diary.profile.weightMeasuredAt, date <= Date() { measured = date }
        }
        .confirmationDialog("Save to Apple Health?", isPresented: $reviewing, titleVisibility: .visible) {
            Button("Save to Apple Health") {
                guard let reviewed else { return }
                error = nil
                Task {
                    do { try await health.share(reviewed); saved = true; await health.refresh(metric) }
                    catch { self.error = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let reviewed { Text("\(metric.title): \(reviewed.value.formatted()) \(metric.unit)\nMeasured: \(reviewed.date.formatted(date: .abbreviated, time: .shortened))\nThis saves a measurement only. Your Fitness rings and goals are not edited.") }
        }
    }
}
