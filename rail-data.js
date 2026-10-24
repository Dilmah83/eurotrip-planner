// Swiss Transport API: includes some international connections; coverage is not Europe-wide.
const SOURCE='https://transport.opendata.ch/';
const text=v=>typeof v==='string'?v.slice(0,160):'';
function stop(s={}){return {station:text(s.station?.name),scheduled:text(s.departure||s.arrival),predicted:text(s.prognosis?.departure||s.prognosis?.arrival),platform:text(s.prognosis?.platform||s.platform),delayMinutes:typeof s.delay==='number'?s.delay:null}}
function board(j){return {...stop(j.stop),line:[j.category,j.number].filter(Boolean).join(' '),destination:text(j.to),cancelled:typeof j.cancelled==='boolean'?j.cancelled:null}}
module.exports=({cached,getJSON})=>async q=>{const mode=q.get('mode')||'connections',from=(q.get('from')||'').trim(),to=(q.get('to')||'').trim(),date=q.get('date')||'';
 if(!from||from.length>120||!['connections','departures'].includes(mode))return [400,{error:'Enter a departure station and valid search mode.'}];
 if(mode==='connections'&&(!to||to.length>120||!/^\d{4}-\d\d-\d\d$/.test(date)||!Number.isFinite(Date.parse(date))||new Date(date+'T12:00:00Z').toISOString().slice(0,10)!==date))return [400,{error:'Enter an arrival station and valid date.'}];
 const params=mode==='departures'?new URLSearchParams({station:from,limit:'6',type:'departure','transportations[]':'train'}):new URLSearchParams({from,to,date,time:q.get('time')||'08:00',limit:'3','transportations[]':'train'});
 const time=q.get('time');if(time&&!/^([01]\d|2[0-3]):[0-5]\d$/.test(time))return [400,{error:'Use a valid local departure time.'}];
 const url='https://transport.opendata.ch/v1/'+(mode==='departures'?'stationboard':'connections')+'?'+params;
 const data=await cached('rail:'+url,mode==='departures'?60000:5*60000,()=>getJSON(url,{},1));
 if(data.errors?.length)throw Error('Rail provider rejected the station or date.');
 const result={mode,source:SOURCE,fetchedAt:new Date().toISOString(),coverage:'Swiss Transport API; international coverage varies. Missing results do not mean no trains run. Eurail pass validity, prices and reservation availability are not supplied.'};
 if(mode==='departures'){if(!Array.isArray(data.stationboard))throw Error('Incomplete rail response');result.station=text(data.station?.name);result.departures=data.stationboard.slice(0,6).map(board)}else{if(!Array.isArray(data.connections))throw Error('Incomplete rail response');result.connections=data.connections.slice(0,3).map(c=>({from:stop(c.from),to:stop(c.to),duration:text(c.duration),transfers:c.transfers,lines:(c.products||[]).filter(x=>typeof x==='string').slice(0,12),sections:(c.sections||[]).filter(s=>s.journey).map(s=>({from:stop(s.departure),to:stop(s.arrival),line:[s.journey.category,s.journey.number].filter(Boolean).join(' ')}))}))}return [200,result];
};
module.exports.stop=stop;module.exports.board=board;
