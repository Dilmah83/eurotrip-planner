import SwiftUI
import UIKit
import PhotosUI
import Vision
import ImageIO
import UniformTypeIdentifiers

// Vision processes only the explicitly selected image, locally. No network or AI provider.
enum BookingOCR {
    static func recognise(_ data: Data) async throws -> (String, Data) {
        try await Task.detached(priority: .userInitiated) {
            guard data.count <= 20 * 1024 * 1024, let source=CGImageSourceCreateWithData(data as CFData,nil),
                  let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:3000] as CFDictionary) else { throw TripError.invalid("Choose a readable screenshot or image under 20 MB.") }
            let request=VNRecognizeTextRequest();request.recognitionLevel = .accurate;request.usesLanguageCorrection=true
            try VNImageRequestHandler(cgImage:image).perform([request])
            let observations=(request.results ?? []).sorted { a,b in Int(a.boundingBox.midY*100) != Int(b.boundingBox.midY*100) ? a.boundingBox.midY>b.boundingBox.midY : a.boundingBox.minX<b.boundingBox.minX }
            let text=observations.compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n")
            guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw TripError.invalid("No text recognised. Crop to the booking details or use manual entry.") }
            let output=NSMutableData();guard let dest=CGImageDestinationCreateWithData(output,UTType.jpeg.identifier as CFString,1,nil) else{throw TripError.invalid("Could not prepare the screenshot.")}
            CGImageDestinationAddImage(dest,image,[kCGImageDestinationLossyCompressionQuality:0.9] as CFDictionary);guard CGImageDestinationFinalize(dest),output.length<=10*1024*1024 else{throw TripError.invalid("Screenshot attachment is too large.")}
            return (text, output as Data)
        }.value
    }
}
struct BookingScreenshotScreen: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var filePicker=false
    @State private var busy=false
    @State private var error=""
    @State private var record=TripRecord.new()
    @State private var warnings:[String]=[]
    @State private var imageData:Data?
    @State private var recognised=false
    @State private var keepImage=true
    var body: some View {
        Form {
            Section {
                PhotosPicker(selection:$photo,matching:.images) { Label("Choose booking screenshot",systemImage:"photo") }.disabled(busy)
                Button("Choose image from Files") { filePicker=true }.disabled(busy)
                Text("Take a screenshot of the hotel confirmation or a single flight leg, then select it here. Text is read on this iPhone. Nothing is uploaded. No access to other photos is needed.").font(.caption)
                if busy { ProgressView("Reading booking…") }
                Text(error).foregroundStyle(.red)
            }
            if recognised {
                Section("Review extracted details") {
                    if let imageData, let image=UIImage(data:imageData) { Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:180).accessibilityLabel("Selected booking screenshot") }
                    ForEach(warnings,id:\.self){Text($0).font(.caption).foregroundStyle(.orange)}
                    Picker("Booking type",selection:binding("kind")){Text("Hotel").tag("Accommodation");Text("Flight").tag("Flight")}
                    TextField("Hotel / flight name",text:binding("t"))
                    TextField("Confirmation reference",text:binding("ref")).autocorrectionDisabled()
                    DateEntry(label:"Departure / check-in",text:binding("date"))
                    TextField("Local time HH:mm",text:binding("time"))
                    DateEntry(label:"Arrival / check-out",text:binding("end"))
                    TextField("Local arrival / check-out time HH:mm",text:binding("endTime"))
                    TextField("Hotel address / airports",text:binding("address"),axis:.vertical)
                    DisclosureGroup("Time zones and recognised text") {
                        TextField("Departure zone, e.g. Europe/Paris",text:binding("tz")).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("Arrival zone",text:binding("arrivalTz")).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("Notes / recognised text",text:binding("note"),axis:.vertical)
                    }
                    Toggle("Keep screenshot offline with booking",isOn:$keepImage)
                    Button("Accept details and save booking") { save() }.disabled(busy || record["t"].trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    Button("Discard extracted details",role:.destructive) { recognised=false;imageData=nil;photo=nil }
                }
            }
        }.navigationTitle("Booking from screenshot")
        .onChange(of:photo){_,next in if let next { Task { await load(next) } } }
        .fileImporter(isPresented:$filePicker,allowedContentTypes:[.image]) { result in
            Task { do { let url=try result.get();let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=20*1024*1024 else{throw TripError.invalid("Image exceeds 20 MB.")};await read(try Data(contentsOf:url)) }catch{self.error=error.localizedDescription} }
        }
    }
    func binding(_ key:String)->Binding<String>{Binding(get:{record[key]},set:{record[key]=$0})}
    @MainActor func load(_ item:PhotosPickerItem) async {
        busy=true;defer{busy=false}
        do { guard let data=try await item.loadTransferable(type:Data.self) else{throw TripError.invalid("Photo unavailable. Download it from iCloud or choose an image from Files.")};await read(data) }catch{self.error=error.localizedDescription}
    }
    @MainActor func read(_ data:Data) async {
        busy=true;error="";recognised=false;imageData=nil;defer{busy=false}
        do { let(text,jpeg)=try await BookingOCR.recognise(data);let parsed=try BookingImport.parse(text);record=parsed.record;warnings=parsed.warnings;imageData=jpeg;recognised=true }catch{self.error=error.localizedDescription}
    }
    func save(){do{record["status"]="Screenshot details reviewed — verify with provider";try store.saveScreenshotBooking(record,jpeg:keepImage ? imageData:nil);dismiss()}catch{self.error=error.localizedDescription}}
}
