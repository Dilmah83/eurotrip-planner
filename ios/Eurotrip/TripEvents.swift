import Foundation

struct TripEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let zone: String
    let notes: String
}
enum TripEvents {
    static func plan(_ archive: TripArchive) -> (events: [TripEvent], skipped: [String]) {
        var events: [TripEvent] = [], skipped: [String] = []
        for kind in ["acts", "docs"] {
            for record in archive.records(kind) {
                let title = record[kind == "acts" ? "title" : "t"]
                let zone = record[kind == "acts" ? "zone" : "tz"]
                guard let start = TripDay.instant(day: record["date"], time: record["time"], zone: zone) else { skipped.append(title + ": enter a date, time and valid time zone to export."); continue }
                let arrival = kind == "docs" ? TripDay.instant(day: record["end"], time: record["endTime"], zone: record["arrivalTz"]) : nil
                let end = arrival.map { $0 > start ? $0 : start.addingTimeInterval(900) } ?? start.addingTimeInterval(900)
                events.append(TripEvent(id: kind + ":" + record.id, title: title, start: start, end: end, zone: zone, notes: [record["address"], record["ref"], record["note"]].filter { !$0.isEmpty }.joined(separator: "\n")))
                if kind == "docs", !record["cancel"].isEmpty {
                    if let cancellation = TripDay.instant(day: record["cancel"], time: record["cancelTime"], zone: record["cancelTz"].isEmpty ? zone : record["cancelTz"]) {
                        events.append(TripEvent(id: "cancel:" + record.id, title: "Cancellation deadline: " + title, start: cancellation, end: cancellation.addingTimeInterval(900), zone: record["cancelTz"].isEmpty ? zone : record["cancelTz"], notes: "Check your booking terms."))
                    } else { skipped.append(title + ": cancellation time/zone incomplete.") }
                }
            }
        }
        return (events.sorted { $0.start < $1.start }, skipped)
    }
}
