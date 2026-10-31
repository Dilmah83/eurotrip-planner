# Eurotrip Planner

Phone-first trip planner with a dependency-free Node backend. Trip records stay in your browser; live lookups run through your server.

## Run and test

Use Node 20 or newer (Node 18 remains supported). Run `npm ci`, `npm test`, then `npm start`. Open http://localhost:3000. Tests use synthetic trip records and mocked provider responses; they do not verify live providers or iPhone permission prompts.

On Render, use `node server.js` as the start command. Set `ACCESS_TOKEN` to protect live API calls, and `CONTACT_EMAIL` for OpenStreetMap requests. Keep API credentials in environment variables. Under **More → Connection and access code**, enter your access code and test it. Public `/api/health` checks uptime; `/api/status` checks access to protected APIs.

## National rail timetables and saved API connections

Home → **National rail timetables** now has a saved country/provider selector. Switzerland uses the existing Swiss Transport API without a key. Germany uses the official Deutsche Bahn Timetables API after you connect credentials. Other listed European countries open an official operator timetable website in a new tab; these are links, not working in-app APIs. The Other Europe/international option opens the Eurail timetable. No claim of complete European operator coverage is made.

For Germany, create an application at https://developers.deutschebahn.com/db-api-marketplace/apis/start and subscribe to **Timetables**. Under **More → API connections**, save both the DB Client ID and Client Secret/API key. From Home select Germany, enter an exact station name or 7-digit EVA ID and tap **Departures now**. Ambiguous names return station choices. The board covers the current and next hour in Europe/Berlin; live predictions, platform changes and cancellations are shown only when returned by DB. If changes fail, the board explicitly falls back to scheduled times. This API does not provide point-to-point journey planning; use the DB website link for that.

Swiss date/time connection searches and current departure boards remain available. International coverage varies; missing results or unpublished timetables do not mean no trains run. No fares, pass-seat inventory or reservation confirmation is supplied. Refresh is manual, not background polling. Responses are cached for one minute (boards) or five minutes (Swiss journeys). DB cache entries are scoped by a credential fingerprint, never raw keys.

**More → API connections → Save Brave key** remembers your Brave Web Search API key in this browser. **Travel web search · Brave** uses it for public-web travel searches (one provider request per click); snippets are unverified leads, not train schedules or prices. Provider charges and limits apply. The existing app access code remains separate and protects the backend APIs. New search requests use POST bodies, not key-bearing URLs; API responses and secrets are excluded from service-worker caches.

Device keys are in localStorage (not encrypted), so use a trusted device. They survive reopening the same browser until removed with the corresponding button or website data is cleared. They do not sync between devices or apps and are excluded from trip records, JSON backups and offline travel packs. Blocked storage displays an error instead of claiming success. Saved keys are not validated merely by saving: test a timetable or a search. If you used the hotel app, paste the same Brave key separately here.

For server-managed credentials, Render environment variables may instead provide `BRAVE_SEARCH_API_KEY`, `DB_CLIENT_ID`, and `DB_API_KEY`. Device keys override server defaults for those requests. A shared server Brave key requires `ACCESS_TOKEN` to prevent public use of a billed key. Never commit actual credentials. All upstream destinations are fixed in the backend; no arbitrary proxy is provided. Source docs: https://transport.opendata.ch/docs.html and https://developers.deutschebahn.com/db-api-marketplace/apis/product/timetables and https://api-dashboard.search.brave.com/api-reference/web/search/get.

Tests cover saved/reopened/removed keys, storage failure, exclusion from trip exports, country selection, authenticated endpoints, DB station disambiguation and midnight handling, predicted-versus-scheduled fields, provider failures, and Brave key handling/escaping. DB and Brave responses are mocked; a real credential and iPhone check is still needed for live-provider validation.

## Current update: travel essentials

Budget fields, payments screens, activity cost inputs and manual visa/ETIAS checklists have been removed from the interface. Existing financial data is preserved in full backups rather than deleted. The Money tab is now Rates: an independent converter and reference rate table, fetching all currencies without needing expenses. Rate dates show the latest published business day.

The nearby adapter fails over between two Overpass providers and distinguishes provider failure from an empty result. Crime and safety can refresh official SAPOL suburb polygon statistics (South Australia), UK local monthly crime counts, and Smartraveller country advice. Reporting dates and fetch times are displayed. These are published monthly figures and country advisories, not a real-time police incident feed. Any unavailable source is reported explicitly. The DFAT feed may be unavailable from some networks; the official source link remains available.

