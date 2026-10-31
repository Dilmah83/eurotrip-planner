# Eurotrip — native iPhone app

Open `Eurotrip.xcodeproj` in Xcode 16 or newer. Choose the Eurotrip scheme and an iPhone simulator, then Run. For a physical phone select your own signing team and bundle identifier. Minimum iOS 17. There are no third-party iOS dependencies. `python3 generate_project.py` regenerates the committed project after adding Swift files.

## Native screens

This is a SwiftUI application, not a website wrapper. Today, itinerary/destination/activity editing, bookings, packing and offline document access use native controls. Nearby uses MapKit and explicit Core Location permission. Calendar uses EventKit; optional local notification scheduling is explicit. The existing Render backend remains the live-data gateway.

- **Today:** current/next trip-day preview, transfer cities, activities and listed/dated accommodation.
- **Itinerary:** route, daily/all activities, editable dates, time zones and travel notes, gap checks and table-import issues.
- **Bookings:** references, addresses, departure/arrival zones, cancellation deadlines, editable notes and offline PDF/JPEG/PNG/WebP/text files (one per booking, up to 10 MB).
- **Explore:** Maps/nearby, forecasts, reference exchange rates, official safety/advice feeds, national rail and Brave search. Provider errors remain visible; no mock live data is substituted.
- **More:** packing, trip setup, rail-pass records, Calendar export, optional private alerts, backup/restore/Undo, standalone offline HTML pack and Keychain connection settings.

## Bring your existing trip across

1. Open the existing website in the browser where your trip is stored.
2. More → Export full backup. Save the JSON in Files and keep a separate copy.
3. Native app → More → Import Eurotrip JSON backup.

Version 3 full backups, earlier supported wrappers and plain trip JSON are read. Records, attachments, financial legacy data and unknown fields are preserved; edits update only the fields edited. Invalid data is rejected without replacing the current trip. Imports/deletions retain a recovery snapshot for Undo. Native full JSON exports remain compatible with the web backup structure. Individual device keys were intentionally excluded from browser backups: re-enter the access code/provider keys if needed.

Safari localStorage and IndexedDB cannot be read directly by a separate native app. Imports are explicit and local. Nothing clears or replaces the website's stored trip. There is no account or automatic cross-device sync.

## Your itinerary table

Itinerary or More → Import itinerary table → Paste → Preview → Import. Markdown and tab-separated Date | Time | Location | Accommodation | Travel time | Things to do rows are supported. Input is processed on the device; it is not sent to a server or committed to the source repository. Consecutive destination rows are grouped while all original row information is retained in the backup. Recognised spelling variants are normalised; unknown cities remain explicit. Travel-time notes remain estimates, not verified schedules. Named hotels remain unconfirmed accommodation records until booking details are supplied.

The default update keeps existing bookings, attachments, financial legacy data and activities. A recovery copy is kept before applying the new route. Review overlapping old activities if dates changed. Time zones suggested from a city are not applied automatically: confirm them in the activity editor before Calendar export. No missing flights, booking references, checkout times or Ireland cities are invented. Ambiguous notes and geographically inconsistent attraction dates are shown for review. A table's final day is the last planned date, not proof of a return-flight booking.

Personal hotel/wedding/travel data belongs in your private import/backup, not in this public repository. The native app starts empty; it does not redistribute the website's seeded personal route.

## Existing Render connection

Default server: `https://eurotrip-planner.onrender.com`. More → Connection → save the existing server access code and test. Codes and optional Brave/DB keys use Keychain (`WhenUnlockedThisDeviceOnly`), not UserDefaults or trip backups. Changing server URL does not forward another host's saved code. Requests require HTTPS, use a fixed API-path allowlist, refuse redirects, and keep access codes in headers/provider keys in POST bodies. No complete trip, passport details or attachment is posted for live lookups.

Swiss rail has an in-app API; Germany uses the existing DB adapter with an active Timetables subscription. Other countries retain the website's official operator links and are explicitly labelled website-only. Missing timetable results are not proof no trains run. Fares, rail-pass inventory and confirmed reservations are not provided. Store operator credentials on the server if preferred. Native device keys can override those defaults for the relevant request.

Maps/nearby and safety need a selected coordinate; GPS is requested only by explicit action, and nearby lookup shares a rounded coordinate when requested. Results are community place records or published crime counts/advisories, not verified opening hours/prices, ratings, live incidents or personal risk scores. Weather has the existing roughly 16-day provider horizon; rates are published reference values, not card rates.

## Calendar, files and offline behaviour

Date-only trip values use ISO civil dates without device-zone conversion. Booking times keep independent IANA departure/arrival zones. Calendar export skips missing/invalid zones and daylight-saving ambiguous/nonexistent times rather than guessing. Export updates this native app's marked events in the default calendar; it does not rewrite unrelated events. Re-export after edits and review Calendar. Optional alerts are one-shot, private and limited to the next available 64 events; re-schedule after edits or to extend that horizon. Delivery depends on iOS permission and Focus settings.

Plans, packing and saved documents work offline immediately. Native trip/recovery files and materialised document previews use complete file protection. The OS picker grants access to selected files only. Exported JSON and standalone HTML packs contain private itinerary/booking/file data; share only with intended recipients. User device/iCloud backups follow iOS settings. Internet is required for maps, external links and live APIs. There is no in-app hotel/flight purchase engine, general European rail API, push service or cloud trip sync.

## Validation

`swift test --package-path ios` runs portable production-model, migration, date/time-zone, attachment, offline-export and table-import tests. `xcodebuild -project ios/Eurotrip.xcodeproj -scheme Eurotrip -destination 'platform=iOS Simulator,name=<installed iPhone>' CODE_SIGNING_ALLOWED=NO test` additionally tests native persistence/recovery and mocked API requests. GitHub Actions chooses an installed simulator automatically. Existing Node/web tests remain in the original workflow.

Swift/Xcode are unavailable in the Linux editing environment, so macOS CI is the native build gate. Mock API tests validate client handling, not live provider accuracy or credential subscriptions. Physical iPhone checks remain required: location allow/deny, Calendar allow/deny, notification delivery/Focus, Quick Look/files, sharing/restoring full backups, airplane-mode plans/files and the actual revised itinerary after import.
