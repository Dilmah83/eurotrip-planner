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

## Eurostar through Google Routes

Explore → Eurostar timetables (also linked from National rail) offers station pickers, date and earliest local departure time. Departure is converted using the selected station's IANA zone, including DST checks. Google results retain each transit operator, connecting trains and walking-segment counts. Stop times use Google's supplied IANA zones, with an explicit UTC/offset timestamp fallback. Only journeys containing an explicitly named Eurostar line/agency are shown. Google can omit Eurostar services: an empty result is not proof no trains run. Confirm all local boarding times, transfer allowances, station arrival/check-in requirements and reservations with Eurostar. This is a journey lookup, not a complete timetable or fare/seat inventory.

Deploy this branch's backend to the configured Render service. In Render set **GOOGLE_MAPS_API_KEY** to a server key with **Routes API** enabled and billing configured. Restrict that key to Routes API and to the server's outbound IPs where your hosting plan supports stable egress. Set appropriate quotas/billing alerts in Google Cloud. Do not put the key into Xcode, trip backups or a client query. Native clients send only station identifiers and a UTC departure timestamp via authenticated POST `/api/rail?provider=eurostar`; the server resolves a fixed station allowlist. No screenshots, passenger names or complete itinerary are included. Missing keys return a setup message and the Eurostar website remains usable. `/api/status` reports only whether Google is configured, never its key.

Google's current transit window is 7 days before to 100 days after request time, subject to supplied schedules. Results are transient (no backend caching, trip storage or export) and displayed separately with Google Maps attribution, without plotting them on Apple Maps. Deploy `/privacy.html` and `/terms.html` with the backend and review them for your deployment before distributing the app. Google's API terms, pricing, regional availability and provider coverage still apply. No live Google lookup was validated without a configured server credential.

References checked 1 November 2026:
- https://developers.google.com/maps/documentation/routes/transit-route
- https://developers.google.com/maps/documentation/routes/reference/rest/v2/TopLevel/computeRoutes
- https://developers.google.com/maps/documentation/routes/policies
- https://eurostarforagents.com/working-together/eurostar-api/ (separate partner distribution API; no partner credentials are bundled)

## Hotel and flight screenshot import

Bookings → Import hotel or flight screenshot → choose one screenshot from Photos or Files → review/edit details → Accept details and save booking. You take the screenshot using iOS's normal screenshot controls; the app cannot capture another app's screen. PhotosPicker only grants access to the image explicitly selected, without full-library permission. Apple Vision performs accurate text recognition locally, without an OpenAI/Google OCR API or credentials. Files up to 20 MB are downsampled to a maximum 3000-pixel side and converted to a metadata-free JPEG attachment (up to 10 MB). Keep the original confirmation separately; the compressed copy may omit tiny details.

Labelled hotel/flight name, reference, start/end dates and times, and address/airports are populated where recognised. Text layouts vary and recognition can be wrong. Numeric dates with ambiguous month/day order and dates without a year remain blank; no dates or time zones are invented. Unsupported/unlabelled information stays in recognised-text notes for review. Boarding times and PINs are not used as departure times or booking references. Import a single flight leg or hotel stay at a time; return and multi-leg itineraries need separate reviewed records. The user must explicitly accept before anything is saved; changing a field does not verify the booking with its provider.

The screenshot preview, extracted fields and optional attachment are on one review screen. One atomic save adds the record and optional image, preserving existing records/files, with Undo in More. Backups include retained screenshots and OCR text. No automatic calendar export or reminder changes occur on screenshot save; use Calendar export after confirming zones. Real booking layouts, iCloud photo availability and Photos/Files selection still need physical-device checks.
