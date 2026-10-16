# Eurotrip Planner (with backend)

Phone-first trip planner plus a small Node server that fetches live data safely. Your trip itself is saved in your phone's browser. The server only looks up weather, exchange rates and (optionally) fares.

## What works now
- Weather forecast per day (Open-Meteo, no key). Only about 16 days ahead; beyond that the app says no forecast yet.
- Live reference exchange rates (Frankfurter, no key). These are not card or bank rates.
- Flight fares: set FLIGHTS_API_KEY (paid provider; see below). The server endpoint is `/api/flights`; there is no screen for it in the app yet.
- Everything from the first version: itinerary, budget, payments, packing, bookings, official entry links, ETIAS status.

## Not connected yet
Accommodation prices and availability, train and bus timetables, restaurant menus. These need paid or partner access (for example a hotel affiliate API, national rail APIs, Google Places). The server returns a clear "not connected" message instead of inventing results. Add bookings by hand in the meantime.

## Flights: provider note
Amadeus closed its Self-Service API on 17 July 2026, so it isn't used. The adapter targets Ignav (fare search and booking links, pay per search). It has not been called with a real key, so check its response before relying on it. Duffel is an alternative if you want to create orders yourself.

## Run it
1. Install Node 20 (nodejs.org). In this folder run `node --test test/server.test.js`, then `ACCESS_TOKEN=your-phrase node server.js`.
2. Open http://localhost:3000.

## Put it online (works from an iPhone)
1. Upload this folder to a **private** GitHub repository (your itinerary is in `public/index.html`).
2. On render.com choose New, then Web Service, and connect the repository. Leave the build command empty. Start command: `node server.js`.
3. Under Environment add `ACCESS_TOKEN` (your secret phrase), and `FLIGHTS_API_KEY` if you have one.
4. Open the address Render gives you in Safari, enter the access code once, then Share, then Add to Home Screen.
Free hosting sleeps when idle, so the first request can take about a minute.

## Testing checklist
- [ ] `node --test test/server.test.js` passes.
- [ ] Open the app on your iPhone, add it to the Home Screen, then open it in airplane mode: the itinerary still shows.
- [ ] Days tab: Forecast works for a date within 16 days and says "no forecast yet" for January.
- [ ] Money tab: add a EUR payment, tap Fetch live rates, check the converted total and the rate date.
- [ ] A wrong access code is rejected.
- [ ] Export backup, delete all data, confirm the app resets.

## Security
Passport details and payments stay in the browser. The server never receives them. API keys live only in server environment variables.

## Near me and local safety (added)
- **Near me tab:** tap "Use my current location" (asked only when you tap). Or search a place by name. Shows a map and places within 500 m to 25 km, with filters. Your location is sent to your own server in a POST request, rounded to about 100 m, and is not stored or put in a web address. It is cleared with "Clear location". Nothing tracks you in the background.
- **Data sources and costs:**
  | Need | Source | Key | Cost and limits |
  | Places | OpenStreetMap via Overpass | none | Free. Fair use only; results are cached 30 min. |
  | Place search and area name | Nominatim | none | Free, max 1 request a second (the server enforces it). Set CONTACT_EMAIL. |
  | Map tiles | tile.openstreetmap.org via Leaflet | none | Free for light personal use. For heavy use, switch to a paid tile provider such as MapTiler or Mapbox. |
  | Weather, open-now time | Open-Meteo | none | Free for non-commercial use. |
  | UK crime figures | data.police.uk | none | Free. England, Wales and Northern Ireland only. |
- **Why not Google or Mapbox:** they give ratings, reviews and live opening hours, but need billing accounts and keys. OpenStreetMap has no ratings, so the app shows none. Google Places could be added later on the server.
- **Not built:** push alerts, route safety or lit-street routing, public transport times, ratings, and crime data outside the UK. The app says so on screen instead of guessing. Directions open in Apple Maps or Google Maps.
- **Location needs HTTPS.** Render provides it. Test on a real iPhone: allow, deny, turn off Location Services, and move to a different place.
