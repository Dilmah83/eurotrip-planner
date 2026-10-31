import Foundation

enum JSONValue: Codable, Equatable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Decimal), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode(Decimal.self) { self = .number(value) }
        else if let value = try? c.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .object(let x): try c.encode(x); case .array(let x): try c.encode(x); case .string(let x): try c.encode(x); case .number(let x): try c.encode(x); case .bool(let x): try c.encode(x); case .null: try c.encodeNil() }
    }
    var object: [String: JSONValue] { if case .object(let x) = self { return x }; return [:] }
    var array: [JSONValue] { if case .array(let x) = self { return x }; return [] }
    var text: String {
        switch self { case .string(let x): return x; case .number(let x): return NSDecimalNumber(decimal: x).stringValue; case .bool(let x): return x ? "true" : "false"; default: return "" }
    }
    var decimal: Decimal? { if case .number(let x) = self { return x }; return Decimal(string: text) }
    var bool: Bool { if case .bool(let x) = self { return x }; return false }
}
extension Dictionary where Key == String, Value == JSONValue {
    func text(_ key: String) -> String { self[key]?.text ?? "" }
    func list(_ key: String) -> [JSONValue] { self[key]?.array ?? [] }
}
struct TripRecord: Identifiable, Equatable {
    var fields: [String: JSONValue]
    var id: String { fields.text("id") }
    subscript(_ key: String) -> String {
        get { fields.text(key) }
        set { fields[key] = .string(newValue) }
    }
    static func new() -> TripRecord { .init(fields: ["id": .string(UUID().uuidString)]) }
}
enum TripError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let x) = self { return x }; return nil }
}
enum TripDay {
    static func date(_ text: String) -> Date? {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard text.count == 10, let d = f.date(from: text), f.string(from: d) == text else { return nil }; return d
    }
    static func string(_ date: Date, zone: TimeZone = .current) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func shift(_ day: String, by amount: Int) -> String {
        guard let value = date(day) else { return day }
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!
        return string(c.date(byAdding: .day, value: amount, to: value)!, zone: c.timeZone)
    }
    static func days(_ from: String, _ to: String) -> [String] {
        guard let a = date(from), let b = date(to), b >= a, b.timeIntervalSince(a) <= 730 * 86400 else { return [] }
        var result: [String] = [], day = from
        while day <= to { result.append(day); day = shift(day, by: 1) }; return result
    }
    static func timeValid(_ s: String) -> Bool { s.range(of: #"^([01][0-9]|2[0-3]):[0-5][0-9]$"#, options: .regularExpression) != nil }
    static func instant(day: String, time: String, zone: String) -> Date? {
        guard date(day) != nil, timeValid(time), let z = TimeZone(identifier: zone), !zone.isEmpty else { return nil }
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = z; f.dateFormat = "yyyy-MM-dd HH:mm"; f.isLenient = false
        let text = day + " " + time
        guard let value = f.date(from: text), f.string(from: value) == text else { return nil }
        for seconds in [1800.0, 3600, 5400, 7200] { if f.string(from: value.addingTimeInterval(seconds)) == text || f.string(from: value.addingTimeInterval(-seconds)) == text { return nil } }
        return value
    }
}
struct TripAttachment: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var data: String
    var bytes: Data? {
        guard let comma = data.firstIndex(of: ","), data.hasPrefix("data:"), data[..<comma].hasSuffix(";base64") else { return nil }
        return Data(base64Encoded: String(data[data.index(after: comma)...]))
    }
    var mime: String { String(data.dropFirst(5).prefix(while: { $0 != ";" })) }
    static let extensions = ["pdf", "png", "jpg", "jpeg", "webp", "txt"]
    func validate(bookingIDs: Set<String>) throws {
        let ext = (name as NSString).pathExtension.lowercased()
        guard bookingIDs.contains(id), !name.isEmpty, name.count <= 250, !name.contains("/"), !name.contains("\\"), Self.extensions.contains(ext),
              ["application/pdf", "image/png", "image/jpeg", "image/webp", "text/plain", "application/octet-stream"].contains(mime),
              let bytes, bytes.count <= 10 * 1024 * 1024 else { throw TripError.invalid("Invalid or oversized booking attachment.") }
    }
}
struct TripArchive: Codable, Equatable {
    var root: [String: JSONValue]
    var trip: [String: JSONValue] {
        get { root["trip"]?.object ?? [:] }
        set { root["trip"] = .object(newValue) }
    }
    var setup: [String: JSONValue] { trip["setup"]?.object ?? [:] }
    var files: [TripAttachment] {
        get { root.list("files").compactMap { value in let x = value.object; guard !x.text("id").isEmpty else { return nil }; return TripAttachment(id: x.text("id"), name: x.text("name"), data: x.text("data")) } }
        set { root["files"] = .array(newValue.map { .object(["id": .string($0.id), "name": .string($0.name), "data": .string($0.data)]) }) }
    }
    init(root: [String: JSONValue]) { self.root = root }
    init(from decoder: Decoder) throws { root = try decoder.singleValueContainer().decode([String: JSONValue].self) }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(root) }
    static var empty: TripArchive {
        var s: [String: JSONValue] = ["home": .string("Adelaide, Australia"), "depart": .string(""), "ret": .string(""), "nat": .string("Australian"), "pexp": .string(""), "trav": .number(1), "budget": .number(0), "cur": .string("AUD"), "pace": .string("Balanced"), "diet": .string("")]
        s["homeZone"] = .string(TimeZone.current.identifier)
        var t: [String: JSONValue] = ["setup": .object(s), "version": .number(3), "seeded": .number(1), "rates": .object([:]), "legs": .object([:]), "rail": .object(["kind": .string("Flexi"), "days": .number(15), "price": .string(""), "cur": .string("EUR")]), "etias": .object(["status": .string("Needs manual verification"), "checked": .string("")]), "checked": .object([:]), "prior": .array([])]
        for key in ["dests", "acts", "exp", "pack", "docs"] { t[key] = .array([]) }
        return .init(root: ["format": .string("eurotrip-backup"), "version": .number(3), "trip": .object(t), "files": .array([])])
    }
    static func decode(_ data: Data) throws -> TripArchive {
        guard data.count <= 50 * 1024 * 1024 else { throw TripError.invalid("Backup exceeds 50 MB.") }
        let object = try JSONDecoder().decode([String: JSONValue].self, from: data)
        var archive: TripArchive
        if object["trip"] != nil {
            guard ["", "eurotrip-backup"].contains(object.text("format")), ["1", "2", "3"].contains(object.text("version")) else { throw TripError.invalid("Unsupported Eurotrip backup format/version.") }
            archive = .init(root: object)
        } else { archive = .empty; archive.trip = object }
        try archive.validate(); return archive
    }
    func encoded() throws -> Data { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; let d = try e.encode(self); guard d.count <= 50 * 1024 * 1024 else { throw TripError.invalid("Backup exceeds 50 MB; keep copies of large attachments separately.") }; return d }
    func records(_ key: String) -> [TripRecord] { trip.list(key).map { TripRecord(fields: $0.object) } }
    mutating func setRecords(_ key: String, _ records: [TripRecord]) { var t = trip; t[key] = .array(records.map { .object($0.fields) }); trip = t }
    func destinations(on day: String) -> [TripRecord] { records("dests").filter { $0["from"] <= day && day <= $0["to"] }.sorted { $0["from"] < $1["from"] } }
    func bookings(on day: String) -> [TripRecord] {
        records("docs").filter { r in
            if r["date"] == day || r["end"] == day { return true }
            if !r["listedFrom"].isEmpty && r["listedFrom"] <= day && day <= r["listedThrough"] { return true }
            return r["kind"] == "Accommodation" && !r["date"].isEmpty && r["date"] <= day && day <= r["end"]
        }
    }
    func previewDay(today: String = TripDay.string(Date())) -> String {
        let a = setup.text("depart"), b = setup.text("ret")
        guard TripDay.date(a) != nil, TripDay.date(b) != nil else { return today }
        return min(max(today, a), b)
    }
    func validate() throws {
        guard case .object? = trip["setup"] else { throw TripError.invalid("Missing trip setup.") }
        for key in ["dests", "acts", "exp", "pack", "docs"] {
            guard case .array(let values)? = trip[key], values.count <= 10_000 else { throw TripError.invalid("Invalid \(key) list.") }
        }
        guard setup.text("cur").range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil else { throw TripError.invalid("Use a three-letter home currency.") }
        if setup.text("trav").range(of: #"^[0-9]{1,3}$"#, options: .regularExpression) == nil || (setup["trav"]?.decimal ?? 0) < 1 || (setup["trav"]?.decimal ?? 0) > 100 { throw TripError.invalid("Traveller count must be a whole number from 1 to 100.") }
        for field in ["depart", "ret", "pexp"] { let s = setup.text(field); if !s.isEmpty && TripDay.date(s) == nil { throw TripError.invalid("Invalid \(field) date.") } }
        let a = setup.text("depart"), b = setup.text("ret")
        if !a.isEmpty && !b.isEmpty && TripDay.days(a,b).isEmpty { throw TripError.invalid("Trip dates must be ordered and at most two years apart.") }
        for key in ["dests", "acts", "docs", "exp"] {
            let records = records(key)
            guard records.allSatisfy({ !$0.id.isEmpty }), Set(records.map(\.id)).count == records.count else { throw TripError.invalid("Duplicate or missing \(key) identities.") }
            for record in records { try Self.validate(record, type: key, strict: false) }
        }
        for p in trip.list("pack") { guard case .string? = p.object["t"], case .bool? = p.object["done"] else { throw TripError.invalid("Invalid packing item.") } }
        guard root.list("files").count == files.count, files.count <= 500, Set(files.map(\.id)).count == files.count else { throw TripError.invalid("Invalid attachment list.") }
        for file in files { try file.validate(bookingIDs: Set(records("docs").map(\.id))) }
    }
    static func validate(_ r: TripRecord, type: String, strict: Bool = true) throws {
        let required: [String]
        switch type { case "dests": required = ["city", "country", "from", "to"]; case "acts": required = ["title", "date"]; case "docs": required = ["t"]; default: required = [] }
        guard required.allSatisfy({ !r[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw TripError.invalid("Complete the required fields.") }
        for key in ["from", "to", "date", "end", "cancel", "due"] { if !r[key].isEmpty && TripDay.date(r[key]) == nil { throw TripError.invalid("Use YYYY-MM-DD for \(key).") } }
        for key in ["time", "endTime", "cancelTime"] { if strict && !r[key].isEmpty && !TripDay.timeValid(r[key]) { throw TripError.invalid("Use 24-hour HH:mm for \(key).") } }
        for key in ["tz", "arrivalTz", "cancelTz", "zone"] { if strict && !r[key].isEmpty && TimeZone(identifier: r[key]) == nil { throw TripError.invalid("Use a valid IANA time zone, such as Europe/Paris.") } }
        if type == "dests" && TripDay.days(r["from"], r["to"]).isEmpty { throw TripError.invalid("Destination dates must be ordered and within two years.") }
        if strict && type == "docs", let start = TripDay.instant(day: r["date"], time: r["time"], zone: r["tz"]), let end = TripDay.instant(day: r["end"], time: r["endTime"], zone: r["arrivalTz"]), end < start { throw TripError.invalid("Arrival is earlier than departure after converting both time zones.") }
    }
}
