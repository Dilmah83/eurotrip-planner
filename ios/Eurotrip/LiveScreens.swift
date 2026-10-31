import SwiftUI

struct ExploreScreen: View {
    var body: some View {
        List {
            NavigationLink { NearbyScreen() } label: { Label("Nearby places and native Maps", systemImage: "map") }
            NavigationLink { RailScreen() } label: { Label("National rail timetables", systemImage: "tram") }
            NavigationLink { RatesScreen() } label: { Label("Exchange-rate converter", systemImage: "arrow.left.arrow.right") }
            NavigationLink { WeatherScreen() } label: { Label("Weather forecast", systemImage: "cloud.sun") }
            NavigationLink { SafetyScreen() } label: { Label("Official crime figures and travel advice", systemImage: "shield") }
            NavigationLink { WebSearchScreen() } label: { Label("Travel web search · Brave", systemImage: "magnifyingglass") }
            Text("Live lookups use your existing Eurotrip backend. Provider failures, unsupported countries and missing credentials are shown explicitly. Saved plans remain available offline.").font(.caption)
        }.navigationTitle("Explore")
    }
}
struct LiveResult: View {
    let value: JSONValue
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case .object(let fields) = value {
                ForEach(fields.keys.sorted(), id: \.self) { key in
                    if !["id", "lat", "lon", "offset"].contains(key) { ValueRow(label: friendly(key), value: fields[key]!) }
                }
            } else { ValueRow(label: "Result", value: value) }
        }
    }
    func friendly(_ key: String) -> String { ["fetchedAt":"Checked", "tmax":"Maximum °C", "tmin":"Minimum °C", "rainProb":"Rain probability %", "scheduled":"Scheduled local time", "predicted":"Predicted local time", "delayMinutes":"Delay (minutes)", "source":"Source", "coverage":"Coverage", "published":"Published", "description":"Description", "by":"By category"][key] ?? key.replacingOccurrences(of: "_", with: " ").capitalized }
}
struct ValueRow: View {
    let label: String
    let value: JSONValue
    var body: some View {
        switch value {
        case .object:
            DisclosureGroup(label) { AnyView(LiveResult(value: value)) }
        case .array(let values):
            VStack(alignment: .leading, spacing: 10) { Text(label).font(.headline); if values.isEmpty { Text("No results supplied.").foregroundStyle(.secondary) }; ForEach(Array(values.enumerated()), id: \.offset) { _, element in AnyView(LiveResult(value: element)) } }
        case .null: Text(label + ": not supplied").font(.caption).foregroundStyle(.secondary)
        default:
            if let url = TravelLinks.url(value.text), value.text.hasPrefix("http") { Link(label, destination: url) }
            else { Text(label + ": " + value.text).textSelection(.enabled) }
        }
    }
}
struct WeatherScreen: View {
    @State var city = ""
    @State var date = TripDay.string(Date())
    @State private var result: JSONValue?
    @State private var error = ""
    @State private var busy = false
    var body: some View {
        Form {
            TextField("City", text: $city)
            DateEntry(label: "Forecast date", text: $date, optional: false)
            Button(busy ? "Loading…" : "Get forecast") { Task { busy = true; error = ""; result = nil; defer { busy = false }; do { result = try await TravelClient.current().request("weather", query: ["city":city,"date":date]) } catch { self.error = error.localizedDescription } } }.disabled(busy || city.isEmpty)
            Text("Forecasts cover the provider's supported horizon, about 16 days. Outside that range, the app reports unavailable rather than inventing a forecast.").font(.caption)
            Text(error).foregroundStyle(.orange)
            if let result { LiveResult(value: result) }
        }.navigationTitle("Weather")
    }
}
struct RatesScreen: View {
    @State private var base = "AUD"
    @State private var to = "EUR"
    @State private var amount = "100"
    @State private var result: JSONValue?
    @State private var error = ""
    @State private var busy = false
    let currencies = ["AUD","EUR","GBP","SGD","CHF","DKK","SEK","NOK","PLN","CZK","USD","NZD","CAD","JPY"]
    var body: some View {
        Form {
            TextField("Amount", text: $amount).keyboardType(.decimalPad)
            Picker("From", selection: $base) { ForEach(currencies, id: \.self) { Text($0) } }.onChange(of: base) { _, _ in result = nil }
            Picker("To", selection: $to) { ForEach(currencies, id: \.self) { Text($0) } }
            if let value = Decimal(string: amount), value >= 0, let rate = result?.object["rates"]?.object[to]?.decimal { Text("\(value * rate) \(to)").font(.title2.bold()) }
            Button(busy ? "Loading…" : "Refresh reference rates") { Task { await refresh() } }.disabled(busy)
            Text("Latest published reference rates, not bank/card or real-time trading rates. Weekends can retain the preceding business day's date.").font(.caption)
            Text(error).foregroundStyle(.orange)
            if let result { LiveResult(value: result) }
        }.navigationTitle("Rates")
    }
    @MainActor func refresh() async { busy = true; error = ""; result = nil; let requested = base; defer { busy = false }; do { let value = try await TravelClient.current().request("rates", query: ["base":requested]); if base == requested { result = value } } catch { self.error = error.localizedDescription } }
}
struct RailProvider: Identifiable {
    let id: String; let name: String; let website: String; let api: String?
}
struct RailScreen: View {
    @AppStorage("eurotrip.rail.country") private var country = "CH"
    @State private var from = ""
    @State private var to = ""
    @State private var date = TripDay.string(Date())
    @State private var time = "08:00"
    @State private var result: JSONValue?
    @State private var error = ""
    @State private var busy = false
    static let providers: [RailProvider] = [
        .init(id:"CH",name:"Switzerland · SBB",website:"https://www.sbb.ch/en/",api:"ch"),
        .init(id:"DE",name:"Germany · Deutsche Bahn",website:"https://int.bahn.de/en",api:"de"),
        .init(id:"AT",name:"Austria · ÖBB",website:"https://www.oebb.at/en/",api:nil),
        .init(id:"BE",name:"Belgium · SNCB / NMBS",website:"https://www.belgiantrain.be/en/",api:nil),
        .init(id:"BA",name:"Bosnia and Herzegovina · ŽFBH / ŽRS",website:"https://www.zfbh.ba/",api:nil),
        .init(id:"BG",name:"Bulgaria · BDZ",website:"https://www.bdz.bg/en",api:nil),
        .init(id:"HR",name:"Croatia · HŽPP",website:"https://www.hzpp.hr/",api:nil),
        .init(id:"CZ",name:"Czechia · České dráhy",website:"https://www.cd.cz/en/",api:nil),
        .init(id:"DK",name:"Denmark · DSB",website:"https://www.dsb.dk/en/",api:nil),
        .init(id:"EE",name:"Estonia · Elron",website:"https://elron.ee/en",api:nil),
        .init(id:"FI",name:"Finland · VR",website:"https://www.vr.fi/en",api:nil),
        .init(id:"FR",name:"France · SNCF Connect",website:"https://www.sncf-connect.com/en-en/",api:nil),
        .init(id:"GR",name:"Greece · Hellenic Train",website:"https://www.hellenictrain.gr/en",api:nil),
        .init(id:"HU",name:"Hungary · MÁV",website:"https://www.mavcsoport.hu/en",api:nil),
        .init(id:"IE",name:"Ireland · Iarnród Éireann",website:"https://www.irishrail.ie/en-ie/",api:nil),
        .init(id:"IT",name:"Italy · Trenitalia",website:"https://www.trenitalia.com/en.html",api:nil),
        .init(id:"LV",name:"Latvia · Vivi",website:"https://www.vivi.lv/en/",api:nil),
        .init(id:"LT",name:"Lithuania · LTG Link",website:"https://ltglink.lt/en",api:nil),
        .init(id:"LU",name:"Luxembourg · CFL",website:"https://www.cfl.lu/en-gb",api:nil),
        .init(id:"MD",name:"Moldova · CFM",website:"https://www.railway.md/",api:nil),
        .init(id:"ME",name:"Montenegro · ŽPCG",website:"https://www.zpcg.me/",api:nil),
        .init(id:"NL",name:"Netherlands · NS",website:"https://www.ns.nl/en",api:nil),
        .init(id:"MK",name:"North Macedonia · MŽ Transport",website:"https://mzt.mk/",api:nil),
        .init(id:"NO",name:"Norway · Entur",website:"https://entur.no/",api:nil),
        .init(id:"PL",name:"Poland · PKP journey planner",website:"https://portalpasazera.pl/en",api:nil),
        .init(id:"PT",name:"Portugal · CP",website:"https://www.cp.pt/",api:nil),
        .init(id:"RO",name:"Romania · CFR Călători",website:"https://www.cfrcalatori.ro/en/",api:nil),
        .init(id:"RS",name:"Serbia · Srbija Voz",website:"https://srbijavoz.rs/",api:nil),
        .init(id:"SK",name:"Slovakia · ZSSK",website:"https://www.zssk.sk/en/",api:nil),
        .init(id:"SI",name:"Slovenia · Slovenian Railways",website:"https://potniski.sz.si/en/",api:nil),
        .init(id:"ES",name:"Spain · Renfe",website:"https://www.renfe.com/es/en",api:nil),
        .init(id:"SE",name:"Sweden · SJ",website:"https://www.sj.se/en",api:nil),
        .init(id:"TR",name:"Türkiye · TCDD Taşımacılık",website:"https://www.tcddtasimacilik.gov.tr/",api:nil),
        .init(id:"UA",name:"Ukraine · Ukrzaliznytsia",website:"https://booking.uz.gov.ua/en",api:nil),
        .init(id:"GB",name:"United Kingdom · National Rail",website:"https://www.nationalrail.co.uk/",api:nil),
        .init(id:"OTHER",name:"Other Europe / international · Eurail timetable",website:"https://www.eurail.com/en/plan-your-trip/eurail-timetable",api:nil)
    ]
    var provider: RailProvider { Self.providers.first { $0.id == country } ?? Self.providers[0] }
    var body: some View {
        Form {
            Picker("Country", selection: $country) { ForEach(Self.providers) { Text($0.name).tag($0.id) } }.onChange(of: country) { _, _ in result = nil; error = "" }
            Link("Official operator timetable", destination: URL(string: provider.website)!)
            if let api = provider.api {
                TextField("From station / DB EVA ID", text: $from)
                if api == "ch" { TextField("To station", text: $to); DateEntry(label: "Journey date", text: $date, optional: false); TextField("Earliest local departure, HH:mm", text: $time); Button("Find connections") { Task { await load("connections") } }.disabled(busy || from.isEmpty || to.isEmpty) }
                Button(busy ? "Loading…" : "Departures now") { Task { await load("departures") } }.disabled(busy || from.isEmpty)
                Text(api == "de" ? "Official DB station departures for the current and next hour, in Europe/Berlin. Requires DB Timetables credentials/subscription. No in-app German point-to-point planning." : "Swiss Transport API, Switzerland and some international connections. Times are local to the station. No provider key required.").font(.caption)
            } else { Text("Official website only. No in-app API is connected for this country.") }
            Text("Coverage is limited. No fares, rail-pass inventory or reservation confirmation. No results does not mean no trains run.").font(.caption)
            Text(error).foregroundStyle(.orange)
            if let result {
                if result.object.text("status") == "choose-station" {
                    Text(result.object.text("message"))
                    ForEach(Array(result.object.list("stations").enumerated()), id: \.offset) { _, station in Button(station.object.text("name")) { from = station.object.text("id"); Task { await load("departures") } } }
                } else { LiveResult(value: result) }
            }
        }.navigationTitle("Rail timetables")
    }
    @MainActor func load(_ mode: String) async {
        busy = true; result = nil; error = ""; let p = provider; defer { busy = false }
        do {
            guard let api = p.api else { return }
            let endpoint = TravelClient.current().endpoint
            let body: [String:JSONValue]? = api == "de" ? ["dbClientId":.string(TravelKeychain.read("dbClient:" + endpoint)),"dbApiKey":.string(TravelKeychain.read("dbKey:" + endpoint))] : nil
            let value = try await TravelClient.current().request("rail", query: ["provider":api,"mode":mode,"from":from,"to":to,"date":date,"time":time], body: body)
            if provider.id == p.id { result = value }
        } catch { self.error = error.localizedDescription }
    }
}
struct WebSearchScreen: View {
    @State private var query = ""
    @State private var result: JSONValue?
    @State private var error = ""
    @State private var busy = false
    var body: some View {
        Form {
            TextField("Public travel search", text: $query)
            Button(busy ? "Searching…" : "Search with Brave") { Task { busy = true; error = ""; result = nil; defer { busy = false }; do { let endpoint = TravelClient.current().endpoint; result = try await TravelClient.current().request("search", body: ["query":.string(query),"apiKey":.string(TravelKeychain.read("brave:" + endpoint))]) } catch { self.error = error.localizedDescription } } }.disabled(busy || query.count < 3)
            Text("Only your entered query is sent to the Eurotrip server and Brave. Search leads are unverified, not train schedules or confirmed prices. A provider key is required in the server or Keychain.").font(.caption)
            Text(error).foregroundStyle(.orange)
            if let result { LiveResult(value: result) }
        }.navigationTitle("Travel search")
    }
}
struct SafetyScreen: View {
    @State var latitude = ""
    @State var longitude = ""
    @State var country = ""
    @State var cc = ""
    @State private var result: JSONValue?
    @State private var error = ""
    @State private var busy = false
    var body: some View {
        Form {
            TextField("Latitude", text: $latitude).keyboardType(.numbersAndPunctuation); TextField("Longitude", text: $longitude).keyboardType(.numbersAndPunctuation)
            TextField("Country name", text: $country); TextField("Country code, e.g. AU or GB", text: $cc).textInputAutocapitalization(.characters)
            Button(busy ? "Loading…" : "Fetch official advice / figures") { Task { busy = true; error = ""; result = nil; defer { busy = false }; do { guard let lat = Decimal(string: latitude), let lon = Decimal(string: longitude), (-90...90).contains(NSDecimalNumber(decimal: lat).doubleValue), (-180...180).contains(NSDecimalNumber(decimal: lon).doubleValue) else { throw TripError.invalid("Enter a valid coordinate or use Explore → Nearby first.") }; result = try await TravelClient.current().request("safety", body: ["lat":.number(lat),"lon":.number(lon),"country":.string(country),"cc":.string(cc.lowercased())]) } catch { self.error = error.localizedDescription } } }.disabled(busy)
            Text("Country advice and published monthly counts, not live police incidents or a personal safety score. Local statistics are limited to supported South Australian/UK sources; provider dates and limitations are shown.").font(.caption)
            Text(error).foregroundStyle(.orange)
            if let result { LiveResult(value: result) }
        }.navigationTitle("Advice and statistics")
    }
}
