import SwiftUI

struct EurostarStation: Identifiable {
    let id:String
    let name:String
    let zone:String
}
struct EurostarScreen: View {
    static let stations:[EurostarStation] = [
        .init(id:"london",name:"London St Pancras International",zone:"Europe/London"),
        .init(id:"paris",name:"Paris Gare du Nord",zone:"Europe/Paris"),
        .init(id:"brussels",name:"Brussels Midi / Zuid",zone:"Europe/Brussels"),
        .init(id:"antwerp",name:"Antwerp Central",zone:"Europe/Brussels"),
        .init(id:"amsterdam",name:"Amsterdam Centraal",zone:"Europe/Amsterdam"),
        .init(id:"rotterdam",name:"Rotterdam Centraal",zone:"Europe/Amsterdam"),
        .init(id:"lille",name:"Lille Europe",zone:"Europe/Paris"),
        .init(id:"cologne",name:"Cologne Hauptbahnhof",zone:"Europe/Berlin")
    ]
    @State private var from="brussels"
    @State private var to="london"
    @State private var date=TripDay.string(Date())
    @State private var time="08:00"
    @State private var result:JSONValue?
    @State private var busy=false
    @State private var error=""
    var origin:EurostarStation{Self.stations.first{$0.id==from}!}
    var body: some View {
        Form {
            Section("Eurostar journey") {
                Picker("From",selection:$from){ForEach(Self.stations){Text($0.name).tag($0.id)}}
                Picker("To",selection:$to){ForEach(Self.stations){Text($0.name).tag($0.id)}}
                DateEntry(label:"Departure date",text:$date,optional:false)
                TextField("Earliest departure HH:mm",text:$time).keyboardType(.numbersAndPunctuation)
                Text("Enter local departure time in \(origin.zone). Results can include connecting trains; no direct service is assumed.").font(.caption)
                Button(busy ? "Finding journeys…":"Find Eurostar journeys"){Task{await search()}}.disabled(busy || from==to)
                Text(error).foregroundStyle(.orange)
            }
            if let result {
                Section("Google Maps") {
                    Text(result.object.text("coverage")).font(.caption)
                    if result.object.list("connections").isEmpty { Text("No Eurostar journey identified in the Google results. Check Eurostar directly.") }
                    ForEach(Array(result.object.list("connections").enumerated()),id:\.offset){index,connection in
                        VStack(alignment:.leading,spacing:8) {
                            Text("Journey \(index+1)").font(.headline)
                            Text("\(connection.object["walkingTransfers"]?.text ?? "0") walking segment(s). Review transfer time.").font(.caption)
                            ForEach(Array(connection.object.list("sections").enumerated()),id:\.offset){_,section in
                                VStack(alignment:.leading){
                                    Text(section.object.text("line"));Text(section.object.list("operators").compactMap{if case .string(let s)=$0{return s};return nil}.joined(separator:", ")).font(.caption)
                                    Text(stopText(section.object["from"]));Text("→ "+stopText(section.object["to"]))
                                    if section.object["eurostar"]?.bool != true {Text("Connecting operator").font(.caption)}
                                }
                            }
                        }.padding(.vertical,4)
                    }
                    Text("Checked: "+result.object.text("fetchedAt")).font(.caption)
                    Link("Google Maps",destination:URL(string:"https://maps.google.com/")!).font(.system(size:14,weight:.medium))
                }
            }
            Section("Confirm with the operator") {
                Link("Eurostar official timetable and booking",destination:URL(string:"https://www.eurostar.com/")!)
                Text("Google covers journeys from 7 days ago to 100 days ahead, subject to supplied schedules. This is not a complete timetable, ticket or reservation service. Confirm local times, station arrival requirements and seats with Eurostar.").font(.caption)
            }
            Section("Privacy and data") {
                Text("Only the selected stations and departure time are sent through your Eurotrip server to Google. Google results stay on this screen and are not stored in your trip or placed on Apple Maps. The server requires a Google Routes API key; you can use Eurostar's website without one.").font(.caption)
                Link("Eurotrip privacy",destination:URL(string:TravelClient.current().endpoint+"/privacy.html")!)
                Link("Eurotrip terms",destination:URL(string:TravelClient.current().endpoint+"/terms.html")!)
                Link("Google terms",destination:URL(string:"https://policies.google.com/terms")!)
                Link("Google privacy policy",destination:URL(string:"https://policies.google.com/privacy")!)
            }
        }.navigationTitle("Eurostar timetables")
        .onChange(of:from){_,_ in result=nil}.onChange(of:to){_,_ in result=nil}
        .onChange(of:date){_,_ in result=nil}.onChange(of:time){_,_ in result=nil}
    }
    func stopText(_ value:JSONValue?)->String {
        let obj=value?.object ?? [:]
        let zone=obj.text("zone")
        if let tz=TimeZone(identifier:zone),let instant=ISO8601DateFormatter().date(from:obj.text("scheduled")) {
            let f=DateFormatter();f.timeZone=tz;f.locale=Locale(identifier:"en_AU");f.dateFormat="d MMM yyyy HH:mm"
            return obj.text("station")+" · "+f.string(from:instant)+" ("+zone+")"
        }
        return obj.text("station")+" · "+obj.text("scheduled")+" (timestamp as supplied; Z means UTC)"
    }
    @MainActor func search() async {
        result=nil;error="";busy=true;defer{busy=false}
        let captured=[from,to,date,time]
        do{
            guard let instant=TripDay.instant(day:date,time:time,zone:origin.zone) else{throw TripError.invalid("Enter a valid date and 24-hour time. Ambiguous daylight-saving times must be checked with Eurostar.")}
            let value=try await TravelClient.current().request("rail",query:["provider":"eurostar"],body:["from":.string(from),"to":.string(to),"departureTime":.string(ISO8601DateFormatter().string(from:instant))])
            if captured == [from,to,date,time]{result=value}
        }catch{self.error=error.localizedDescription}
    }
}
