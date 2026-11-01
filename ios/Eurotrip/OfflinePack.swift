import Foundation

enum TravelLinks {
    static func url(_ text: String) -> URL? { guard let url = URL(string: text), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil, url.user == nil, url.password == nil else { return nil }; return url }
    static func maps(_ address: String) -> URL? { guard !address.isEmpty else { return nil }; var u = URLComponents(string: "https://maps.apple.com/")!; u.queryItems = [URLQueryItem(name: "q", value: address)]; return u.url }
}
enum OfflinePack {
    static func escape(_ text: String) -> String { text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;") }
    static func html(_ archive: TripArchive) throws -> Data {
        try archive.validate()
        var body = "<h1>Eurotrip offline travel pack</h1><p>Private snapshot. Times and booking status are as entered; verify with operators. External links require internet.</p>"
        for stop in archive.records("dests").sorted(by: { $0["from"] < $1["from"] }) { body += "<section><h2>\(escape(stop["city"])), \(escape(stop["country"]))</h2><p>\(escape(stop["from"])) → \(escape(stop["to"]))</p><p>\(escape(stop["travelNote"]))</p></section>" }
        body += "<h2>Bookings</h2>"
        for booking in archive.records("docs") {
            body += "<section><h3>\(escape(booking["t"]))</h3><p>\(escape(booking["kind"])) · \(escape(booking["ref"]))</p><p>\(escape(booking["date"])) \(escape(booking["time"])) \(escape(booking["tz"])) → \(escape(booking["end"])) \(escape(booking["endTime"])) \(escape(booking["arrivalTz"]))</p><p>\(escape(booking["address"]))</p><p>\(escape(booking["note"]))</p>"
            if let url = TravelLinks.url(booking["url"]) { body += "<a href=\"\(escape(url.absoluteString))\">Booking website</a>" }
            for file in archive.files where file.id == booking.id { body += "<p><a download=\"\(escape(file.name))\" href=\"\(escape(file.data))\">Open saved file: \(escape(file.name))</a></p>" }
            body += "</section>"
        }
        body += "<h2>Activities</h2>"
        for activity in archive.records("acts").sorted(by: { $0["date"] + $0["time"] < $1["date"] + $1["time"] }) { body += "<section><b>\(escape(activity["date"])) \(escape(activity["time"])) \(escape(activity["zone"]))</b><p>\(escape(activity["title"]))</p><p>\(escape(activity["note"]))</p></section>" }
        body += "<h2>Packing</h2>" + archive.trip.list("pack").map { "<p>\($0.object["done"]?.bool == true ? "✓" : "☐") \(escape($0.object.text("t")))</p>" }.joined()
        return Data(("<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Eurotrip offline travel pack</title><style>body{font:17px/1.5 system-ui;max-width:760px;margin:auto;padding:20px;color:#14213d;background:#f4f6f8}section{background:white;border:1px solid #ccd;padding:16px;margin:12px 0;border-radius:14px}p{white-space:pre-wrap}a{overflow-wrap:anywhere}</style>" + body + "</html>").utf8)
    }
}
