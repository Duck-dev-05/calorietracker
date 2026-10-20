import SwiftUI

struct HealthCataloguePanel: View {
    @EnvironmentObject var health: HealthService
    @State private var results: [HealthDataKind: HealthBrowseResult] = [:]
    @State private var loading = false
    @State private var search = ""
    @State private var expanded: Set<String> = ["Activity & Fitness"]
    private var kinds: [HealthDataKind] { HealthDataKind.allCases.filter { search.isEmpty || ($0.title + " " + $0.group).localizedCaseInsensitiveContains(search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Browse Health & Fitness", subtitle: "Latest readable records across 26 supported types. Open one for records and dates.")
            TextField("Find a Health data type", text: $search).padding(14).background(NourishStyle.surface, in: RoundedRectangle(cornerRadius: 14)).accessibilityLabel("Find a Health data type")
            if loading { ProgressView("Checking available records…") }
            ForEach(HealthDataKind.groups, id: \.self) { group in
                if kinds.contains(where: { $0.group == group }) {
                    Surface {
                        DisclosureGroup(group, isExpanded: Binding(get: { !search.isEmpty || expanded.contains(group) }, set: { if $0 { expanded.insert(group) } else { expanded.remove(group) } })) {
                        ForEach(kinds.filter { $0.group == group }) { kind in
                            NavigationLink(destination: HealthRecordsScreen(kind: kind)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack { Text(kind.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                                    if let result = results[kind] {
                                        if let first = result.records.first {
                                            Text(first.value).font(.subheadline).foregroundStyle(NourishStyle.accent)
                                            Text(first.end.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                        } else { Text(result.error == nil ? "No readable records" : "Could not load · tap to retry").font(.caption).foregroundStyle(.secondary) }
                                    } else { Text(loading ? "Checking…" : "Not checked").font(.caption).foregroundStyle(.secondary) }
                                }.padding(.vertical, 8).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            if kind != kinds.filter({ $0.group == group }).last { Divider() }
                        }
                        }
                    }
                }
            }
            if kinds.isEmpty { Text("No matching data types.").font(.subheadline).foregroundStyle(.secondary) }
            Text("These are individual records, not daily totals. Activity rings show today's summary. Permission or device restrictions may hide records. Clinical records, ECGs, routes and every Health-app feature are not included.").font(.caption).foregroundStyle(.secondary)
        }.task(id: health.browseRevision) { await load() }
    }
    @MainActor private func load() async {
        loading = true; results = [:]
        await withTaskGroup(of: (HealthDataKind, HealthBrowseResult).self) { group in
            for kind in HealthDataKind.allCases {
                group.addTask { @MainActor in
                    do { return (kind, HealthBrowseResult(records: try await health.browse(kind, limit: 1))) }
                    catch { return (kind, HealthBrowseResult(error: error.localizedDescription)) }
                }
            }
            for await (kind, result) in group {
                guard !Task.isCancelled else { continue }
                results[kind] = result
            }
        }
        if !Task.isCancelled { loading = false }
    }
}
struct HealthRecordsScreen: View {
    @EnvironmentObject var health: HealthService
    let kind: HealthDataKind
    @State private var byDay = false
    @State private var day = Date()
    @State private var revision = 0
    @State private var records: [HealthDataRecord] = []
    @State private var loading = false
    @State private var error: String?
    @State private var checked: Date?
    private var requestID: String { "\(byDay)-\(day.timeIntervalSinceReferenceDate)-\(revision)-\(health.browseRevision)" }
    var body: some View {
        List {
            Section {
                if kind != .rings { Toggle("Choose a day", isOn: $byDay) }
                if byDay || kind == .rings { DatePicker("Day", selection: $day, in: ...Date(), displayedComponents: .date) }
                Text(kind == .rings ? "Apple's activity summary for this day." : "Up to 200 latest individual records\(byDay ? " overlapping this day" : " across available history"). Open a day to inspect older records. These are not combined totals.").font(.footnote).foregroundStyle(.secondary)
                if let checked { Text("Checked \(checked.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                if loading { ProgressView("Reading records…") }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            Section("Records") {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.value).font(.headline).textSelection(.enabled)
                        Text(record.start.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        if record.end != record.start { Text("Until \(record.end.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                        Text(record.source).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }
                if !loading && records.isEmpty && error == nil { EmptyCard(title: "No readable records", message: "This may mean no data or restricted access. Check Nourish permissions in Apple Health.", icon: "heart") }
                if records.count == 200 { Text("Showing the most recent 200 records. Older records may exist; choose an earlier day to inspect them. Very busy days can also exceed this limit.").font(.footnote).foregroundStyle(.secondary) }
            }
            if kind == .height || kind == .weight {
                Section { NavigationLink("Review profile import or share a measurement", destination: HealthMetricScreen(metric: kind == .height ? .height : .weight)) }
            }
            Section {
                Text("Read only. No records are imported, combined or written automatically. Overlapping sleep, workout and source records must not be summed as independent calories or sleep totals.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
        .toolbar { Button { revision += 1 } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh records").disabled(loading) }
        .task(id: requestID) { await load() }
    }
    @MainActor private func load() async {
        loading = true; records = []; error = nil; checked = nil
        do {
            let result = try await health.browse(kind, day: byDay || kind == .rings ? day : nil)
            guard !Task.isCancelled else { return }
            records = result; checked = Date()
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        loading = false
    }
}
