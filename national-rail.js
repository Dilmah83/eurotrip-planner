// Official Deutsche Bahn Timetables adapter. Credentials are never included in URLs or responses.
const {createHash}=require('crypto');
const BASE='https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1';
const decode=s=>String(s||'').replace(/&quot;/g,'"').replace(/&apos;/g,"'").replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
function attrs(s){const out={};for(const m of s.matchAll(/([\w:-]+)\s*=\s*(["'])(.*?)\2/g))out[m[1]]=decode(m[3]);return out}
function stations(xml){return [...xml.matchAll(/<station\b([^>]*?)\/?\s*>/g)].map(m=>attrs(m[1])).filter(s=>/^\d{7}$/.test(s.eva||'')).map(s=>({id:s.eva,name:s.name||s.eva})).slice(0,20)}
function stops(xml){return [...xml.matchAll(/<s\b([^>]*)>([\s\S]*?)<\/s>/g)].map(m=>{const dp=m[2].match(/<dp\b([^>]*?)\/?\s*>/),tl=m[2].match(/<tl\b([^>]*?)\/?\s*>/);return {id:attrs(m[1]).id,dp:dp?attrs(dp[1]):null,tl:tl?attrs(tl[1]):{}}}).filter(s=>s.id&&s.dp)}
function dbTime(s){return /^\d{10}$/.test(s||'')?'20'+s.slice(0,2)+'-'+s.slice(2,4)+'-'+s.slice(4,6)+'T'+s.slice(6,8)+':'+s.slice(8,10):''}
function berlinParts(date){return Object.fromEntries(new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Berlin',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(date).filter(p=>p.type!=='literal').map(p=>[p.type,p.value]))}
async function getXML(url,options){const r=await fetch(url,{...options,signal:AbortSignal.timeout(10000)});if(!r.ok){const e=Error('HTTP '+r.status);e.status=r.status;throw e}if(+(r.headers.get('content-length')||0)>2000000)throw Error('Rail response too large');const xml=await r.text();if(xml.length>2000000||/<!DOCTYPE|<!ENTITY/i.test(xml)||!/<(?:timetable|stations)\b/.test(xml))throw Error('Invalid rail response');return xml}
module.exports=({cached,getText=getXML,now=()=>new Date()})=>async(q,b={})=>{
 const mode=q.get('mode')||'departures';if(mode!=='departures')return [400,{error:'Germany’s Timetables API provides station departures. Use DB’s official journey planner for point-to-point routes.'}];
 const from=(q.get('from')||'').trim();if(!from||from.length>120)return [400,{error:'Enter a German station name or 7-digit EVA station ID.'}];
 const client=b.dbClientId||process.env.DB_CLIENT_ID||'',key=b.dbApiKey||process.env.DB_API_KEY||'';
 if(!/^[\x21-\x7E]{1,200}$/.test(client)||!/^[\x21-\x7E]{1,500}$/.test(key))return [428,{error:'Connect Deutsche Bahn first: More → API connections → save your DB Client ID and API key.'}];
 const auth=createHash('sha256').update(client+'\0'+key).digest('hex').slice(0,32),options={headers:{'DB-Client-Id':client,'DB-Api-Key':key,Accept:'application/xml'}};
 const xml=(url,ttl)=>cached('db:'+auth+':'+url,ttl,()=>getText(url,options));
 try{
  let station={id:from,name:from};if(!/^\d{7}$/.test(from)){
   const all=stations(await xml(BASE+'/station/'+encodeURIComponent(from),86400000));
   const exact=all.filter(s=>s.name.toLowerCase()===from.toLowerCase());
   if(!all.length)return [200,{status:'choose-station',stations:[],message:'No station matched. Try the exact station name or its EVA station ID.',source:'https://www.bahn.de/'}];
   if(exact.length===1)station=exact[0];else if(all.length===1)station=all[0];else return [200,{status:'choose-station',stations:all,message:'Choose the station you mean, then load its departures.',source:'https://www.bahn.de/'}];
  }
  const date=now(),parts=berlinParts(date),cutoff=`${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`;
  const hours=[date,new Date(date.getTime()+3600000)].map(d=>{const p=berlinParts(d);return p.year.slice(2)+p.month+p.day+'/'+p.hour});
  const plans=[];for(const hour of new Set(hours))plans.push(await xml(BASE+'/plan/'+station.id+'/'+hour,60000));
  const root=plans[0].match(/<timetable\b([^>]*)>/);if(root)station.name=attrs(root[1]).station||station.name;
  let changes=[],changesAvailable=true;try{changes=stops(await xml(BASE+'/fchg/'+station.id,60000))}catch{changesAvailable=false}
  const changed=new Map(changes.map(s=>[s.id,s]));
  const merged=new Map();for(const s of plans.flatMap(stops)){const live=changed.get(s.id);merged.set(s.id,{...s,dp:{...s.dp,...(live?.dp||{})}})}
  const departures=[...merged.values()].map(s=>{const d=s.dp,scheduled=dbTime(d.pt),predicted=dbTime(d.ct);return {station:station.name,scheduled,predicted,platform:d.cp||d.pp||'',delayMinutes:null,line:[s.tl.c,s.tl.n].filter(Boolean).join(' '),destination:(d.cpth||d.ppth||'').split('|').filter(Boolean).at(-1)||'Not supplied',cancelled:d.cs==='c'?true:null}}).filter(s=>(s.predicted||s.scheduled)>=cutoff).sort((a,b)=>(a.predicted||a.scheduled).localeCompare(b.predicted||b.scheduled)).slice(0,10);
  return [200,{mode:'departures',station:station.name,departures,source:'https://developers.deutschebahn.com/db-api-marketplace/apis/product/timetables',fetchedAt:now().toISOString(),coverage:'Official DB station timetable for the current and next hour. Times are local to Germany (Europe/Berlin). '+(changesAvailable?'Live predictions are shown only when supplied by DB.':'Live changes unavailable; scheduled departures only. Check cancellations with DB.')+' No fares, pass availability or route planning. An empty board does not mean no trains run.'}];
 }catch(e){return [[401,403].includes(e.status)?403:e.status===429?429:502,{error:[401,403].includes(e.status)?'DB rejected the credentials or Timetables subscription. Check both keys and activate the Timetables product.':e.status===429?'DB’s request limit was reached. Wait before refreshing.':'Deutsche Bahn timetable data is unavailable. Use the official operator link or try later.'}]}
};
module.exports.stations=stations;module.exports.stops=stops;module.exports.dbTime=dbTime;
