import XCTest
import UIKit
@testable import Eurotrip

final class NativeStoreTests: XCTestCase {
    @MainActor func testEditAndReloadPreserveUnknownFieldsAndRestoreUndo() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)}
        let store=TripStore(directory:dir)
        var r=TripRecord.new();r["t"]="Example booking";r["ref"]="KEEP";r.fields["legacyPrivateField"] = .string("Retained")
        try store.save(r,type:"docs");try store.attach(Data("offline".utf8),name:"a.txt",booking:r.id)
        var edit=r;edit["t"]="Edited booking";try store.save(edit,type:"docs")
        let reopened=TripStore(directory:dir);XCTAssertEqual(reopened.archive.records("docs")[0]["ref"],"KEEP");XCTAssertEqual(reopened.archive.records("docs")[0]["legacyPrivateField"],"Retained");XCTAssertEqual(reopened.archive.files[0].bytes,Data("offline".utf8))
        reopened.delete(r.id,type:"docs");XCTAssertTrue(reopened.archive.files.isEmpty);try reopened.undo();XCTAssertEqual(reopened.archive.files.count,1)
    }
    @MainActor func testInvalidImportLeavesCurrentTripUntouched() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)}
        let store=TripStore(directory:dir);let before=store.archive
        XCTAssertThrowsError(try store.importData(Data("{}".utf8)));XCTAssertEqual(store.archive,before)
    }
    @MainActor func testCorruptedStorageNeverSilentlyOverwritten() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)}
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);let raw=Data("corrupt fixture".utf8);try raw.write(to:dir.appendingPathComponent("trip.json"))
        let store=TripStore(directory:dir);XCTAssertNotNil(store.storageError);XCTAssertThrowsError(try store.commit(.empty));XCTAssertEqual(try Data(contentsOf:dir.appendingPathComponent("trip.json")),raw)
    }
}
final class TravelFixture: URLProtocol {
    static var response: ((URLRequest)throws->(Int,Data))?
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){do{let(status,data)=try Self.response!(request);client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)}catch{client?.urlProtocol(self,didFailWithError:error)}}
    override func stopLoading(){}
}
final class TravelClientTests: XCTestCase {
    func client()->TravelClient{let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[TravelFixture.self];return TravelClient(endpoint:"https://eurotrip.example.org",accessCode:"fixture-code",configuration:c)}
    override func tearDown(){TravelFixture.response=nil}
    func testAccessCodeInHeaderAndNeverInQuery() async throws {
        TravelFixture.response={request in XCTAssertEqual(request.value(forHTTPHeaderField:"X-Access-Token"),"fixture-code");XCTAssertFalse(request.url!.absoluteString.contains("fixture-code"));XCTAssertEqual(request.url?.path,"/api/status");return(200,Data(#"{"ok":true}"#.utf8))}
        let value = try await client().request("status")
        XCTAssertTrue(value.object["ok"]!.bool)
    }
    func test401AndRateLimitAreClearErrors() async {
        for status in [401,429]{TravelFixture.response={_ in(status,Data(#"{"error":"fixture"}"#.utf8))};do{_=try await client().request("status");XCTFail("Must not pretend success")}catch{XCTAssertTrue(error.localizedDescription.contains(status==401 ? "Access code" : "limit"))}}
    }
    func testUnsupportedAndInsecureEndpointRejectedBeforeNetworking() async {
        TravelFixture.response={_ in XCTFail("Must not call insecure endpoint");return(200,Data())}
        do{_=try await TravelClient(endpoint:"http://insecure.example.org").request("status");XCTFail("Must fail")}catch{}
        do{_=try await client().request("arbitrary-proxy");XCTFail("Must fail")}catch{}
    }
    func testProviderKeysUsePostBodyNotURL() async throws {
        TravelFixture.response={request in XCTAssertEqual(request.httpMethod,"POST");XCTAssertFalse(request.url!.absoluteString.contains("fixture-key"));return(200,Data(#"{"results":[],"coverage":"test only"}"#.utf8))}
        _=try await client().request("search",body:["query":.string("fictional travel query"),"apiKey":.string("fixture-key")])
    }
    func testOfflineFailureDoesNotReturnMockLiveData() async {
        TravelFixture.response={_ in throw URLError(.notConnectedToInternet)}
        do{_=try await client().request("rates");XCTFail("Must not fabricate data")}catch{}
    }
}

extension NativeStoreTests {
    @MainActor func testScreenshotSaveIsAtomicPreservesExistingTripAndCanUndo() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)}
        let store=TripStore(directory:dir);var old=TripRecord.new();old["t"]="Existing booking";try store.save(old,type:"docs")
        var scanned=try BookingImport.parse("Hotel: Example Hotel\nCheck-in: 2026-12-01").record
        let before=store.archive;scanned["date"]="invalid";XCTAssertThrowsError(try store.saveScreenshotBooking(scanned,jpeg:Data("fixture".utf8)));XCTAssertEqual(store.archive,before)
        scanned["date"]="2026-12-01";try store.saveScreenshotBooking(scanned,jpeg:Data("fixture".utf8));XCTAssertEqual(store.archive.records("docs").count,2);XCTAssertEqual(store.archive.files.count,1)
        let reopened=TripStore(directory:dir);XCTAssertEqual(reopened.archive,store.archive);try reopened.undo();XCTAssertEqual(reopened.archive,before)
    }
}

final class ScreenshotOCRTests:XCTestCase {
    func testInvalidImageFailsWithoutInventedBooking() async {
        do{_=try await BookingOCR.recognise(Data("not an image".utf8));XCTFail("Must reject invalid image")}catch{}
    }
    @MainActor func testGeneratedHotelScreenshotRecognisedOnDevice() async throws {
        let renderer=UIGraphicsImageRenderer(size:CGSize(width:1200,height:800))
        let image=renderer.image{context in UIColor.white.setFill();context.fill(CGRect(x:0,y:0,width:1200,height:800));let lines=["Hotel name: Example Hotel","Booking reference: ABC123","Check-in: 29 November 2026","Check-out: 1 December 2026"];for (index,line) in lines.enumerated(){(line as NSString).draw(at:CGPoint(x:40,y:40+index*100),withAttributes:[.font:UIFont.systemFont(ofSize:36),.foregroundColor:UIColor.black])}}
        let data=try XCTUnwrap(image.pngData());let(text,jpeg)=try await BookingOCR.recognise(data);let parsed=try BookingImport.parse(text)
        XCTAssertEqual(parsed.record["t"],"Example Hotel");XCTAssertEqual(parsed.record["date"],"2026-11-29");XCTAssertFalse(jpeg.isEmpty)
    }
}
