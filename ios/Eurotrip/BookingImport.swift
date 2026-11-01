import Foundation

struct BookingExtraction {
    var record: TripRecord
    var warnings: [String]
}
// Conservative parsing of locally recognised text: only labelled fields, no inferred bookings.
enum BookingImport {
    static func parse(_ text: String) throws -> BookingExtraction {
        guard text.utf8.count <= 60_000 else { throw TripError.invalid("Too much text. Crop the screenshot to one booking.") }
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { throw TripError.invalid("No readable text found. Try a clearer screenshot or add the booking manually.") }
        let fieldLabels = Set(["hotel name","property name","hotel","property","flight number","flight no","flight","booking reference","confirmation number","confirmation code","booking number","reservation number","pnr","departure date","departing","departure","departs","arrival date","arriving","arrival","arrives","check-in date","check-in","check in","check-out date","check-out","check out","departure time","arrival time","check-in time","check-out time","hotel address","property address","address","departure airport","arrival airport","from","to"])
        func value(_ labels: [String]) -> String {
            for lineIndex in lines.indices {
                for label in labels {
                    let pattern = "^" + NSRegularExpression.escapedPattern(for: label) + #"\s*(?::|：|\s[-–]\s)\s*(.+)$"#
                    if let r = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive), let m = r.firstMatch(in: lines[lineIndex], range: NSRange(lines[lineIndex].startIndex..., in: lines[lineIndex])) { return (lines[lineIndex] as NSString).substring(with: m.range(at: 1)) }
                    if lines[lineIndex].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":：")) == label.lowercased(), lines.indices.contains(lineIndex + 1) { let next = lines[lineIndex + 1]; if !fieldLabels.contains(next.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":："))), !next.contains(":") || time(next) != nil { return next } }
                }
            }
            return ""
        }
        let labelledHotel = value(["Hotel name", "Property name", "Hotel", "Property"])
        let hotel = labelledHotel.isEmpty ? (lines.prefix(5).first { $0.range(of: #"\bhotel\b"#, options:[.regularExpression,.caseInsensitive]) != nil && !$0.lowercased().contains("confirmation") && !$0.lowercased().contains("booking") && $0.count < 100 } ?? "") : labelledHotel
        let flight = value(["Flight number", "Flight no", "Flight"])
        let isFlight = !flight.isEmpty || text.range(of: #"\b(boarding pass|flight confirmation|departure airport)\b"#, options: [.regularExpression,.caseInsensitive]) != nil || (hotel.isEmpty && !value(["Departure", "Departure date"]).isEmpty && !value(["Arrival", "Arrival date"]).isEmpty)
        var r = TripRecord.new(); r["kind"] = isFlight ? "Flight" : "Accommodation"
        r["t"] = isFlight ? (flight.isEmpty ? "Flight — review screenshot" : flight) : hotel
        r["ref"] = value(["Booking reference", "Confirmation number", "Confirmation code", "Booking number", "Reservation number", "PNR"])
        // Do not populate authentication PINs, passenger names or unlabelled numbers as references.
        let start = value(isFlight ? ["Departure date", "Departing", "Departure", "Departs"] : ["Check-in date", "Check-in", "Check in"])
        let end = value(isFlight ? ["Arrival date", "Arriving", "Arrival", "Arrives"] : ["Check-out date", "Check-out", "Check out"])
        r["date"] = date(start) ?? ""; r["end"] = date(end) ?? ""
        r["time"] = time(value(isFlight ? ["Departure time"] : ["Check-in time"])) ?? time(start) ?? ""
        r["endTime"] = time(value(isFlight ? ["Arrival time"] : ["Check-out time"])) ?? time(end) ?? ""
        r["address"] = value(isFlight ? ["Departure airport", "From"] : ["Hotel address", "Property address", "Address"])
        let destination = value(["Arrival airport", "To"])
        if isFlight && !destination.isEmpty { r["address"] = [r["address"],destination].filter { !$0.isEmpty }.joined(separator: " → ") }
        r["status"] = "Screenshot — reviewed details required"
        r["note"] = "Imported from screenshot using on-device text recognition. Verify with the original booking.\n\nRecognised text:\n" + text
        r["importSource"] = "on-device-screenshot"; r["importedAt"] = ISO8601DateFormatter().string(from: Date())
        var warnings = ["Text recognition can be wrong. Check the name, reference, dates and local times before saving.", "Time zones are not inferred. Calendar export needs confirmed time zones; add these below or later.", "Import one hotel stay or one flight leg at a time. Multi-leg/return bookings must be reviewed and saved separately."]
        if r["t"].isEmpty { warnings.append("Booking name was not identified. Enter it before saving.") }
        if r["date"].isEmpty { warnings.append("Start date is missing or ambiguous. Numeric dates such as 03/04/2027 and dates without a year are left blank.") }
        if !end.isEmpty && r["end"].isEmpty { warnings.append("End date could not be read unambiguously. Check the original.") }
        return .init(record: r, warnings: warnings)
    }
    static func date(_ text: String) -> String? {
        func match(_ pattern: String) -> String? { guard let range = text.range(of: pattern, options: [.regularExpression,.caseInsensitive]) else { return nil }; return String(text[range]) }
        if let iso = match(#"\b\d{4}-\d{2}-\d{2}\b"#), TripDay.date(iso) != nil { return iso }
        if let numeric = match(#"\b\d{1,2}/\d{1,2}/\d{4}\b"#) {
            let p = numeric.split(separator: "/").compactMap { Int($0) }
            // A locale is not proof of the source document's date order.
            if p.count == 3, p[0] > 12, p[1] <= 12 { let iso = String(format:"%04d-%02d-%02d",p[2],p[1],p[0]); return TripDay.date(iso) == nil ? nil : iso }
            return nil
        }
        let patterns = [(#"\b\d{1,2}\s+[A-Za-z]+\s+\d{4}\b"#,["d MMM yyyy","d MMMM yyyy"]),(#"\b[A-Za-z]+\s+\d{1,2},?\s+\d{4}\b"#,["MMM d, yyyy","MMMM d, yyyy","MMM d yyyy","MMMM d yyyy"])]
        for (pattern, formats) in patterns { if let raw = match(pattern) { for format in formats { let f=DateFormatter(); f.locale=Locale(identifier:"en_US_POSIX"); f.timeZone=TimeZone(secondsFromGMT:0); f.dateFormat=format; f.isLenient=false; if let d=f.date(from:raw) { return TripDay.string(d) } } } }
        return nil
    }
    static func time(_ text: String) -> String? {
        let pattern = #"\b([0-9]{1,2}):([0-9]{2})\s*(AM|PM)?\b"#
        guard let re=try? NSRegularExpression(pattern:pattern,options:.caseInsensitive),let m=re.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)) else{return nil}
        let ns=text as NSString;guard var h=Int(ns.substring(with:m.range(at:1))),let min=Int(ns.substring(with:m.range(at:2))),min<60 else{return nil}
        if m.range(at:3).location != NSNotFound { guard h>=1 && h<=12 else{return nil};let period=ns.substring(with:m.range(at:3)).uppercased();h=h%12+(period=="PM" ? 12:0) }
        guard h<24 else{return nil};return String(format:"%02d:%02d",h,min)
    }
}
