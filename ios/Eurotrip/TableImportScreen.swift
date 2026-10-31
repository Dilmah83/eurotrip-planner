import SwiftUI

struct TableImportScreen: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var preview: TripArchive?
    @State private var error = ""
    @State private var keepExisting = true
    var body: some View {
        Form {
            Section("Paste your itinerary table") {
                Text("Paste the table from chat or notes. It is parsed only on this iPhone and is not uploaded. Your existing trip is kept as a recovery copy when you import.")
                PasteButton(payloadType: String.self) { values in text = values.joined(separator: "\n"); preview = nil }
                TextEditor(text: $text).frame(minHeight: 180).font(.caption).onChange(of: text) { _, _ in preview = nil }
                Button("Preview itinerary") { do { preview = try ItineraryImport.parse(text); error = "" } catch { self.error = error.localizedDescription } }.disabled(text.isEmpty)
            }
            if let preview {
                Section("Ready to import") {
                    Text("\(preview.setup.text("depart")) → \(preview.setup.text("ret"))")
                    Text("\(preview.records("dests").count) stops · \(preview.records("acts").count) activities / notes · \(preview.records("docs").count) named accommodation records")
                    Text("Flight times and estimates are copied, not verified. Unknown transport, cities, booking references and check-in/out times remain unconfirmed. Time zones must be confirmed before Calendar export.").font(.caption)
                    ForEach(preview.trip.list("importWarnings"), id: \.text) { Text($0.text).foregroundStyle(.orange) }
                    Toggle("Keep existing bookings, files and activities", isOn: $keepExisting)
                    Button("Import this itinerary") { do { let next = keepExisting ? try ItineraryImport.keepingExisting(store.archive, updating: preview) : preview; try store.commit(next, snapshot: true); dismiss() } catch { self.error = error.localizedDescription } }
                }
            }
            Text(error).foregroundStyle(.red)
        }.navigationTitle("Import itinerary table")
    }
}
