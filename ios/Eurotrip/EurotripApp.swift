import SwiftUI
import UniformTypeIdentifiers
import QuickLook

@main struct EurotripApp: App {
    @StateObject private var store = TripStore()
    var body: some Scene { WindowGroup { EurotripRoot().environmentObject(store) } }
}
struct EurotripRoot: View {
    @EnvironmentObject private var store: TripStore
    var body: some View {
        TabView {
            NavigationStack { TodayScreen() }.tabItem { Label("Today", systemImage: "sun.horizon") }
            NavigationStack { ItineraryScreen() }.tabItem { Label("Itinerary", systemImage: "map") }
            NavigationStack { BookingsScreen() }.tabItem { Label("Bookings", systemImage: "ticket") }
            NavigationStack { ExploreScreen() }.tabItem { Label("Explore", systemImage: "globe.europe.africa") }
            NavigationStack { MoreScreen() }.tabItem { Label("More", systemImage: "ellipsis.circle") }
        }.tint(Color(red: 0.78, green: 0.24, blue: 0.15))
        .safeAreaInset(edge: .top) { if let error = store.storageError { Text(error).font(.caption).padding().background(.orange.opacity(0.15)) } }
    }
}
struct TodayScreen: View {
    @EnvironmentObject private var store: TripStore
    var body: some View {
        let day = store.archive.previewDay()
        let stops = store.archive.destinations(on: day)
        let activities = store.archive.records("acts").filter { $0["date"] == day }.sorted { $0["time"] < $1["time"] }
        List {
            Section {
                HStack { Image("TripLogo").resizable().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true); VStack(alignment: .leading) { Text("EUROTRIP").font(.title2.bold()); Text(store.archive.setup.text("depart") + " → " + store.archive.setup.text("ret")).font(.caption) } }
                Text(day == TripDay.string(Date()) ? "Today · \(day)" : "Trip preview · \(day)")
                if stops.isEmpty { Text("No destination recorded for this date.") }
                else { Text(stops.map { $0["city"] }.joined(separator: " → ")).font(.title3.bold()); if stops.count > 1 { Text("Transfer day — check both departure and arrival cities.").font(.caption) } }
            }
            if store.archive.records("dests").isEmpty {
                Section("Start your native trip") {
                    Text("Import your website backup from More, or create your trip in Itinerary. Saved plans, bookings and files work offline.")
                    NavigationLink("Set up trip") { SetupScreen() }
                }
            }
            Section("Today's activities") {
                if activities.isEmpty { Text("Nothing planned.").foregroundStyle(.secondary) }
                ForEach(activities) { record in NavigationLink { RecordEditor(type: "acts", original: record) } label: { RecordRow(record: record, type: "acts") } }
            }
            Section("Bookings for this day") {
                let bookings = store.archive.bookings(on: day)
                if bookings.isEmpty { Text("No dated bookings.") }
                ForEach(bookings) { record in NavigationLink { BookingDetail(record: record) } label: { RecordRow(record: record, type: "docs") } }
            }
            if let stop = stops.last {
                Section("At your destination") {
                    NavigationLink("Weather for \(stop["city"])") { WeatherScreen(city: stop["city"], date: day) }
                    NavigationLink("Explore \(stop["city"])") { NearbyScreen(initialPlace: stop["city"]) }
                }
            }
            Section { NavigationLink("National rail timetables") { RailScreen() }; NavigationLink("Packing checklist") { PackingScreen() } }
        }.navigationTitle("Your trip")
    }
}
struct RecordRow: View {
    let record: TripRecord
    let type: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record[type == "dests" ? "city" : type == "docs" ? "t" : "title"]).font(.headline)
            if type == "dests" { Text("\(record["country"]) · \(record["from"]) → \(record["to"])") }
            else { Text([record["date"], record["time"], record[type == "docs" ? "tz" : "zone"]].filter { !$0.isEmpty }.joined(separator: " · ")) }
            if type == "docs" {
                Text([record["kind"], record["ref"], record["status"]].filter { !$0.isEmpty }.joined(separator: " · "))
                if !record["listedFrom"].isEmpty { Text("Listed stay: \(record["listedFrom"]) → \(record["listedThrough"]). Confirm actual check-in/out dates.").font(.caption) }
            }
            if !record["travelNote"].isEmpty { Text("Travel note: " + record["travelNote"]).font(.caption) }
            if type == "acts" && !record["note"].isEmpty { Text(record["note"]).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
        }.font(.subheadline)
    }
}
struct ItineraryScreen: View {
    @EnvironmentObject private var store: TripStore
    @State private var selection = "Route"
    @State private var day = Date()
    var body: some View {
        List {
            NavigationLink("Import / update from an itinerary table") { TableImportScreen() }
            NavigationLink("Trip dates and settings") { SetupScreen() }
            Picker("View", selection: $selection) { Text("Route").tag("Route"); Text("Day").tag("Day"); Text("All activities").tag("All") }.pickerStyle(.segmented)
            if selection == "Route" {
                NavigationLink { RecordEditor(type: "dests", original: nil) } label: { Label("Add destination", systemImage: "plus") }
                ForEach(store.archive.records("dests").sorted { $0["from"] < $1["from"] }) { record in
                    NavigationLink { RecordEditor(type: "dests", original: record) } label: { RecordRow(record: record, type: "dests") }
                        .swipeActions { Button("Delete", role: .destructive) { store.delete(record.id, type: "dests") } }
                }
                NavigationLink("Rail pass and planned journeys") { PassScreen() }
            } else {
                if selection == "Day" { DatePicker("Day", selection: $day, displayedComponents: .date) }
                NavigationLink { RecordEditor(type: "acts", original: nil, initialDate: TripDay.string(day)) } label: { Label("Add activity", systemImage: "plus") }
                ForEach(store.archive.records("acts").filter { selection == "All" || $0["date"] == TripDay.string(day) }.sorted { $0["date"] + $0["time"] < $1["date"] + $1["time"] }) { record in
                    NavigationLink { RecordEditor(type: "acts", original: record) } label: { RecordRow(record: record, type: "acts") }
                        .swipeActions { Button("Delete", role: .destructive) { store.delete(record.id, type: "acts") } }
                }
            }
            if !store.archive.trip.list("importWarnings").isEmpty {
                Section("Review from your itinerary") { ForEach(store.archive.trip.list("importWarnings"), id: \.text) { Text($0.text).foregroundStyle(.orange) } }
            }
            Section("Itinerary checks") {
                let dates = TripDay.days(store.archive.setup.text("depart"), store.archive.setup.text("ret"))
                let missing = dates.filter { store.archive.destinations(on: $0).isEmpty }
                if !missing.isEmpty { Text("\(missing.count) trip day(s) have no destination: " + missing.prefix(5).joined(separator: ", ")).foregroundStyle(.orange) }
                if !dates.isEmpty && missing.isEmpty { Text("Every trip day has a destination.") }
                let outside = store.archive.records("acts").filter { !dates.contains($0["date"]) }
                if !outside.isEmpty { Text("\(outside.count) activities lie outside the current trip dates. They remain available in All activities.") }
            }
            if !store.message.isEmpty { Text(store.message).font(.caption) }
        }.navigationTitle("Itinerary").onAppear { if let date = TripDay.localDate(store.archive.previewDay()) { day = date } }
    }
}
extension TripDay {
    static func localDate(_ text: String) -> Date? {
        guard let d = date(text) else { return nil }
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var parts = utc.dateComponents([.year, .month, .day], from: d); parts.hour = 12
        var local = Calendar(identifier: .gregorian); local.timeZone = .current
        return local.date(from: parts)
    }
}
struct DateEntry: View {
    let label: String
    @Binding var text: String
    var optional = true
    var body: some View {
        if text.isEmpty && optional { Button("Set \(label)") { text = TripDay.string(Date()) } }
        else {
            DatePicker(label, selection: Binding(get: { TripDay.localDate(text) ?? Date() }, set: { text = TripDay.string($0) }), displayedComponents: .date)
            if optional { Button("Clear \(label)") { text = "" }.font(.caption) }
        }
    }
}
struct SetupScreen: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @State private var fields: [String: JSONValue] = [:]
    @State private var error = ""
    func binding(_ key: String) -> Binding<String> { Binding(get: { fields.text(key) }, set: { fields[key] = .string($0) }) }
    var body: some View {
        Form {
            TextField("Home city", text: binding("home"))
            DateEntry(label: "Departure", text: binding("depart"))
            DateEntry(label: "Last itinerary / return day", text: binding("ret"))
            TextField("Home currency", text: binding("cur")).textInputAutocapitalization(.characters).autocorrectionDisabled()
            TextField("Travellers", text: binding("trav")).keyboardType(.numberPad)
            TextField("Dietary needs / allergies", text: binding("diet"), axis: .vertical)
            DisclosureGroup("Optional passport record — device only") { TextField("Nationality", text: binding("nat")); DateEntry(label: "Passport expiry", text: binding("pexp")) }
            Text(error).foregroundStyle(.red)
            Button("Save trip") { do { fields["cur"] = .string(fields.text("cur").uppercased()); try store.updateSetup(fields); dismiss() } catch { self.error = error.localizedDescription } }
        }.navigationTitle("Trip settings").onAppear { fields = store.archive.setup }
    }
}
struct RecordEditor: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    let type: String
    let original: TripRecord?
    var initialDate = ""
    @State private var record = TripRecord.new()
    @State private var error = ""
    func binding(_ key: String) -> Binding<String> { Binding(get: { record[key] }, set: { record[key] = $0 }) }
    var body: some View {
        Form {
            if type == "dests" {
                TextField("City", text: binding("city")); TextField("Country", text: binding("country"))
                DateEntry(label: "Arrive", text: binding("from"), optional: false)
                DateEntry(label: "Leave", text: binding("to"), optional: false)
                TextField("Travel notes / estimated duration", text: binding("travelNote"), axis: .vertical)
            } else if type == "acts" {
                TextField("Activity", text: binding("title")); DateEntry(label: "Date", text: binding("date"), optional: false)
                TextField("Local time, HH:mm (optional)", text: binding("time")).keyboardType(.numbersAndPunctuation)
                TextField("Time zone, e.g. Europe/Paris", text: binding("zone")).autocorrectionDisabled().textInputAutocapitalization(.never)
                if !record["suggestedZone"].isEmpty && record["zone"].isEmpty { Button("Confirm suggested zone: \(record["suggestedZone"])") { record["zone"] = record["suggestedZone"] } }
                TextField("Notes", text: binding("note"), axis: .vertical)
            } else {
                TextField("Booking name", text: binding("t"))
                Picker("Type", selection: binding("kind")) { ForEach(["Accommodation", "Flight", "Train", "Ferry", "Bus", "Activity", "Other"], id: \.self) { Text($0) } }
                TextField("Confirmation reference", text: binding("ref"))
                DateEntry(label: "Departure / check-in", text: binding("date"))
                TextField("Local departure time, HH:mm", text: binding("time")).keyboardType(.numbersAndPunctuation)
                TextField("Departure time zone, e.g. Europe/Paris", text: binding("tz")).autocorrectionDisabled().textInputAutocapitalization(.never)
                DateEntry(label: "Arrival / check-out", text: binding("end"))
                TextField("Local arrival time, HH:mm", text: binding("endTime")).keyboardType(.numbersAndPunctuation)
                TextField("Arrival time zone", text: binding("arrivalTz")).autocorrectionDisabled().textInputAutocapitalization(.never)
                TextField("Address / station / airport", text: binding("address"), axis: .vertical)
                TextField("Booking URL", text: binding("url")).keyboardType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never)
                DisclosureGroup("Cancellation deadline") { DateEntry(label: "Cancellation date", text: binding("cancel")); TextField("Time, HH:mm", text: binding("cancelTime")); TextField("Time zone", text: binding("cancelTz")).autocorrectionDisabled().textInputAutocapitalization(.never) }
                TextField("Notes", text: binding("note"), axis: .vertical)
            }
            Text("Times are local as entered. Calendar export requires an explicit valid time zone; the app does not guess it.").font(.caption)
            Text(error).foregroundStyle(.red)
            Button("Save") { do { try store.save(record, type: type); dismiss() } catch { self.error = error.localizedDescription } }
        }.navigationTitle(original == nil ? "Add \(type == "dests" ? "destination" : type == "acts" ? "activity" : "booking")" : "Edit")
        .onAppear {
            record = original ?? .new()
            if original == nil {
                let date = initialDate.isEmpty ? store.archive.previewDay() : initialDate
                if type == "dests" { record["from"] = date; record["to"] = date }
                if type == "acts" { record["date"] = date }
                if type == "docs" { record["kind"] = "Accommodation" }
            }
        }
    }
}
