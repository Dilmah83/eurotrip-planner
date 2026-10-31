// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "EurotripCore", products: [.library(name: "EurotripCore", targets: ["EurotripCore"])], targets: [
    .target(name: "EurotripCore", path: "Eurotrip", exclude: ["EurotripApp.swift", "TripStore.swift", "TravelClient.swift", "BookingsAndSettings.swift", "CalendarScreen.swift", "LiveScreens.swift", "NearbyScreen.swift", "TableImportScreen.swift", "Assets.xcassets"], sources: ["TripCore.swift", "TripEvents.swift", "ItineraryImport.swift", "OfflinePack.swift"]),
    .testTarget(name: "EurotripCoreTests", dependencies: ["EurotripCore"], path: "EurotripTests", exclude: ["NativeTests.swift"], sources: ["CoreTests.swift"])
])
