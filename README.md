# Eurotrip Planner

Phone-first trip planner with a dependency-free Node backend. Trip records stay in your browser; live lookups run through your server.

## Run and test

Use Node 20 or newer (Node 18 remains supported). Run `npm ci`, `npm test`, then `npm start`. Open http://localhost:3000. Tests use synthetic trip records and mocked provider responses; they do not verify live providers or iPhone permission prompts.

On Render, use `node server.js` as the start command. Set `ACCESS_TOKEN` to protect live API calls, and `CONTACT_EMAIL` for OpenStreetMap requests. Keep API credentials in environment variables. Under **More → Connection and access code**, enter your access code and test it. Public `/api/health` checks uptime; `/api/status` checks access to protected APIs.

## Home rail data

Home now shows the next train journey from the itinerary, editable departure/arrival stations, a date/time connection search, and a current departure board. Data is fetched on demand through `/api/rail`, protected by the existing access code. The Swiss Transport API supplies some international connections; coverage is not Europe-wide. No-results and provider failures do not establish that no trains run. Only supplied prognosis fields are labelled live; other times remain scheduled. Prices, Eurail pass-seat availability and reservation confirmation are not provided. Exact station names usually give better results. Departures are cached for one minute and connections for five minutes.

Source and API terms/documentation: https://transport.opendata.ch/docs.html. Eurail operator timetable link is provided separately; this is not a Eurail account integration.

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

Flight endpoint: optional provider adapter requiring `FLIGHTS_API_KEY`; no flight-search UI and no verified provider integration is claimed. Hotels, train/bus timetables, menus, ratings, accounts, cloud sync and push notifications are not connected. Enter bookings manually and use official operator websites.

## Update and iPhone checks

After deployment, close and reopen Safari/the Home Screen app to activate an available service-worker update. Do not clear website data to update: that deletes your trip. Export a fresh backup first.

On a real iPhone, verify Add to Home Screen; allow/deny location; opening and saving attached files; app launch in airplane mode after offline preparation; downloading/restoring a backup; and opening the downloaded travel pack. iOS document handling and storage eviction depend on browser settings. Keep a backup outside the phone. Private browsing or full device storage may prevent persistent saves.

The repository includes the initial itinerary in `public/app.js`; anyone with repository or public site access can read the seeded itinerary. Access codes protect APIs, not static app files. Personal changes, passport expiry, payments and attachments are not uploaded to the backend or committed to the repository.
