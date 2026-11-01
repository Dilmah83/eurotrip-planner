// Google Routes API transit adapter. Keys stay server-side; no caching of Google content.
const STATIONS = {
 london:'London St Pancras International, UK', paris:'Paris Gare du Nord, France',
 brussels:'Bruxelles-Midi, Belgium', antwerp:'Antwerpen-Centraal, Belgium',
 amsterdam:'Amsterdam Centraal, Netherlands', rotterdam:'Rotterdam Centraal, Netherlands',
 lille:'Lille Europe, France', cologne:'Köln Hauptbahnhof, Germany'
};
const clean=v=>typeof v==='string'?v.replace(/[\u0000-\u001f]/g,' ').slice(0,300):'';
const stop=(s,time,localized)=>({station:clean(s?.name),scheduled:clean(time),zone:clean(localized?.timeZone)});
module.exports=({fetcher=fetch,now=()=>Date.now(),key=()=>process.env.GOOGLE_MAPS_API_KEY}={})=>async(q,b={})=>{
 const from=b.from,to=b.to,departure=b.departureTime;
 if(!Object.hasOwn(STATIONS,from)||!Object.hasOwn(STATIONS,to)||from===to||typeof departure!=='string'||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.test(departure)||!Number.isFinite(Date.parse(departure))||new Date(departure).toISOString()!==departure.replace('Z','.000Z'))return[400,{error:'Select different supported stations and a valid UTC departure time.'}];
 const delta=Date.parse(departure)-now();
 if(delta < -7*864e5 || delta > 100*864e5)return[400,{error:'Google transit lookup supports 7 days back to 100 days ahead. Use the official Eurostar timetable for other dates.'}];
 if(!key())return[503,{error:'Eurostar lookup needs GOOGLE_MAPS_API_KEY on the Eurotrip server, with Routes API enabled and billing configured. Use the official Eurostar timetable meanwhile.'}];
 let response;
 try{response=await fetcher('https://routes.googleapis.com/directions/v2:computeRoutes',{method:'POST',redirect:'error',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json','X-Goog-Api-Key':key(),'X-Goog-FieldMask':'routes.duration,routes.legs.steps.transitDetails,routes.legs.steps.travelMode'},body:JSON.stringify({origin:{address:STATIONS[from]},destination:{address:STATIONS[to]},travelMode:'TRANSIT',departureTime:departure,computeAlternativeRoutes:true,transitPreferences:{allowedTravelModes:['TRAIN']},languageCode:'en'})});}catch{return[502,{error:'Google transit service is unavailable. Use Eurostar directly; no timetable has been substituted.'}];}
 if(!response.ok)return[response.status===429?429:502,{error:response.status===429?'Google transit request limit reached. Try again later.':'Google transit request failed. Check the server Routes API configuration or use Eurostar directly.'}];
 let data;try{data=await response.json()}catch{return[502,{error:'Invalid Google transit response.'}];}
 if(data.error || (data.routes!==undefined&&!Array.isArray(data.routes)))return[502,{error:'Incomplete Google transit response.'}];
 const connections=(data.routes||[]).slice(0,4).flatMap(route=>{
  const steps=(route.legs||[]).flatMap(l=>l.steps||[]);
  const sections=steps.filter(s=>s.transitDetails).map(s=>{const t=s.transitDetails,line=t.transitLine||{},operators=(line.agencies||[]).map(a=>clean(a.name));return{from:stop(t.stopDetails?.departureStop,t.stopDetails?.departureTime,t.localizedValues?.departureTime),to:stop(t.stopDetails?.arrivalStop,t.stopDetails?.arrivalTime,t.localizedValues?.arrivalTime),line:clean(line.name||line.nameShort),operators,eurostar:/\beurostar\b/i.test([line.name,line.nameShort,...operators].join(' '))};});
  if(!sections.some(s=>s.eurostar))return[];
  return[{duration:clean(route.duration),sections,walkingTransfers:steps.filter(s=>s.travelMode==='WALK').length,includesOtherOperators:sections.some(s=>!s.eurostar)}];
 });
 return[200,{status:connections.length?'connections':'not-identified',connections,attribution:'Google Maps',source:'https://maps.google.com/',official:'https://www.eurostar.com/',fetchedAt:new Date(now()).toISOString(),coverage:'Google transit journeys containing an identified Eurostar segment, not a complete Eurostar timetable. Connecting operators and walking transfers may be included. No results does not mean no Eurostar trains run. Confirm station, local times, check-in requirements and availability with Eurostar. No fares, seats or pass reservations supplied.'}];
};
module.exports.STATIONS=STATIONS;
