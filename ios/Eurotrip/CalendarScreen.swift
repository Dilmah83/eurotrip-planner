import SwiftUI
import EventKit
import UserNotifications

struct CalendarScreen: View {
    @EnvironmentObject private var store: TripStore
    @State private var message = ""
    @State private var busy = false
    var body: some View {
        let plan = TripEvents.plan(store.archive)
        List {
            Section("Calendar and optional phone alerts") {
                Text("Only records with explicit local date, time and time zone are included. Incomplete records stay in your itinerary. Confirm time zones with your airline, hotel or operator.")
                Button("Export / update in Calendar") { Task { await calendar(plan.events) } }.disabled(busy || plan.events.isEmpty)
                Button("Schedule next 64 departure / deadline alerts") { Task { await alerts(plan.events) } }.disabled(busy || plan.events.isEmpty)
                Text("Alerts occur at the recorded time. iOS permissions and Focus settings affect delivery. Re-schedule after edits or to replenish the 64-alert horizon. This is not a booking or cancellation service.").font(.caption)
                Text(message)
            }
            Section("Ready to export") { ForEach(plan.events) { event in VStack(alignment: .leading) { Text(event.title); Text(event.start.formatted() + " · " + event.zone).font(.caption) } } }
            Section("Need information") { ForEach(plan.skipped, id: \.self) { Text($0).font(.caption) } }
        }.navigationTitle("Calendar")
    }
    @MainActor func calendar(_ events: [TripEvent]) async {
        busy = true; defer { busy = false }; let ek = EKEventStore()
        do {
            guard try await ek.requestFullAccessToEvents(), let calendar = ek.defaultCalendarForNewEvents else { throw TripError.invalid("Calendar access denied or no writable default calendar.") }
            let dates = events.map(\.start) + [Date()]
            let from = (dates.min() ?? Date()).addingTimeInterval(-730 * 86400), to = (dates.max() ?? Date()).addingTimeInterval(730 * 86400)
            let existing = ek.events(matching: ek.predicateForEvents(withStart: from, end: to, calendars: [calendar])).filter { $0.url?.scheme == "eurotrip-native" }
            var desired = Set<String>()
            for item in events {
                let key = Data(item.id.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
                let marker = "eurotrip-native://event/" + key; desired.insert(marker)
                let event = existing.first { $0.url?.absoluteString == marker } ?? EKEvent(eventStore: ek)
                event.calendar = calendar; event.title = item.title; event.startDate = item.start; event.endDate = item.end; event.timeZone = TimeZone(identifier: item.zone); event.notes = item.notes; event.url = URL(string: marker)
                try ek.save(event, span: .thisEvent, commit: false)
            }
            for event in existing where !desired.contains(event.url?.absoluteString ?? "") { try ek.remove(event, span: .thisEvent, commit: false) }
            try ek.commit(); message = "Updated \(events.count) native Eurotrip events in \(calendar.title). Review them in Calendar."
        } catch { ek.reset(); message = error.localizedDescription }
    }
    @MainActor func alerts(_ events: [TripEvent]) async {
        busy = true; defer { busy = false }
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw TripError.invalid("Notifications are off. Enable them in iPhone Settings.") }
            let old = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: old.filter { $0.identifier.hasPrefix("eurotrip:") }.map(\.identifier))
            let available = max(0, 64 - old.filter { !$0.identifier.hasPrefix("eurotrip:") }.count)
            let upcoming = Array(events.filter { $0.start > Date() }.prefix(available))
            for event in upcoming {
                let content = UNMutableNotificationContent(); content.title = "Eurotrip reminder"; content.body = "A saved trip event or deadline is due. Open Eurotrip for details."; content.sound = .default
                let delay = event.start.timeIntervalSinceNow
                guard delay > 0 else { continue }
                try await center.add(UNNotificationRequest(identifier: "eurotrip:" + event.id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)))
            }
            message = upcoming.last.map { "Scheduled \(upcoming.count) private alerts through \($0.start.formatted()). Re-schedule after edits or to extend this horizon." } ?? "No future dated events to notify."
        } catch { message = error.localizedDescription }
    }
}
