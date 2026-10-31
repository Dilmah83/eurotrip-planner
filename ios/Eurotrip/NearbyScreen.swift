import SwiftUI
import MapKit
import CoreLocation

@MainActor final class TripLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var message = ""
    private let manager = CLLocationManager()
    private var requested = false
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    func locate() {
        requested = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: message = "Finding location…"; manager.requestLocation()
        default: message = "Location access is off. Search a city instead, or enable Eurotrip in iPhone Settings."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { if requested && [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) { manager.requestLocation() } }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { requested = false; coordinate = locations.last?.coordinate; message = "Location selected. Tap Find nearby to share the coordinate with your Eurotrip server." }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { message = "Location unavailable. Search a city instead." }
}
struct NearbyScreen: View {
    var initialPlace = ""
    @StateObject private var location = TripLocation()
    @State private var query = ""
    @State private var found: [JSONValue] = []
    @State private var selected: CLLocationCoordinate2D?
    @State private var label = ""
    @State private var country = ""
    @State private var cc = ""
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 50, longitude: 12), span: MKCoordinateSpan(latitudeDelta: 25, longitudeDelta: 25)))
    @State private var places: [JSONValue] = []
    @State private var response: JSONValue?
    @State private var category = "all"
    @State private var radius = 1000
    @State private var error = ""
    @State private var busy = false
    var body: some View {
        List {
            Section("Choose a location") {
                TextField("City or place", text: $query)
                HStack {
                    Button("Search place") { Task { await geocode() } }.disabled(busy || query.count < 2)
                    Button("Use my location") { location.locate() }
                }
                Text(location.message).font(.caption)
                ForEach(Array(found.enumerated()), id: \.offset) { _, result in
                    Button(result.object.text("label")) { if let coordinate = coordinate(result.object) { choose(coordinate, label: result.object.text("label")); found = [] } }
                }
            }
            if let selected {
                Map(position: $position) {
                    Marker(label.isEmpty ? "Selected location" : label, coordinate: selected)
                    ForEach(Array(places.enumerated()), id: \.offset) { _, place in if let point = coordinate(place.object) { Marker(place.object.text("name"), coordinate: point).tint(.orange) } }
                }.frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 14))
                Text(label).font(.caption)
                Picker("Places", selection: $category) { Text("All").tag("all"); Text("Food and drink").tag("food"); Text("Museums").tag("museums"); Text("Attractions").tag("attractions"); Text("Parks").tag("parks"); Text("Transport").tag("transport"); Text("Pharmacies / emergency").tag("health") }
                Picker("Radius", selection: $radius) { Text("500 m").tag(500); Text("1 km").tag(1000); Text("5 km").tag(5000); Text("10 km").tag(10000) }
                Button(busy ? "Loading…" : "Find nearby") { Task { await nearby(selected) } }.disabled(busy)
                NavigationLink("Official advice and statistics for this location") { SafetyScreen(latitude: String(selected.latitude), longitude: String(selected.longitude), country: country, cc: cc) }
                Text("This lookup sends the selected coordinate to your Eurotrip server and its place providers. Community opening hours and costs may be incomplete. Map tiles and directions require internet.").font(.caption)
            }
            Text(error).foregroundStyle(.orange)
            ForEach(Array(places.enumerated()), id: \.offset) { _, value in
                let p = value.object
                Section(p.text("name")) {
                    Text(p.text("kind")); Text("\(p.text("dist")) m straight-line distance")
                    Text(p.text("hours").isEmpty ? "Opening hours not supplied" : p.text("hours"))
                    if let open = p["openNow"], open != .null { Text(open.bool ? "Reported open now" : "Reported closed now") }
                    Text(p.text("fee") == "free" ? "Reported free entry" : "Price not confirmed")
                    if let point = coordinate(p), let url = TravelLinks.maps("\(point.latitude),\(point.longitude)") { Link("Walking directions", destination: url) }
                    if let url = TravelLinks.url(p.text("website")) { Link("Place website", destination: url) }
                }
            }
            if let response { DisclosureGroup("Coverage and source") { if let source = TravelLinks.url(response.object.text("source")) { Link("OpenStreetMap", destination: source) }; Text(response.object.text("fetchedAt")); Text("Places are community records, not verified prices, ratings or availability.") } }
        }.navigationTitle("Nearby and Maps").onAppear { if query.isEmpty { query = initialPlace } }
        .onChange(of: location.coordinate?.latitude) { _, _ in if let point = location.coordinate { choose(point, label: "My selected location") } }
    }
    func coordinate(_ p: [String:JSONValue]) -> CLLocationCoordinate2D? {
        guard let lat = p["lat"]?.decimal, let lon = p["lon"]?.decimal else { return nil }
        let a = NSDecimalNumber(decimal: lat).doubleValue, b = NSDecimalNumber(decimal: lon).doubleValue
        guard (-90...90).contains(a), (-180...180).contains(b) else { return nil }; return .init(latitude: a, longitude: b)
    }
    func choose(_ point: CLLocationCoordinate2D, label: String) { selected = point; self.label = label; places = []; response = nil; position = .region(MKCoordinateRegion(center: point, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))) }
    @MainActor func geocode() async { busy = true; error = ""; defer { busy = false }; do { found = try await TravelClient.current().request("geocode", query: ["q":query]).object.list("results"); if found.isEmpty { error = "No place found. Try city and country." } } catch { self.error = error.localizedDescription } }
    @MainActor func nearby(_ point: CLLocationCoordinate2D) async {
        busy = true; error = ""; places = []; response = nil; defer { busy = false }
        do {
            let lat = Decimal((point.latitude * 1000).rounded() / 1000), lon = Decimal((point.longitude * 1000).rounded() / 1000)
            let value = try await TravelClient.current().request("nearby", body: ["lat":.number(lat),"lon":.number(lon),"radius":.number(Decimal(radius)),"cat":.string(category)])
            guard selected?.latitude == point.latitude && selected?.longitude == point.longitude else { return }
            response = value; places = value.object.list("items"); if places.isEmpty { places = value.object.list("results") }
            if let area = try? await TravelClient.current().request("reverse", body: ["lat":.number(lat),"lon":.number(lon)]), selected?.latitude == point.latitude && selected?.longitude == point.longitude { country = area.object.text("country"); cc = area.object.text("cc") }
            if places.isEmpty { error = "No places returned in the selected area/category. This is not a guarantee none exist." }
        } catch { self.error = error.localizedDescription }
    }
}