Sources: https://www.police.sa.gov.au/about-us/crime-statistics-map (ArcGIS map linked by SAPOL); https://www.smartraveller.gov.au/our-role/resources (public destinations-export API); https://data.police.uk/; https://frankfurter.dev/v1/.

## Earlier version 3 changes (some financial and entry-rule UI superseded above)

- Repaired empty `data-*` button dispatch, including location, search, adding destinations/costs/bookings, rates and backup actions.
- Home shows the current/next destination and today's bookings, accommodation and upcoming departure. Before or after travel it previews a trip date. Transfer days show both cities; forecast and restaurant links use the arriving city.
- Days has one-day, seven-day and whole-trip views, date navigation and Jump to today. Activity costs preserve their original currency.
- Edit existing destinations, activities, payments and bookings. Bookings include local departure/check-in and arrival/check-out dates and times, IANA time zones, addresses, references, cancellation deadlines and document links.
- Home and Money include activity estimates. Record an activity payment to replace its estimate without double counting. Rates are stored as currency pairs; changing home currency does not reuse an incompatible rate. Missing rates remain explicitly excluded from totals.
- Rail-pass use counts distinct train travel dates, not journey count. Journeys follow date order; pass payments cannot be added twice. Reservation status remains a manual record.
- Backup/restore validates trip data and includes attached files. Existing version 1 backups are accepted. An undo snapshot preserves the trip and attachments before import. Invalid saved data is preserved for recovery instead of silently overwritten.
- Attach PDF/image/text booking files (up to 10 MB each) for offline access. Files live in IndexedDB on this browser. Backup file import is capped at 50 MB. Deleted booking files are excluded from backups; Undo last deletion is available until the app is reloaded.
- Download a standalone offline HTML travel pack with itinerary, bookings, costs, packing and embedded attachments. It works without the app server. It is a private snapshot, not a syncing copy.
- The app shell is cached for offline opening. **More → Prepare app for offline use** confirms that every shell file was saved. Maps, searches, external document links, live forecasts and exchange-rate updates need internet. Map tiles are not bulk downloaded.
- Manual entry-rule verification dates, official links and an indicative rolling Schengen counter, including entered past stays. This is not an eligibility determination. Check official government rules for nationality, residence rights and complete travel history.
- Visible online/offline status, backup reminders, theme persistence and improved input labels/validation.

Existing trip storage uses the same `eurotrip.v1` key. Data migrates in place; existing activities inherit the previous home currency. Legacy exchange rates migrate to pairs using the saved home currency. Old data cannot reveal whether that home currency was previously changed incorrectly: recheck legacy rates against a reliable source.

## Live data and limits

Weather: Open-Meteo, approximately 16 days ahead. Exchange rates: Frankfurter reference rates, not bank/card rates. Nearby places: OpenStreetMap/Overpass and Nominatim; no ratings or verified pricing. Maps: Leaflet/OpenStreetMap. Official UK crime counts: data.police.uk, subject to coverage and delay. Directions open in Apple or Google Maps. Live providers can be unavailable or change policies; check the provider's own site before relying on results.

Flight endpoint: optional provider adapter requiring `FLIGHTS_API_KEY`; no flight-search UI and no verified provider integration is claimed. Hotel booking, other national rail APIs, bus timetables, menus, ratings, accounts, cloud sync and push notifications are not connected. Enter bookings manually and use official operator websites.

## Update and iPhone checks

After deployment, close and reopen Safari/the Home Screen app to activate an available service-worker update. Do not clear website data to update: that deletes your trip. Export a fresh backup first.

On a real iPhone, verify Add to Home Screen; allow/deny location; opening and saving attached files; app launch in airplane mode after offline preparation; downloading/restoring a backup; and opening the downloaded travel pack. iOS document handling and storage eviction depend on browser settings. Keep a backup outside the phone. Private browsing or full device storage may prevent persistent saves.

The repository includes the initial itinerary in `public/app.js`; anyone with repository or public site access can read the seeded itinerary. Access codes protect APIs, not static app files. Personal changes, passport expiry, payments and attachments are not uploaded to the backend or committed to the repository.

## Native iPhone / Xcode transition

Open `ios/Eurotrip.xcodeproj`. [Native setup, migration, privacy and feature coverage](ios/README.md) describes the SwiftUI app, existing-backup import, private itinerary-table import, offline files, Maps, Calendar and reuse of this Render backend. The website remains available; native records do not silently replace browser storage. Personal itinerary tables are not embedded in the public native source.
