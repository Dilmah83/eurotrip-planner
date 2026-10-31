import XCTest
#if canImport(Eurotrip)
@testable import Eurotrip
#else
@testable import EurotripCore
#endif

final class CoreTests: XCTestCase {
    func record(_ fields: [String:String]) -> TripRecord { TripRecord(fields: fields.mapValues(JSONValue.string)) }
    func sample() -> TripArchive {
        var a = TripArchive.empty; var t = a.trip; var s = a.setup
        s["depart"] = .string("2050-01-01"); s["ret"] = .string("2050-01-10"); t["setup"] = .object(s)
        t["privateLegacy"] = .object(["retained": .bool(true), "values": .array([.number(123),.null])]); a.trip = t
        a.setRecords("dests", [record(["id":"a","city":"Example City","country":"Example country","from":"2050-01-01","to":"2050-01-05"]),record(["id":"b","city":"Other City","country":"Other country","from":"2050-01-05","to":"2050-01-10"])])
        a.setRecords("acts", [record(["id":"act","title":"Example activity","date":"2050-01-02","time":"10:00","zone":"Europe/Paris","cost":"20","cur":"EUR"])])
        a.setRecords("docs", [record(["id":"doc","t":"Example booking","kind":"Accommodation","date":"2050-01-02","end":"2050-01-04","ref":"TEST-ONLY","note":"Fixture"])]); return a
    }
    func testFullBackupRoundTripPreservesUnknownAndFinancialFields() throws {
        var a = sample(); var t = a.trip; t["exp"] = .array([.object(["id":.string("expense"),"desc":.string("Legacy"),"amt":.number(50),"cur":.string("EUR"),"status":.string("Paid")])]); a.trip = t
        a.files = [TripAttachment(id:"doc",name:"example.txt",data:"data:text/plain;base64,"+Data("offline fixture".utf8).base64EncodedString())]
        let b = try TripArchive.decode(a.encoded())
        XCTAssertEqual(a,b); XCTAssertEqual(b.files[0].bytes,Data("offline fixture".utf8)); XCTAssertEqual(b.trip["privateLegacy"],t["privateLegacy"]); XCTAssertEqual(b.trip.list("exp").count,1)
    }
    func testLegacyPlainTripAndVersionOneWrapper() throws {
        let a = sample(); let data = try JSONEncoder().encode(a.trip)
        XCTAssertEqual(try TripArchive.decode(data).trip,a.trip)
        var wrapped = a; wrapped.root["version"] = .number(1)
        XCTAssertEqual(try TripArchive.decode(wrapped.encoded()).trip,a.trip)
    }
    func testInvalidFutureBackupDoesNotSilentlyLoadEmptyTrip() throws {
        var a = sample(); a.root["version"] = .number(99)
        XCTAssertThrowsError(try TripArchive.decode(a.encoded()))
        XCTAssertThrowsError(try TripArchive.decode(Data("{}".utf8)))
    }
    func testAttachmentMustBelongToBookingAndRejectPathTraversal() {
        for file in [TripAttachment(id:"missing",name:"a.txt",data:"data:text/plain;base64,WA=="),TripAttachment(id:"doc",name:"../a.txt",data:"data:text/plain;base64,WA=="),TripAttachment(id:"doc",name:"a.html",data:"data:text/html;base64,WA=="),TripAttachment(id:"doc",name:"a.txt",data:"data:text/plain;base64,not base64")] {
            var a = sample(); a.files = [file]; XCTAssertThrowsError(try a.validate())
        }
    }
    func testDuplicateRecordsRejected() { var a = sample(); a.setRecords("acts",a.records("acts")+a.records("acts")); XCTAssertThrowsError(try a.validate()) }
    func testTransferDaysShowDepartureAndArrivalCities() { XCTAssertEqual(sample().destinations(on:"2050-01-05").map { $0["city"] },["Example City","Other City"]) }
    func testPreviewBeforeAndAfterTripClampsWithoutInventingCurrentDestination() { XCTAssertEqual(sample().previewDay(today:"2049-01-01"),"2050-01-01"); XCTAssertEqual(sample().previewDay(today:"2051-01-01"),"2050-01-10") }
    func testAllDatesAreInclusiveAndLeapDatesValidated() { XCTAssertEqual(TripDay.days("2028-02-28","2028-03-01").count,3); XCTAssertNil(TripDay.date("2027-02-29")); XCTAssertEqual(TripDay.shift("2028-03-01",by:-1),"2028-02-29") }
    func testDayBoundsRejectExcessiveOrReversedRanges() { XCTAssertTrue(TripDay.days("2050-01-02","2050-01-01").isEmpty); XCTAssertTrue(TripDay.days("2050-01-01","2053-01-01").isEmpty) }
    func testExplicitTimeZonesResolveInternationalDateLine() throws {
        let r = record(["id":"flight","t":"Fixture flight","kind":"Flight","date":"2050-12-02","time":"10:00","tz":"Asia/Tokyo","end":"2050-12-01","endTime":"23:00","arrivalTz":"Pacific/Honolulu"])
        XCTAssertNoThrow(try TripArchive.validate(r,type:"docs")); var a = sample(); a.setRecords("docs",[r]); let plan=TripEvents.plan(a); XCTAssertTrue(plan.events.last!.end > plan.events.last!.start); XCTAssertEqual(a.bookings(on:"2050-12-01").count,1)
    }
    func testCalendarSkipsMissingAndAmbiguousZones() {
        XCTAssertNil(TripDay.instant(day:"2050-01-01",time:"10:00",zone:""))
        XCTAssertNil(TripDay.instant(day:"2026-03-29",time:"02:30",zone:"Europe/Berlin"))
        XCTAssertNil(TripDay.instant(day:"2026-10-25",time:"02:30",zone:"Europe/Berlin"))
        var a = sample(); a.setRecords("acts",[record(["id":"x","title":"Unknown zone","date":"2050-01-01","time":"10:00"])]); a.setRecords("docs",[])
        XCTAssertTrue(TripEvents.plan(a).events.isEmpty); XCTAssertFalse(TripEvents.plan(a).skipped.isEmpty)
    }
    func testCalendarIdentifiersStayStableAfterTimeEdit() {
        var a = sample(); a.setRecords("docs",[]); let first=TripEvents.plan(a).events[0]
        var r=a.records("acts")[0];r["time"]="11:00";a.setRecords("acts",[r]);let second=TripEvents.plan(a).events[0]
        XCTAssertEqual(first.id,second.id);XCTAssertNotEqual(first.start,second.start)
    }
    func testOfflinePackEscapesContentAndIncludesAttachments() throws {
        var a=sample();var r=a.records("docs")[0];r["t"]="<script>alert(1)</script>";r["url"]="javascript:alert(1)";a.setRecords("docs",[r]);a.files=[TripAttachment(id:"doc",name:"a.txt",data:"data:text/plain;base64,WA==")]
        let html=String(data:try OfflinePack.html(a),encoding:.utf8)!
        XCTAssertFalse(html.contains("<script>"));XCTAssertTrue(html.contains("&lt;script&gt;"));XCTAssertFalse(html.contains("javascript:"));XCTAssertTrue(html.contains("data:text/plain;base64,WA=="))
    }
    func testUnsafeLinksRejected() { XCTAssertNil(TravelLinks.url("javascript:alert(1)"));XCTAssertNil(TravelLinks.url("https://user:secret@example.org"));XCTAssertNotNil(TravelLinks.maps("Example address")) }
    func testTableImportGroupsStopsAndPreservesOriginalNotes() throws {
        let text="| Date | Time | Location | Accommodation | travel time | things to do |\n| 1/3/50 | 10:00 | Paris, France | Example Hotel | estimated travel | example visit |\n| 2/3/50 | | Paris, France | Example Hotel | | |\n| 3/3/50 | | antwerp | | train estimate | |"
        let a=try ItineraryImport.parse(text)
        XCTAssertEqual(a.records("dests").count,2);XCTAssertEqual(a.records("dests")[0]["to"],"2050-03-02");XCTAssertEqual(a.records("docs")[0]["listedThrough"],"2050-03-02");XCTAssertTrue(a.records("docs")[0]["date"].isEmpty)
        XCTAssertEqual(a.trip.list("importedItineraryRows").count,3);XCTAssertEqual(a.records("acts").first?["zone"],"");XCTAssertEqual(a.records("acts").first?["suggestedZone"],"Europe/Paris")
    }
    func testTableImportTSVAndUnknownCityPreservesAmbiguity() throws {
        let a=try ItineraryImport.parse("1/3/50\t\tlreland\t\t\t")
        XCTAssertTrue(a.records("dests")[0]["city"].contains("confirm"));XCTAssertFalse(a.trip.list("importWarnings").isEmpty)
        XCTAssertEqual(ItineraryImport.place("colonge germany").city,"Cologne")
    }
    func testMergingUpdatedPlanKeepsConfirmedBookingAndFiles() throws {
        var existing=sample();existing.files=[TripAttachment(id:"doc",name:"a.txt",data:"data:text/plain;base64,WA==")]
        let plan=try ItineraryImport.parse("1/3/50 | | Other City, Country | | |")
        let merged=try ItineraryImport.keepingExisting(existing,updating:plan)
        XCTAssertEqual(merged.files,existing.files);XCTAssertEqual(merged.records("docs"),existing.records("docs"));XCTAssertEqual(merged.trip["privateLegacy"],existing.trip["privateLegacy"]);XCTAssertEqual(merged.records("acts"),existing.records("acts"))
    }
    func testListedAccommodationAppearsWithoutInventedCheckoutDate() throws { let a=try ItineraryImport.parse("1/3/50 | | Paris | Example Hotel | |\n2/3/50 | | Paris | Example Hotel | |");XCTAssertEqual(a.bookings(on:"2050-03-02").count,1);XCTAssertTrue(a.records("docs")[0]["end"].isEmpty) }
    func testInvalidTableDatesAndTimesFailHonestly() { XCTAssertThrowsError(try ItineraryImport.parse("30/2/50 | | Paris | | |"));XCTAssertThrowsError(try ItineraryImport.parse("1/3/50 | 25:99 | Paris | | |"));XCTAssertThrowsError(try ItineraryImport.parse("not an itinerary")) }
}
