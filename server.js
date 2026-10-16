// Eurotrip Planner backend. No dependencies. Needs Node 18 or newer.
const http=require('http'),fs=require('fs'),path=require('path');
const PORT=process.env.PORT||3000,TOKEN=process.env.ACCESS_TOKEN||'',PUB=path.join(__dirname,'public');
const MIME={'.html':'text/html; charset=utf-8','.js':'text/javascript','.png':'image/png','.webmanifest':'application/manifest+json','.json':'application/json'};
const cache=new Map(),hits=new Map();
async function cached(key,ttl,fn){const h=cache.get(key);if(h&&h.exp>Date.now())return h.v;const v=await fn();cache.set(key,{v,exp:Date.now()+ttl});return v}
async function getJSON(url,opt={},tries=3){for(let i=0;i<tries;i++){try{const r=await fetch(url,{...opt,signal:AbortSignal.timeout(10000)});
 if(r.status===429||r.status>=500)throw new Error('HTTP '+r.status);if(!r.ok){const e=new Error('HTTP '+r.status);e.fatal=true;throw e}return await r.json()}
 catch(e){if(e.fatal||i===tries-1)throw e;await new Promise(s=>setTimeout(s,400*2**i))}}}
const limited=ip=>{const n=Date.now(),a=(hits.get(ip)||[]).filter(t=>n-t<6e4);a.push(n);hits.set(ip,a);return a.length>60};
const DAY=864e5,num=v=>v==null?null:Math.round(v*10)/10;
async function weather(q){const city=(q.get('city')||'').trim(),date=q.get('date')||'';
 if(!city||!/^\d{4}-\d\d-\d\d$/.test(date))return[400,{error:'city and date (YYYY-MM-DD) are required'}];
 const days=Math.round((Date.parse(date)-Date.parse(new Date().toISOString().slice(0,10)))/DAY);
 if(days<0||days>15)return[200,{status:'out-of-range',message:'No reliable daily forecast yet. Forecasts cover about 16 days ahead. Check again closer to '+date+'.'}];
 const g=await cached('geo:'+city.toLowerCase(),30*DAY,async()=>{const j=await getJSON('https://geocoding-api.open-meteo.com/v1/search?count=1&name='+encodeURIComponent(city));return j.results&&j.results[0]||null});
 if(!g)return[200,{status:'no-place',message:'Place not found: '+city+'. Edit the destination name in the Trip tab.'}];
 const daily='temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_probability_max,snowfall_sum,wind_speed_10m_max,sunrise,sunset';
 const j=await cached('wx:'+g.latitude+','+g.longitude+':'+date,3*3600e3,()=>getJSON('https://api.open-meteo.com/v1/forecast?latitude='+g.latitude+'&longitude='+g.longitude+'&daily='+daily+'&timezone=auto&start_date='+date+'&end_date='+date));
 const d=j.daily;if(!d||!d.time||!d.time.length)return[502,{error:'Weather provider returned no data'}];
 return[200,{status:'forecast',label:'Provider forecast',place:g.name+', '+(g.country||''),tmax:num(d.temperature_2m_max[0]),tmin:num(d.temperature_2m_min[0]),feelsMax:num(d.apparent_temperature_max[0]),feelsMin:num(d.apparent_temperature_min[0]),rainProb:d.precipitation_probability_max[0],snow:num(d.snowfall_sum[0]),wind:num(d.wind_speed_10m_max[0]),sunrise:d.sunrise[0],sunset:d.sunset[0],source:'https://open-meteo.com/',fetchedAt:new Date().toISOString()}]}
async function fx(q){const f=(q.get('from')||'').toUpperCase(),t=(q.get('to')||'').toUpperCase();
 if(!/^[A-Z]{3}$/.test(f)||!/^[A-Z]{3}$/.test(t))return[400,{error:'from and to must be 3-letter currency codes'}];
 if(f===t)return[200,{rate:1,date:new Date().toISOString().slice(0,10),source:'same currency'}];
 const j=await cached('fx:'+f+t,6*3600e3,()=>getJSON('https://api.frankfurter.dev/v1/latest?base='+f+'&symbols='+t));
 if(!j.rates||!j.rates[t])return[502,{error:'No rate returned for '+f+' to '+t}];
 return[200,{rate:j.rates[t],date:j.date,source:'https://frankfurter.dev/',label:'Reference rate (not a bank or card rate)',fetchedAt:new Date().toISOString()}]}
