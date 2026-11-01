import Foundation

struct ItineraryRow {
    let date: String
    let time: String
    let location: String
    let accommodation: String
    let travel: String
    let activity: String
}
enum ItineraryImport {
    static func rows(_ text: String) throws -> [ItineraryRow] {
        guard text.utf8.count <= 100_000 else { throw TripError.invalid("Table is too large. Use a full JSON backup for larger trips.") }
        let regex = try NSRegularExpression(pattern: #"\b([0-9]{1,2})/([0-9]{1,2})/([0-9]{2}|[0-9]{4})\b"#)
        var result: [ItineraryRow] = []
        for line in text.components(separatedBy: .newlines) {
            var cells = line.components(separatedBy: line.contains("|") ? "|" : "\t").map { $0.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "\u{00A0}", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            if cells.first == "" { cells.removeFirst() }; if cells.last == "" { cells.removeLast() }
            guard cells.count >= 3, let match = regex.firstMatch(in: cells[0], range: NSRange(cells[0].startIndex..., in: cells[0])) else { continue }
            func part(_ n: Int) -> Int { Int((cells[0] as NSString).substring(with: match.range(at: n))) ?? 0 }
            let year = part(3) < 100 ? 2000 + part(3) : part(3)
            let day = String(format: "%04d-%02d-%02d", year, part(2), part(1))
            guard TripDay.date(day) != nil, cells[1].isEmpty || TripDay.timeValid(cells[1]) else { throw TripError.invalid("Invalid date/time in table: " + cells[0]) }
            guard !cells[2].isEmpty else { throw TripError.invalid("A dated row has no location.") }
            while cells.count < 6 { cells.append("") }
            result.append(.init(date: day, time: cells[1], location: cells[2], accommodation: cells[3], travel: cells[4], activity: cells[5]))
        }
        guard !result.isEmpty, result.count <= 1000 else { throw TripError.invalid("No itinerary rows found. Paste the table with Date | Time | Location | Accommodation | Travel time | Things to do.") }
        return result
    }
    static func place(_ original: String) -> (city: String, country: String, zone: String) {
        let text = original.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_AU"))
        let known: [(String,String,String,String)] = [
            ("adelaide","Adelaide","Australia","Australia/Adelaide"), ("singapore","Singapore","Singapore","Asia/Singapore"), ("paris","Paris","France","Europe/Paris"), ("antwerp","Antwerp","Belgium","Europe/Brussels"),
            ("cologne","Cologne","Germany","Europe/Berlin"), ("colonge","Cologne","Germany","Europe/Berlin"), ("hamburg","Hamburg","Germany","Europe/Berlin"), ("hamberg","Hamburg","Germany","Europe/Berlin"),
            ("stockholm","Stockholm","Sweden","Europe/Stockholm"), ("riga","Riga","Latvia","Europe/Riga"), ("gdanksk","Gdańsk","Poland","Europe/Warsaw"), ("gdansk","Gdańsk","Poland","Europe/Warsaw"),
            ("krakow","Kraków","Poland","Europe/Warsaw"), ("prague","Prague","Czechia","Europe/Prague"), ("berlin","Berlin","Germany","Europe/Berlin"), ("london","London","United Kingdom","Europe/London"),
            ("edinburgh","Edinburgh","United Kingdom","Europe/London"), ("endiburagh","Edinburgh","United Kingdom","Europe/London"), ("belfast","Belfast","United Kingdom","Europe/London"), ("dublin","Dublin","Ireland","Europe/Dublin"),
            ("ireland","Ireland — city to confirm","Ireland","Europe/Dublin"), ("lreland","Ireland — city to confirm","Ireland","Europe/Dublin")
        ]
        if let x = known.first(where: { text.contains($0.0) }) { return (x.1,x.2,x.3) }
        let parts = original.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return (parts[0], parts.count > 1 ? parts.dropFirst().joined(separator: ", ") : "Country to confirm", "")
    }
    static func parse(_ text: String) throws -> TripArchive {
        let rows = try rows(text).sorted { $0.date < $1.date }
        var archive = TripArchive.empty
        var setup = archive.setup; setup["depart"] = .string(rows.first!.date); setup["ret"] = .string(rows.last!.date); setup["nat"] = .string("")
        guard !TripDay.days(rows.first!.date, rows.last!.date).isEmpty else { throw TripError.invalid("Table spans more than two years.") }
        var stops: [TripRecord] = [], activities: [TripRecord] = [], bookings: [TripRecord] = [], reviews: [String] = []
        for row in rows {
            let p = place(row.location)
            let key = p.city + "|" + p.country
            if let i = stops.indices.last, stops[i]["city"] + "|" + stops[i]["country"] == key, row.date <= TripDay.shift(stops[i]["to"], by: 1) {
                stops[i]["to"] = max(stops[i]["to"], row.date)
                if !row.travel.isEmpty { stops[i]["travelNote"] = [stops[i]["travelNote"], row.travel].filter { !$0.isEmpty }.joined(separator: "\n") }
            } else {
                var stop = TripRecord.new(); stop["city"] = p.city; stop["country"] = p.country; stop["from"] = row.date; stop["to"] = row.date; stop["travelNote"] = row.travel; if row.travel.lowercased().contains("drive") || row.travel.lowercased().contains("autobahn") || row.travel.lowercased().contains("authbhan") { stop["travelMode"] = "Car" }; stops.append(stop)
            }
            if p.city.contains("city to confirm") { let warning = "Choose the Ireland city for the dates listed in your table."; if !reviews.contains(warning) { reviews.append(warning) } }
            func activity(_ title: String, time: String = "", note: String = "") -> TripRecord {
                var r = TripRecord.new(); r["title"] = title; r["date"] = row.date; r["time"] = time; r["zone"] = ""; r["suggestedZone"] = p.zone; r["note"] = note; r["cost"] = ""; r["cur"] = setup.text("cur"); return r
            }
            let lower = row.location.lowercased()
            if !row.time.isEmpty {
                activities.append(activity((lower.contains("fly out") ? "Flight departure · " : "Arrive · ") + p.city, time: row.time, note: "Copied from itinerary table. Confirm against the actual booking; time zone not confirmed."))
            } else if lower.contains("eat") { activities.append(activity(p.city + " — Eat!")) }
            if !row.travel.isEmpty { activities.append(activity(row.travel, note: "User itinerary note/estimate, not a verified transport duration or reservation.")) }
            if !row.activity.isEmpty {
                let raw = row.activity.lowercased()
                let title: String
                if raw.contains("aschwitz") || raw.contains("auschwitz") {
                    title = "Auschwitz — date/location to review"
                    if p.city == "Prague" { reviews.append("Auschwitz is listed on a Prague day. It is near Oświęcim, Poland: verify the visit date and transport before booking.") }
                } else if raw == "louve" || raw == "louvre" { title = "Louvre — time/ticket to confirm" }
                else if raw.contains("amers") { title = "Day trip ‘amers’ — destination to confirm"; reviews.append("Clarify the ‘amers’ day-trip destination; no city was guessed.") }
                else { title = row.activity }
                activities.append(activity(title, note: "Original note: " + row.activity))
            }
            if !row.accommodation.isEmpty {
                if let i = bookings.firstIndex(where: { $0["t"].lowercased() == row.accommodation.lowercased() && $0["city"] == p.city }) {
                    bookings[i]["listedThrough"] = row.date
                } else {
                    var hotel = TripRecord.new(); hotel["t"] = row.accommodation; hotel["kind"] = "Accommodation"; hotel["city"] = p.city; hotel["listedFrom"] = row.date; hotel["listedThrough"] = row.date; hotel["address"] = row.accommodation + ", " + p.city; hotel["status"] = "Unconfirmed"; hotel["note"] = "Accommodation named in your itinerary. Booking reference, confirmed check-in/out dates and times were not supplied."; bookings.append(hotel)
                }
            }
        }
        archive.setRecords("dests", stops); archive.setRecords("acts", activities); archive.setRecords("docs", bookings)
        var trip = archive.trip; trip["setup"] = .object(setup); trip["importWarnings"] = .array(reviews.map(JSONValue.string)); trip["importedItineraryRows"] = .array(rows.map { .object(["date":.string($0.date),"time":.string($0.time),"location":.string($0.location),"accommodation":.string($0.accommodation),"travel":.string($0.travel),"activity":.string($0.activity)]) }); archive.trip = trip
        try archive.validate(); return archive
    }
    static func keepingExisting(_ existing: TripArchive, updating planned: TripArchive) throws -> TripArchive {
        var next = existing
        next.setRecords("dests", planned.records("dests"))
        var setup = existing.setup; setup["depart"] = planned.setup["depart"]; setup["ret"] = planned.setup["ret"]
        var docs = existing.records("docs")
        for booking in planned.records("docs") {
            if !docs.contains(where: { $0["t"].lowercased() == booking["t"].lowercased() && ($0["date"] == booking["listedFrom"] || $0["listedFrom"] == booking["listedFrom"]) }) { docs.append(booking) }
        }
        var activities = existing.records("acts")
        for activity in planned.records("acts") {
            if !activities.contains(where: { $0["date"] == activity["date"] && ((!activity["time"].isEmpty && $0["time"] == activity["time"]) || $0["title"] == activity["title"]) }) { activities.append(activity) }
        }
        next.setRecords("docs", docs); next.setRecords("acts", activities)
        var trip = next.trip; trip["setup"] = .object(setup); trip["importedItineraryRows"] = planned.trip["importedItineraryRows"]; trip["importWarnings"] = .array(planned.trip.list("importWarnings") + [.string("Existing activities, bookings and files were kept. Review any events from a previous version of the itinerary.")]); next.trip = trip
        try next.validate(); return next
    }

}
