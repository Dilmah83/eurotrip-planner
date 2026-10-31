import Foundation
import SwiftUI

@MainActor final class TripStore: ObservableObject {
    @Published private(set) var archive = TripArchive.empty
    @Published var message = ""
    @Published var storageError: String?
    private let file: URL
    private let recovery: URL
    init(directory: URL? = nil) {
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Eurotrip")
        file = folder.appendingPathComponent("trip.json"); recovery = folder.appendingPathComponent("before-change.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { archive = try TripArchive.decode(Data(contentsOf: file)) }
        } catch { storageError = "Existing data could not be read and has not been changed: " + error.localizedDescription }
    }
    func originalData() throws -> Data { try Data(contentsOf: file) }
    var canUndo: Bool { FileManager.default.fileExists(atPath: recovery.path) }
    func commit(_ next: TripArchive, snapshot: Bool = false) throws {
        guard storageError == nil else { throw TripError.invalid("Storage needs recovery. Existing data was not overwritten.") }
        try next.validate(); let data = try next.encoded()
        if snapshot { try archive.encoded().write(to: recovery, options: [.atomic, .completeFileProtection]) }
        try data.write(to: file, options: [.atomic, .completeFileProtection]); archive = next
    }
    func save(_ record: TripRecord, type: String) throws {
        try TripArchive.validate(record, type: type)
        var next = archive; var records = next.records(type)
        if let index = records.firstIndex(where: { $0.id == record.id }) { records[index] = record } else { records.append(record) }
        next.setRecords(type, records); try commit(next)
    }
    func delete(_ id: String, type: String) {
        do {
            var next = archive; next.setRecords(type, next.records(type).filter { $0.id != id })
            if type == "docs" { next.files.removeAll { $0.id == id } }
            try commit(next, snapshot: true); message = "Deleted. Undo is available in More."
        } catch { message = error.localizedDescription }
    }
    func updateSetup(_ values: [String: JSONValue]) throws { var next = archive; var t = next.trip; t["setup"] = .object(values); next.trip = t; try commit(next) }
    func togglePacking(_ index: Int) {
        do { var next = archive; var t = next.trip; var p = t.list("pack"); guard p.indices.contains(index) else { return }; var item = p[index].object; item["done"] = .bool(!(item["done"]?.bool ?? false)); p[index] = .object(item); t["pack"] = .array(p); next.trip = t; try commit(next) } catch { message = error.localizedDescription }
    }
    func addPacking(_ text: String) throws { var next = archive; var t = next.trip; var p = t.list("pack"); p.append(.object(["t": .string(text), "done": .bool(false)])); t["pack"] = .array(p); next.trip = t; try commit(next) }
    func removePacking(_ index: Int) throws { var next = archive; var t = next.trip; var p = t.list("pack"); guard p.indices.contains(index) else { return }; p.remove(at: index); t["pack"] = .array(p); next.trip = t; try commit(next, snapshot: true) }
    func importData(_ data: Data) throws { let next = try TripArchive.decode(data); try commit(next, snapshot: true); message = "Imported trip, attachments and preserved legacy fields. Previous trip can be restored in More." }
    func undo() throws { let previous = try TripArchive.decode(Data(contentsOf: recovery)); try commit(previous); message = "Previous trip restored." }
    func attach(_ data: Data, name: String, booking: String) throws {
        guard data.count <= 10 * 1024 * 1024 else { throw TripError.invalid("Attachment limit is 10 MB.") }
        let ext = (name as NSString).pathExtension.lowercased()
        let mime = ["pdf":"application/pdf","png":"image/png","jpg":"image/jpeg","jpeg":"image/jpeg","webp":"image/webp","txt":"text/plain"][ext] ?? "application/octet-stream"
        let attachment = TripAttachment(id: booking, name: (name as NSString).lastPathComponent, data: "data:\(mime);base64," + data.base64EncodedString())
        var next = archive; next.files.removeAll { $0.id == booking }; next.files.append(attachment); try commit(next, snapshot: true)
    }
    func previewFile(_ id: String) throws -> URL {
        guard let attachment = archive.files.first(where: { $0.id == id }), let bytes = attachment.bytes else { throw TripError.invalid("No offline attachment for this booking.") }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Eurotrip-preview")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent(UUID().uuidString + "-" + attachment.name)
        try bytes.write(to: path, options: [.atomic, .completeFileProtection]); return path
    }
    var summary: String {
        let s = archive.setup
        return "EUROTRIP\n\(s.text("depart")) – \(s.text("ret"))\n\n" + archive.records("dests").sorted { $0["from"] < $1["from"] }.map { "\($0["from"]) – \($0["to"]): \($0["city"]), \($0["country"])" }.joined(separator: "\n") + "\n\nBookings\n" + archive.records("docs").map { "\($0["t"]) [\($0["kind"])]\n\($0["date"]) \($0["time"]) \($0["tz"]) → \($0["end"]) \($0["endTime"]) \($0["arrivalTz"])\n\($0["address"])\nRef: \($0["ref"])\n\($0["note"])" }.joined(separator: "\n\n") + "\n\nLocal times as entered. This shared text does not include attached files; export a full JSON backup to preserve them."
    }
}