async function flights(q){const key=process.env.FLIGHTS_API_KEY;
 if(!key)return[501,{error:'Flight search is not set up. Add FLIGHTS_API_KEY (see README).'}];
 const o=(q.get('from')||'').toUpperCase(),d=(q.get('to')||'').toUpperCase(),date=q.get('date')||'';
 if(!/^[A-Z]{3}$/.test(o)||!/^[A-Z]{3}$/.test(d)||!/^\d{4}-\d\d-\d\d$/.test(date))return[400,{error:'from, to (airport codes) and date (YYYY-MM-DD) are required'}];
 const url=process.env.FLIGHTS_API_URL||'https://ignav.com/api/fares/one-way';
 const j=await cached('fl:'+o+d+date,30*60e3,()=>getJSON(url,{method:'POST',headers:{'Content-Type':'application/json','X-Api-Key':key},body:JSON.stringify({origin:o,destination:d,departure_date:date})},2));
 return[200,{status:'provider-result',label:'Provider fare for this date. Confirm price and baggage at the booking link.',offers:j,fetchedAt:new Date().toISOString()}]}
const UA='EurotripPlanner/2.0 ('+(process.env.CONTACT_EMAIL||'no-contact-set')+')';
const pt=b=>{if(!b||b.lat==null||b.lon==null)return null;const la=+b.lat,lo=+b.lon;if(!(la>=-90&&la<=90&&lo>=-180&&lo<=180))return null;return{lat:Math.round(la*1e3)/1e3,lon:Math.round(lo*1e3)/1e3}};
const body=req=>new Promise(r=>{let d='';req.on('data',c=>{d+=c;if(d.length>2000){req.destroy();r({})}});req.on('end',()=>{try{r(JSON.parse(d||'{}'))}catch(e){r({})}})});
const ORD=['Mo','Tu','We','Th','Fr','Sa','Su'];
function openNow(s,off){if(!s)return null;if(s.trim()==='24/7')return true;
 const n=new Date(Date.now()+off*1000),di=(n.getUTCDay()+6)%7,mi=n.getUTCHours()*60+n.getUTCMinutes();let res=null;
 for(const rule of s.split(';')){const m=rule.trim().match(/^((?:[A-Z][a-z](?:-[A-Z][a-z])?)(?:,[A-Z][a-z](?:-[A-Z][a-z])?)*)?\s*((?:\d\d:\d\d-\d\d:\d\d)(?:,\d\d:\d\d-\d\d:\d\d)*|off|closed)$/);if(!m)return null;
  let hit=!m[1];if(m[1])for(const p of m[1].split(',')){const[a,b2]=p.split('-'),ia=ORD.indexOf(a),ib=b2?ORD.indexOf(b2):ia;if(ia<0||ib<0)return null;if(ia<=ib?(di>=ia&&di<=ib):(di>=ia||di<=ib))hit=true}
  if(hit)res=/^\d/.test(m[2])&&m[2].split(',').some(t=>{const[x,y]=t.split('-').map(z=>+z.slice(0,2)*60+ +z.slice(3));return x<y?(mi>=x&&mi<y):(mi>=x||mi<y)})}
 return res===null?false:res}
