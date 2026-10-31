import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct BookingsScreen: View {
    @EnvironmentObject private var store: TripStore
    var body: some View {
        List {
            NavigationLink { RecordEditor(type: "docs", original: nil) } label: { Label("Add booking", systemImage: "plus") }
            ForEach(store.archive.records("docs").sorted { $0["date"] + $0["time"] < $1["date"] + $1["time"] }) { record in
                NavigationLink { BookingDetail(record: record) } label: { RecordRow(record: record, type: "docs"); if store.archive.files.contains(where: { $0.id == record.id }) { Image(systemName: "paperclip").accessibilityLabel("Offline attachment") } }
                    .swipeActions { Button("Delete", role: .destructive) { store.delete(record.id, type: "docs") } }
            }
            Text("Bookings and attached files are stored on this iPhone. Full JSON backups include the files; shared summaries do not.").font(.caption)
        }.navigationTitle("Bookings")
    }
}
struct BookingDetail: View {
    @EnvironmentObject private var store: TripStore
    let record: TripRecord
    @State private var importer = false
    @State private var preview: URL?
    @State private var error = ""
    var current: TripRecord { store.archive.records("docs").first { $0.id == record.id } ?? record }
    var body: some View {
        List {
            Section { RecordRow(record: current, type: "docs"); Text(current["address"]); Text(current["note"]).textSelection(.enabled) }
            if !current["end"].isEmpty { Section("Arrival / check-out") { Text([current["end"], current["endTime"], current["arrivalTz"]].filter { !$0.isEmpty }.joined(separator: " · ")) } }
            if !current["cancel"].isEmpty { Section("Cancellation deadline") { Text([current["cancel"], current["cancelTime"], current["cancelTz"]].filter { !$0.isEmpty }.joined(separator: " · ")); Text("Local time as recorded; confirm the booking's terms.").font(.caption) } }
            NavigationLink("Edit booking") { RecordEditor(type: "docs", original: current) }
            if let url = TravelLinks.url(current["url"]) { Link("Open booking / document website", destination: url) }
            if let url = TravelLinks.maps(current["address"]) { Link("Directions in Maps", destination: url) }
            Section("Offline attachment") {
                Button("Attach PDF, photo or text file") { importer = true }
                if let file = store.archive.files.first(where: { $0.id == current.id }) {
                    Button("Open \(file.name)") { do { preview = try store.previewFile(current.id) } catch { self.error = error.localizedDescription } }
                }
                Text("One file per booking, up to 10 MB. Attaching another replaces this booking's file; Undo is available in More.").font(.caption)
            }
            Text(error).foregroundStyle(.red)
        }.navigationTitle(current["t"])
        .fileImporter(isPresented: $importer, allowedContentTypes: [.pdf, .image, .plainText]) { result in
            do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0; guard size <= 10 * 1024 * 1024 else { throw TripError.invalid("File exceeds 10 MB.") }; try store.attach(Data(contentsOf: url), name: url.lastPathComponent, booking: current.id) } catch { self.error = error.localizedDescription }
        }.quickLookPreview($preview)
        .onChange(of: preview) { old, next in if next == nil, let old { try? FileManager.default.removeItem(at: old) } }
    }
}
struct PackingScreen: View {
    @EnvironmentObject private var store: TripStore
    @State private var text = ""
    @State private var error = ""
    var body: some View {
        List {
            HStack { TextField("New packing item", text: $text); Button("Add") { do { try store.addPacking(text.trimmingCharacters(in: .whitespacesAndNewlines)); text = "" } catch { self.error = error.localizedDescription } }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            ForEach(Array(store.archive.trip.list("pack").enumerated()), id: \.offset) { index, value in
                Button { store.togglePacking(index) } label: { Label(value.object.text("t"), systemImage: value.object["done"]?.bool == true ? "checkmark.circle.fill" : "circle") }
                    .swipeActions { Button("Delete", role: .destructive) { do { try store.removePacking(index) } catch { self.error = error.localizedDescription } } }
            }
            Text(error).foregroundStyle(.red)
        }.navigationTitle("Packing")
    }
}
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(_ data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct MoreScreen: View {
    @EnvironmentObject private var store: TripStore
    @State private var importing = false
    @State private var exporting = false
    @State private var pending: Data?
    @State private var export = Data()
    @State private var replace = false
    @State private var message = ""
    @State private var packURL: URL?
    var body: some View {
        Form {
            Section("Your trip") {
                NavigationLink("Import itinerary table") { TableImportScreen() }
                NavigationLink("Trip settings") { SetupScreen() }
                NavigationLink("Packing checklist") { PackingScreen() }
                NavigationLink("Rail pass and journey records") { PassScreen() }
                NavigationLink("Calendar export") { CalendarScreen() }
            }
            Section("Backup and website migration") {
                if store.storageError != nil { Button("Export original data for recovery") { do { export = try store.originalData(); exporting = true } catch { message = error.localizedDescription } } }
                Text("On the website: More → Export full backup. Save the JSON in Files, then import it here. Native apps cannot directly read Safari's browser storage.")
                Button("Import Eurotrip JSON backup") { importing = true }.disabled(store.storageError != nil)
                Button("Export full backup with attachments") { do { export = try store.archive.encoded(); exporting = true } catch { message = error.localizedDescription } }.disabled(store.storageError != nil)
                ShareLink("Share itinerary and booking summary", item: store.summary)
                Button("Prepare standalone offline travel pack") { do { let data = try OfflinePack.html(store.archive); let file = FileManager.default.temporaryDirectory.appendingPathComponent("eurotrip-offline.html"); try data.write(to: file, options: [.atomic, .completeFileProtection]); packURL = file } catch { message = error.localizedDescription } }
                if let packURL { ShareLink("Save / share offline travel pack", item: packURL) }
                if store.canUndo { Button("Undo last import or deletion") { do { try store.undo(); message = store.message } catch { message = error.localizedDescription } } }
                Text("JSON backups remain compatible with the website. Legacy financial and unknown fields are preserved even when not shown in the native UI. Backups contain private trip information: keep a copy outside this phone.").font(.caption)
                Text(message).font(.caption)
            }
            NavigationLink("Connection and API credentials") { ConnectionScreen() }
            Section("Offline and privacy") {
                Text("Itinerary, bookings, packing and saved attachments work offline without preparing a web cache. Live Maps, rates, forecasts, timetables and searches require internet. There is no account, cloud trip sync or live booking engine. The existing Render server handles live provider requests; the complete trip and attached files are not uploaded.")
                Text("Credentials use this iPhone's Keychain and are excluded from exports. Saved trip files use iOS file protection. Photos/files you explicitly export or share remain subject to the destination's privacy settings.")
            }
        }.navigationTitle("More")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 50 * 1024 * 1024 else { throw TripError.invalid("Backup exceeds 50 MB.") }
                let data = try Data(contentsOf: url); _ = try TripArchive.decode(data)
                if store.archive.records("dests").isEmpty && store.archive.records("docs").isEmpty && store.archive.records("acts").isEmpty && store.archive.trip.list("pack").isEmpty { try store.importData(data); message = store.message }
                else { pending = data; replace = true }
            } catch { message = error.localizedDescription }
        }
        .confirmationDialog("Replace the native trip with this backup? The current trip will be kept for Undo.", isPresented: $replace) {
            Button("Import and keep recovery copy") { do { if let pending { try store.importData(pending); message = store.message }; pending = nil } catch { message = error.localizedDescription } }
            Button("Cancel", role: .cancel) { pending = nil }
        }
        .fileExporter(isPresented: $exporting, document: BackupDocument(export), contentType: .json, defaultFilename: "eurotrip-backup-\(TripDay.string(Date()))") { if case .failure(let error) = $0 { message = error.localizedDescription } }
    }
}
struct ConnectionScreen: View {
    @AppStorage("eurotrip.endpoint") private var endpoint = "https://eurotrip-planner.onrender.com"
    @State private var code = ""
    @State private var brave = ""
    @State private var dbClient = ""
    @State private var dbKey = ""
    @State private var message = ""
    @State private var busy = false
    var body: some View {
        Form {
            Section("Eurotrip backend") {
                TextField("HTTPS backend URL", text: $endpoint).keyboardType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never)
                SecureField("Existing app access code", text: $code)
                Button("Save code and test connection") { Task { await testConnection() } }.disabled(busy)
                Text(message)
                Text("The URL points to your existing Render service. A cold service can take several seconds to wake. Changing the URL does not send a previous server's saved code to the new host.").font(.caption)
            }
            Section("Optional device provider keys") {
                Text("Use existing server-managed credentials where available. Device keys are stored only in Keychain and sent to the configured Eurotrip server for the relevant request.").font(.caption)
                SecureField("Brave API key", text: $brave)
                Button("Save Brave key") { save(brave, key: "brave") }
                SecureField("DB Client ID", text: $dbClient); SecureField("DB API key", text: $dbKey)
                Button("Save DB credentials") { do { try TravelKeychain.save(dbClient, name: "dbClient:" + endpoint); try TravelKeychain.save(dbKey, name: "dbKey:" + endpoint); message = "Stored securely. Use Germany departures to verify your Timetables subscription." } catch { message = error.localizedDescription } }
                Button("Remove device provider keys", role: .destructive) { save("", key: "brave"); save("", key: "dbClient"); save("", key: "dbKey"); brave = ""; dbClient = ""; dbKey = "" }
                Text("Saving is not validation. Public Swiss rail needs no provider key. Germany requires an active DB Timetables subscription. Brave requires an API key; provider limits and charges can apply.").font(.caption)
            }
        }.navigationTitle("Connection").onAppear { code = TravelKeychain.read("access:" + endpoint) }
    }
    func save(_ value: String, key: String) { do { try TravelKeychain.save(value, name: key + ":" + endpoint); message = value.isEmpty ? "Removed device key." : "Stored securely; test the corresponding lookup to verify access." } catch { message = error.localizedDescription } }
    @MainActor func testConnection() async {
        busy = true; defer { busy = false }
        do {
            guard let url = URL(string: endpoint), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { throw TripError.invalid("Enter a valid HTTPS backend URL.") }
            guard code.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 }), code.count <= 500 else { throw TripError.invalid("Access codes cannot contain spaces or control characters.") }
            try TravelKeychain.save(code, name: "access:" + endpoint)
            let result = try await TravelClient(endpoint: endpoint, accessCode: code).request("status")
            message = result.object["ok"]?.bool == true ? "Connected. Live provider availability is checked when you run each lookup." : "Unexpected server response."
        } catch { message = error.localizedDescription }
    }
}
struct PassScreen: View {
    @EnvironmentObject private var store: TripStore
    @State private var rail: [String: JSONValue] = [:]
    @State private var error = ""
    var legs: [(String, TripRecord, TripRecord)] {
        let stops = store.archive.records("dests").sorted { $0["from"] < $1["from"] }
        guard stops.count > 1 else { return [] }
        return (1..<stops.count).compactMap { n in let a = stops[n-1], b = stops[n]; return a["city"] == b["city"] && a["country"] == b["country"] ? nil : (b["from"] + "|" + b["city"], a, b) }
    }
    func binding(_ key: String) -> Binding<String> { .init(get: { rail.text(key) }, set: { rail[key] = .string($0) }) }
    var body: some View {
        Form {
            Picker("Pass type", selection: binding("kind")) { Text("Flexi").tag("Flexi"); Text("Continuous").tag("Continuous") }
            TextField("Pass days", text: binding("days")).keyboardType(.numberPad)
            Button("Save pass") { do { var next = store.archive; var trip = next.trip; trip["rail"] = .object(rail); next.trip = trip; try store.commit(next) } catch { self.error = error.localizedDescription } }
            ForEach(legs, id: \.0) { key, a, b in
                Section("\(a["city"]) → \(b["city"]) · \(b["from"])") {
                    Picker("Travel mode", selection: legBinding(key, "mode")) { ForEach(["Not set", "Train (pass day)", "Train (own ticket)", "Ferry", "Bus", "Car", "Flight"], id: \.self) { Text($0) } }
                    Picker("Reservation", selection: legBinding(key, "res")) { ForEach(["Unknown", "Not needed", "Needed", "Booked"], id: \.self) { Text($0) } }
                }
            }
            let marked = Set(legs.filter { store.archive.trip["legs"]?.object[$0.0]?.object.text("mode") == "Train (pass day)" }.map { $0.2["from"] })
            Text("\(marked.count) distinct planned pass travel dates. This is a manual planning record, not pass activation or reservation confirmation.")
            Text(error).foregroundStyle(.red)
        }.navigationTitle("Rail pass").onAppear { rail = store.archive.trip["rail"]?.object ?? [:] }
    }
    func legBinding(_ key: String, _ field: String) -> Binding<String> {
        Binding(get: { store.archive.trip["legs"]?.object[key]?.object.text(field).nilIfEmpty ?? (field == "mode" ? "Not set" : "Unknown") }, set: { value in
            do { var next = store.archive; var t = next.trip; var all = t["legs"]?.object ?? [:]; var leg = all[key]?.object ?? [:]; if field == "mode" && value == "Not set" { leg.removeValue(forKey: field) } else { leg[field] = .string(value) }; all[key] = .object(leg); t["legs"] = .object(all); next.trip = t; try store.commit(next) } catch { error = error.localizedDescription }
        })
    }
}
extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