let lastNom=0;const nomWait=async()=>{const w=1100-(Date.now()-lastNom);if(w>0)await new Promise(r=>setTimeout(r,w));lastNom=Date.now()};
const FIL={attractions:'["tourism"~"^(attraction|viewpoint|artwork)$"]',historic:'["historic"]',museums:'["tourism"~"^(museum|gallery)$"]',parks:'["leisure"~"^(park|garden|nature_reserve)$"]',markets:'["amenity"="marketplace"]',food:'["amenity"~"^(restaurant|cafe|bar|pub)$"]',entertainment:'["amenity"~"^(nightclub|theatre|cinema)$"]',transport:'["railway"="station"]',health:'["amenity"~"^(pharmacy|hospital|police)$"]'};
const KIND=t=>t.tourism==='museum'||t.tourism==='gallery'?['Museums and galleries',true]:t.historic?['Historic sites',false]:t.tourism?['Attractions and viewpoints',false]:t.leisure?['Parks and gardens',false]:t.amenity==='marketplace'?['Markets',false]:['restaurant','cafe','bar','pub'].includes(t.amenity)?['Food and drink',true]:['nightclub','theatre','cinema'].includes(t.amenity)?['Entertainment and nightlife',true]:t.railway?['Transport stations',null]:['Health and emergency',true];
async function nearby(q,b){const p=pt(b);if(!p)return[400,{error:'lat and lon are required'}];
 const R=[500,1000,5000,10000,25000].includes(+b.radius)?+b.radius:1000,keys=FIL[b.cat]?[b.cat]:Object.keys(FIL);
 const ql='[out:json][timeout:20];('+keys.map(k=>'nwr'+FIL[k]+'["name"](around:'+R+','+p.lat+','+p.lon+');').join('')+');out center meta 150;';
 const j=await cached('nb:'+p.lat+','+p.lon+':'+R+':'+keys.join(),30*60e3,()=>getJSON('https://overpass-api.de/api/interpreter',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','User-Agent':UA},body:'data='+encodeURIComponent(ql)},2));
 let wx=null,off=0;try{const w=await cached('nw:'+p.lat+','+p.lon,3*3600e3,()=>getJSON('https://api.open-meteo.com/v1/forecast?latitude='+p.lat+'&longitude='+p.lon+'&daily=precipitation_probability_max,snowfall_sum,temperature_2m_max&timezone=auto&forecast_days=1'));off=w.utc_offset_seconds||0;wx={rainProb:w.daily.precipitation_probability_max[0],snow:w.daily.snowfall_sum[0],tmax:w.daily.temperature_2m_max[0],offset:off,source:'https://open-meteo.com/'}}catch(e){}
 const rad=x=>x*Math.PI/180,hav=(la,lo)=>{const a=Math.sin(rad(la-p.lat)/2)**2+Math.cos(rad(p.lat))*Math.cos(rad(la))*Math.sin(rad(lo-p.lon)/2)**2;return Math.round(12742000*Math.asin(Math.sqrt(a)))};
 const ok=u=>/^https?:\/\//i.test(u||'')?u:null,els=j.elements||[];
 const items=els.map(e=>{const t=e.tags||{},la=e.lat??(e.center&&e.center.lat),lo=e.lon??(e.center&&e.center.lon);if(la==null||lo==null)return null;const[kind,indoor]=KIND(t);
  return{id:e.type+'/'+e.id,name:t.name,kind,indoor,lat:la,lon:lo,dist:hav(la,lo),hours:t.opening_hours||null,openNow:openNow(t.opening_hours,off),fee:t.fee==='no'?'free':(t.fee==='yes'||t.charge)?'paid':null,website:ok(t.website||t['contact:website']),desc:t.description||null,edited:e.timestamp||null}}).filter(Boolean).filter(x=>x.dist<=R).sort((a,c)=>a.dist-c.dist);
 return[200,{items,weather:wx,capped:els.length>=150,source:'https://www.openstreetmap.org/copyright',fetchedAt:new Date().toISOString(),label:'Community-edited map data (OpenStreetMap). Hours, fees and websites may be out of date.'}]}
async function reverse(q,b){const p=pt(b);if(!p)return[400,{error:'lat and lon are required'}];
 const j=await cached('rv:'+p.lat+','+p.lon,DAY,async()=>{await nomWait();return getJSON('https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=14&accept-language=en&lat='+p.lat+'&lon='+p.lon,{headers:{'User-Agent':UA}})});
 const a=j.address||{},area=a.suburb||a.neighbourhood||a.quarter||a.city_district,city=a.city||a.town||a.village||a.municipality;
 return[200,{label:[area,city].filter(Boolean).join(', ')||j.display_name||'Unnamed area',country:a.country||'',cc:a.country_code||'',source:'https://www.openstreetmap.org/copyright',fetchedAt:new Date().toISOString()}]}
async function geocode(q){const s=(q.get('q')||'').trim();if(s.length<2||s.length>120)return[400,{error:'Enter a place name'}];
 const j=await cached('gc:'+s.toLowerCase(),7*DAY,async()=>{await nomWait();return getJSON('https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&accept-language=en&q='+encodeURIComponent(s),{headers:{'User-Agent':UA}})});
 return[200,{results:j.map(r=>({label:r.display_name,lat:+r.lat,lon:+r.lon})),source:'https://www.openstreetmap.org/copyright'}]}
async function crime(q,b){const p=pt(b);if(!p)return[400,{error:'lat and lon are required'}];
 try{const last=await cached('uk:last',6*3600e3,()=>getJSON('https://data.police.uk/api/crime-last-updated'));let[y,m]=String(last.date).slice(0,7).split('-').map(Number);const months=[];
  for(let i=0;i<3;i++){months.push(y+'-'+String(m).padStart(2,'0'));m--;if(m<1){m=12;y--}}
  const out=[];for(const mo of months){const arr=await cached('uk:'+p.lat+','+p.lon+':'+mo,12*3600e3,()=>getJSON('https://data.police.uk/api/crimes-street/all-crime?lat='+p.lat+'&lng='+p.lon+'&date='+mo));const by={};arr.forEach(c=>by[c.category]=(by[c.category]||0)+1);out.push({month:mo,total:arr.length,by})}
  return[200,{status:'ok',months:out,area:'about 1 mile around this point',measure:'Recorded incidents (counts, not rates per population)',published:last.date,source:'https://data.police.uk/',limits:'Covers England, Wales and Northern Ireland, not Scotland. Locations are approximate and counts depend on how incidents are recorded. This does not show which areas are safe. There is no comparison with the wider city here.'}]}
 catch(e){return[200,{status:'unavailable',message:'Official crime figures couldn\u2019t be loaded for this point. It may be outside coverage.',source:'https://data.police.uk/'}]}}
const notYet=name=>async()=>[501,{error:name+' search is not connected yet. Use the provider\'s own website and record the booking manually.'}];
const ROUTES={'/api/nearby':nearby,'/api/reverse':reverse,'/api/geocode':geocode,'/api/crime':crime,'/api/weather':weather,'/api/fx':fx,'/api/flights':flights,'/api/hotels':notYet('Accommodation'),'/api/transport':notYet('Train and bus'),'/api/restaurants':notYet('Restaurant and menu')};
const send=(res,code,body,type='application/json')=>{res.writeHead(code,{'Content-Type':type,'X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Cache-Control':type==='application/json'?'no-store':'no-cache'});res.end(typeof body==='string'||Buffer.isBuffer(body)?body:JSON.stringify(body))};
const server=http.createServer(async(req,res)=>{try{const u=new URL(req.url,'http://x');
 if(u.pathname==='/api/health')return send(res,200,{ok:true});
 if(u.pathname.startsWith('/api/')){
  if(limited(req.socket.remoteAddress||'?'))return send(res,429,{error:'Too many requests. Wait a minute.'});
  if(TOKEN&&req.headers['x-access-token']!==TOKEN)return send(res,401,{error:'Access code needed'});
  const h=ROUTES[u.pathname];if(!h)return send(res,404,{error:'Unknown endpoint'});
  try{const bd=req.method==='POST'?await body(req):{};const[c,o]=await h(u.searchParams,bd);return send(res,c,o)}catch(e){return send(res,502,{error:'The data provider is unavailable. Try again, or use the official website.'})}}
 let p=path.normalize(path.join(PUB,decodeURIComponent(u.pathname==='/'?'/index.html':u.pathname)));
 if(!p.startsWith(PUB+path.sep))return send(res,403,'Forbidden','text/plain');
 fs.readFile(p,(e,buf)=>e?send(res,404,'Not found','text/plain'):send(res,200,buf,MIME[path.extname(p)]||'application/octet-stream'))}
 catch(e){send(res,500,{error:'Server error'})}});
server.openNow=openNow;module.exports=server;if(require.main===module)server.listen(PORT,()=>console.log('Eurotrip Planner on port '+PORT));
