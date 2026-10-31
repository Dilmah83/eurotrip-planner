const KEY='eurotrip.v1';
const SCHENGEN=['austria','belgium','bulgaria','croatia','czechia','czech republic','denmark','estonia','finland','france','germany','greece','hungary','iceland','italy','latvia','liechtenstein','lithuania','luxembourg','malta','netherlands','norway','poland','portugal','romania','slovakia','slovenia','spain','sweden','switzerland'];
const CATS=['International flights','Accommodation','Local transport','Intercity transport','Food and restaurants','Activities and attractions','Visas and authorisations','Travel insurance','Shopping','Mobile data','Emergency reserve','Miscellaneous'];
const PACK=['Passport','Travel insurance documents','Phone charger and EU plug adaptor','Thermal base layers','Warm waterproof coat','Gloves, scarf and hat','Waterproof walking shoes','Medications and prescriptions','Payment cards and some cash','Offline maps downloaded'];
const blank=()=>({setup:{home:'Adelaide, Australia',depart:'',ret:'',nat:'Australian',pexp:'',trav:1,budget:0,cur:'AUD',pace:'Balanced',diet:''},dests:[],acts:[],exp:[],pack:PACK.map(t=>({t,done:false})),docs:[],rates:{AUD:{r:1,at:''}},etias:{status:'Application not yet available',checked:'2026-10-17'},rail:{kind:'Flexi',days:15,price:'',cur:'EUR'},legs:{}});
let S=load();let tab='home';let editing=null;
function load(){let s=blank();try{const v=localStorage.getItem(KEY);if(v)s=Object.assign(s,JSON.parse(v))}catch(e){}
 if(!s.setup||!Array.isArray(s.dests)||!Array.isArray(s.acts))return {...blank(),seeded:1};
 if(!s.seeded&&!s.dests.length&&!s.acts.length&&!s.setup.depart){const id=()=>Math.random().toString(36).slice(2,9);
  Object.assign(s.setup,{depart:'2026-11-27',ret:'2027-01-20'});
  s.dests=[['Singapore','Singapore','2026-11-27','2026-11-29'],['Paris','France','2026-11-29','2026-11-30'],['Antwerp','Belgium','2026-12-01','2026-12-01'],['Amsterdam','Netherlands','2026-12-02','2026-12-04'],['Copenhagen','Denmark','2026-12-05','2026-12-06'],['Stockholm','Sweden','2026-12-07','2026-12-09'],['Helsinki','Finland','2026-12-10','2026-12-12'],['Tallinn','Estonia','2026-12-13','2026-12-13'],['Riga','Latvia','2026-12-14','2026-12-17'],['Warsaw','Poland','2026-12-18','2026-12-19'],['Gdansk','Poland','2026-12-20','2026-12-21'],['Prague','Czechia','2026-12-22','2026-12-23'],['Antwerp','Belgium','2026-12-24','2026-12-26'],['Berlin','Germany','2026-12-27','2026-12-30'],['London','United Kingdom','2026-12-31','2027-01-04'],['Edinburgh','United Kingdom','2027-01-05','2027-01-07'],['Ireland (city to confirm)','Ireland','2027-01-08','2027-01-14'],['Belfast','United Kingdom','2027-01-15','2027-01-15'],['Ireland (city to confirm)','Ireland','2027-01-16','2027-01-20']].map(([city,country,from,to])=>({id:id(),city,country,from,to}));
  s.acts=[['2026-11-27','10:05','Fly out of Adelaide'],['2026-11-27','14:40','Arrive in Singapore'],['2026-11-28','','Singapore: eat!'],['2026-11-29','11:00','Fly out of Singapore'],['2026-11-29','18:00','Arrive in Paris']].map(([date,time,title])=>({id:id(),date,time,title,cost:''}))}
 s.seeded=1;return s}
function save(){try{localStorage.setItem(KEY,JSON.stringify(S))}catch(e){toast('Could not save on this device. Export your data to keep it.')}}
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const D=s=>new Date(s+'T00:00:00');const iso=d=>{const z=new Date(d.getTime()-d.getTimezoneOffset()*6e4);return z.toISOString().slice(0,10)};
const today=()=>iso(new Date());const diff=(a,b)=>Math.round((D(b)-D(a))/864e5);
const fmtD=s=>s?D(s).toLocaleDateString('en-AU',{weekday:'short',day:'numeric',month:'short',year:'numeric'}):'not set';
const uid=()=>Math.random().toString(36).slice(2,9);
const cur=()=>S.setup.cur||'AUD';
function toHome(e){if(e.cur===cur())return e.amt;const r=S.rates[e.cur+'>'+cur()];return r?e.amt*r.r:null}
const money=n=>n==null?'rate needed':new Intl.NumberFormat('en-AU',{style:'currency',currency:cur()}).format(n);
function toast(m){const t=document.createElement('div');t.setAttribute('role','status');t.className='note t-warn';t.style.cssText='position:fixed;left:14px;right:14px;top:calc(12px + env(safe-area-inset-top,0px));z-index:9;margin:0';t.textContent=m;document.body.appendChild(t);setTimeout(()=>t.remove(),3500)}
function days(){const a=S.setup.depart,b=S.setup.ret;if(!a||!b||b<a)return[];const out=[];for(let d=D(a);iso(d)<=b;d.setDate(d.getDate()+1))out.push(iso(d));return out}
const destOn=ds=>destinationsOn(ds).at(-1);
const isSch=c=>SCHENGEN.includes(String(c).trim().toLowerCase());
function totals(){let est=0,paid=0,out=0,miss=0;const byCat={};allExpenses().forEach(e=>{const v=toHome(e);if(v==null){miss++;return}est+=v;byCat[e.cat]=(byCat[e.cat]||0)+v;if(e.status==='Paid')paid+=v;else out+=v});return{est,paid,out,miss,byCat}}
function warnings(){const w=[],s=S.setup;if(!s.depart||!s.ret)w.push(['t-warn','Add your departure and return dates in the Trip tab.']);
 if(s.pexp&&s.ret){const m=diff(s.ret,s.pexp);if(m<0)w.push(['t-bad','Your passport expires before your return date.']);else if(m<183)w.push(['t-warn','Your passport has less than about 6 months left after your return. Many countries require 3 to 6 months. Check each official entry page.'])}
 else w.push(['t-warn','Add your passport expiry date in the Trip tab.']);
 if(S.dests.some(d=>isSch(d.country))){const e=S.etias||{},age=e.checked?diff(e.checked,today()):999,toDep=s.depart?diff(today(),s.depart):999;w.push(['t-warn','ETIAS is recorded as "'+e.status+'" (checked '+(e.checked?fmtD(e.checked):'never')+'). Rules can change before you travel, so recheck the official EU page.']);if(age>14||(toDep<=7&&age>2))w.push(['t-bad','Your ETIAS check is out of date. Open More and recheck the official source.'])}return w}
function render(){const v={home,trip,days:daysV,money:moneyV,list,near,more}[tab]();document.getElementById('app').innerHTML=v;if(tab==='near')drawMap();
 document.getElementById('nav').innerHTML=[['home','Home'],['trip','Trip'],['days','Days'],['money','Money'],['list','Lists'],['near','Near'],['more','More']].map(([k,l])=>`<button class="${tab===k?'on':''}" data-go="${k}">${l}</button>`).join('')}
function home(){const s=S.setup,t=today(),du=s.depart?diff(t,s.depart):null,len=days().length,tot=totals();
 const next=destOn(t)||S.dests.filter(d=>d.from>t).sort((a,b)=>a.from.localeCompare(b.from))[0];
 const left=s.budget?s.budget-tot.est:null,pct=s.budget?Math.min(100,tot.est/s.budget*100):0;
 const upcoming=S.exp.filter(e=>e.status!=='Paid'&&e.due).sort((a,b)=>a.due.localeCompare(b.due)).slice(0,4);
 const td=S.acts.filter(a=>a.date===t).sort((a,b)=>a.time.localeCompare(b.time));
 return `<h1>Eurotrip Planner</h1><p class="sub">Dec 2026 – Jan 2027. Everything is saved on this device.</p>
 <div class="hero"><div class="big">${du==null?'–':du>0?du:du===0?'Today':'Away'}</div><p>${du==null?'Set your dates in the Trip tab':du>0?'days until departure':du===0?'Departure day':'Trip under way or finished'}</p>
 <p>${len?len+' days':''}${len&&S.dests.length?' · ':''}${S.dests.length?S.dests.map(d=>esc(d.city)).join(', '):'No destinations yet'}</p></div>
 <div class="row" style="margin:0 0 10px"><button class="grow" data-locate>Find things near me</button><button class="alt" data-go="near">Search a place</button></div>
 ${warnings().map(([c,m])=>`<div class="note ${c}">${esc(m)}</div>`).join('')}
 ${next?`<div class="card"><h3>Next destination</h3><b>${esc(next.city)}, ${esc(next.country)}</b><div class="sub">${fmtD(next.from)} to ${fmtD(next.to)}</div><a class="btn alt sm" target="_blank" rel="noopener" href="https://www.google.com/search?q=${encodeURIComponent('weather forecast '+next.city)}">Check weather forecast</a></div>`:''}
 ${td.length?`<div class="card"><h3>Today</h3>${td.map(a=>`<div class="act">${esc(a.time)} ${esc(a.title)}</div>`).join('')}</div>`:''}
 <div class="card"><h3>Budget</h3><div class="bar"><i class="${left!=null&&left<0?'over':''}" style="width:${pct}%"></i></div>
 <div class="row sp" style="margin-top:8px"><span>Planned and recorded ${money(tot.est)}</span><span>${s.budget?'Budget '+money(+s.budget):'No budget set'}</span></div>
 <div class="sub">Paid ${money(tot.paid)} · Outstanding ${money(tot.out)}${tot.miss?' · '+tot.miss+' item(s) need an exchange rate':''}</div></div>
 <div class="card"><h3>Upcoming payments</h3>${upcoming.length?upcoming.map(e=>`<div class="row sp"><span>${esc(e.desc)}</span><span class="tag ${e.due<t?'t-bad':'t-warn'}">${fmtD(e.due)}</span></div>`).join(''):'<span class="sub">Nothing due. Add payments in Money.</span>'}</div>`}
function trip(){const s=S.setup;const f=(k,l,t='text')=>`<label>${l}</label><input type="${t}" data-s="${k}" value="${esc(s[k])}">`;
 return `<h1>Trip</h1><p class="sub">Set up your trip. Dates can be changed any time.</p>
 <div class="card"><label>Leaving from</label><input data-s="home" value="${esc(s.home)}">
 <div class="g2"><div>${f('depart','Departure date','date')}</div><div>${f('ret','Return date','date')}</div></div>
 <div class="g2"><div>${f('nat','Passport nationality')}</div><div>${f('pexp','Passport expiry','date')}</div></div>
 <div class="g2"><div>${f('trav','Travellers','number')}</div><div>${f('budget','Total budget','number')}</div></div>
 <div class="g2"><div>${currencySelect('Home currency',s.cur,'data-s="cur"')}</div><div>${f('pace','Pace (relaxed, balanced, packed)')}</div></div>
 ${f('diet','Dietary needs and allergies')}
 <div class="sub" style="margin-top:8px">Passport details stay on this device only.</div></div>
 <h2>Destinations</h2>
 ${S.dests.map((d,i)=>`<div class="card"><div class="row sp"><div class="grow"><b>${esc(d.city)}, ${esc(d.country)}</b><div class="sub" style="margin:0">${fmtD(d.from)} to ${fmtD(d.to)}</div></div>
 <button class="alt sm" data-up="${i}" aria-label="Move up">↑</button><button class="alt sm" data-dn="${i}" aria-label="Move down">↓</button><button class="alt sm" data-edit="dests|${esc(d.id)}">Edit</button><button class="alt sm" data-deld="${esc(d.id)}">Remove</button></div></div>`).join('')||'<p class="sub">No destinations yet. Add your first stop below.</p>'}
 <div class="card"><h3>Add a destination</h3><div class="g2"><div><label>City</label><input id="dc"></div><div><label>Country</label><input id="dk"></div>
 <div><label>Arrive</label><input id="df" type="date"></div><div><label>Leave</label><input id="dt" type="date"></div></div>
 <button style="margin-top:10px;width:100%" data-adddest>Add destination</button></div>${railCard()}`}
function daysV(){const ds=visibleDays();if(!ds.length)return `<h1>Days</h1>${dayControls()}<p class="sub">Set departure and return dates in the Trip tab to see each day.</p>`;
 return `<h1>Days</h1>${dayControls()}<p class="sub">Times are local to the destination. Add activities or open a destination search.</p>`+ds.map((d,i)=>{const dest=destOn(d),as=S.acts.filter(a=>a.date===d).sort((a,b)=>a.time.localeCompare(b.time));const sum=as.reduce((n,a)=>n+(toHome({amt:+a.cost||0,cur:a.cur||cur()})||0),0);
 return `<div class="card"><div class="row sp"><h3>${fmtD(d)}</h3><span class="tag t-n">${destinationsOn(d).map(x=>esc(x.city)).join(' → ')||'No destination'}</span></div>
 ${as.map((a,j)=>{const clash=as.some((b,k)=>k!==j&&b.time===a.time&&a.time);return `<div class="act"><div class="row sp"><b>${esc(a.time)||'Any time'} ${esc(a.title)}${a.zone?' ('+esc(a.zone)+')':''}</b><span></span></div>${clash?'<span class="tag t-warn">Same start time as another activity</span>':''}
 <div class="row" style="margin-top:4px"><button class="alt sm" data-mv="${esc(a.id)}|-1">← Day</button><button class="alt sm" data-mv="${esc(a.id)}|1">Day →</button><button class="alt sm" data-edit="acts|${esc(a.id)}">Edit</button><button class="alt sm" data-dela="${esc(a.id)}">Delete</button></div></div>`}).join('')||'<span class="sub">Nothing planned.</span>'}
 <div class="g2" style="margin-top:8px"><input data-t="${d}" type="time" aria-label="Start time"><input data-n="${d}" type="number" placeholder="Cost (${cur()})" aria-label="Cost"></div>
 <input data-a="${d}" placeholder="New activity" style="margin-top:6px" aria-label="Activity">
 <div class="row" style="margin-top:6px"><button class="sm" data-adda="${d}">Add activity</button><button class="alt sm" data-rest="${d}">Rest day</button>${dest?`<button class="alt sm" data-wx="${d}">Forecast</button>`:''}${dest?`<a class="btn alt sm" target="_blank" rel="noopener" href="https://www.google.com/maps/search/${encodeURIComponent('restaurants near '+dest.city)}">Find restaurants</a>`:''}</div>
 <div class="sub" id="wx-${d}"></div><div class="sub" style="margin-top:6px">Planned spend ${money(sum)}</div></div>`}).join('')}
function moneyV(){const t=totals(),s=S.setup,n=Math.max(1,days().length);const sorted=[...S.exp].sort((a,b)=>(a.due||'9').localeCompare(b.due||'9'));
 return `<h1>Money</h1>${activityLedger()}<p class="sub">Amounts keep their original currency. Exchange rates are ones you enter.</p>
 <div class="card"><div class="row sp"><span>Planned and recorded</span><b>${money(t.est)}</b></div><div class="row sp"><span>Paid</span><b>${money(t.paid)}</b></div><div class="row sp"><span>Outstanding</span><b>${money(t.out)}</b></div>
 ${s.budget?`<div class="row sp"><span>Remaining budget</span><b>${money(s.budget-t.est)}</b></div><div class="row sp"><span>Average daily budget</span><b>${money(s.budget/n)}</b></div>`:''}
 ${s.trav>1?`<div class="row sp"><span>Per person</span><b>${money(t.est/s.trav)}</b></div>`:''}</div>
 ${Object.keys(t.byCat).length?`<div class="card"><h3>By category</h3>${Object.entries(t.byCat).map(([k,v])=>`<div class="row sp"><span>${esc(k)}</span><span>${money(v)}</span></div>`).join('')}</div>`:''}
 <h2>Payments</h2>${sorted.map(e=>`<div class="card"><div class="row sp"><b>${esc(e.desc)}</b><span>${esc(e.cur)} ${(+e.amt).toFixed(2)}</span></div><div class="sub" style="margin:0">${esc(e.cat)}${e.due?' · due '+fmtD(e.due):''}${e.ref?' · ref '+esc(e.ref):''}</div>
 <div class="row" style="margin-top:6px"><span class="tag ${e.status==='Paid'?'t-ok':'t-warn'}">${esc(e.status)}</span><button class="alt sm" data-tg="${esc(e.id)}">Mark ${e.status==='Paid'?'unpaid':'paid'}</button><button class="alt sm" data-edit="exp|${esc(e.id)}">Edit</button><button class="alt sm" data-dele="${esc(e.id)}">Delete</button></div></div>`).join('')||'<p class="sub">No payments recorded.</p>'}
 <div class="card"><h3>Add payment or cost</h3><label>Description</label><input id="ed"><div class="g2"><div><label>Amount</label><input id="ea" type="number" step="0.01"></div><div><label>Currency</label><input id="ec" value="${esc(cur())}"></div>
 <div><label>Category</label><select id="ek">${CATS.map(c=>`<option>${c}</option>`).join('')}</select></div><div><label>Due date</label><input id="eu" type="date"></div></div>
 <label>Confirmation reference (optional)</label><input id="er"><button style="margin-top:10px;width:100%" data-adde>Add</button></div>
 <div class="card"><h3>Exchange rates to ${esc(cur())}</h3><p class="sub">Enter a rate you’ve looked up. It’s saved with today’s date.</p>
 ${Object.entries(S.rates).filter(([k])=>k.endsWith('>'+cur())).map(([k,r])=>`<div class="row sp"><span>1 ${esc(k.split('>')[0])} = ${r.r} ${esc(cur())}</span><span class="sub" style="margin:0">entered ${esc(r.at)}</span></div>`).join('')}
 <div class="g2"><input id="rc" placeholder="Currency, e.g. EUR"><input id="rv" type="number" step="0.0001" placeholder="Rate"></div><button class="sm" style="margin-top:8px" data-addr>Save rate</button> <button class="alt sm" style="margin-top:8px" data-fxlive>Fetch live rates</button></div>`}
function list(){return `<h1>Lists</h1><h2>Packing</h2><div class="card">${S.pack.map((p,i)=>`<label class="chk"><input type="checkbox" data-pk="${i}" ${p.done?'checked':''}><span class="${p.done?'done':''}">${esc(p.t)}</span><button class="alt sm" style="margin-left:auto" data-delp="${i}">×</button></label>`).join('')}
 <div class="row" style="margin-top:8px"><input id="pn" placeholder="Add item" class="grow"><button data-addp>Add</button></div></div>
 <h2>Bookings and documents</h2><p class="sub">Notes only. Don’t store card numbers or security codes here.</p>
 ${S.docs.map(d=>`<div class="card"><b>${esc(d.t)}</b><div class="sub" style="margin:0">${esc(d.ref)}</div><div>${esc(d.note)}</div><button class="alt sm" style="margin-top:6px" data-deldoc="${esc(d.id)}">Delete</button></div>`).join('')}
 <div class="card"><label>What (e.g. Flight, Hotel Vienna)</label><input id="bt"><label>Reference number</label><input id="br"><label>Notes (times, address, contact)</label><textarea id="bn" rows="2"></textarea><button style="margin-top:10px;width:100%" data-adddoc>Save booking</button></div>`}
function more(){const cs=[...new Set(S.dests.map(d=>d.country.trim()).filter(Boolean))];const nat=S.setup.nat||'your passport';
 const link=(u,l)=>`<a href="${u}" target="_blank" rel="noopener">${l}</a>`;
 const card=c=>{const l=c.toLowerCase();let body;
  if(isSch(c))body=`<li>${link('https://travel-europe.europa.eu/ees_en','EU Entry/Exit System (EES)')}</li><li>${link('https://travel-europe.europa.eu/etias_en','ETIAS travel authorisation')}</li><li>${link('https://home-affairs.ec.europa.eu/policies/schengen/schengen-area_en','Schengen area rules, including 90 days in any 180')}</li>`;
  else if(l==='united kingdom'||l==='uk'||l==='england'||l==='scotland'||l==='wales')body=`<li>${link('https://www.gov.uk/check-uk-visa','Check if you need a UK visa')}</li><li>${link('https://www.gov.uk/guidance/electronic-travel-authorisation-eta','UK Electronic Travel Authorisation (ETA)')}</li>`;
  else if(l==='ireland')body=`<li>${link('https://www.irishimmigration.ie/coming-to-visit-ireland/','Irish Immigration: visiting Ireland')}</li>`;
  else body=`<li>Look up the official immigration site of ${esc(c)}.</li>`;
  return `<div class="card"><div class="row sp"><h3>${esc(c)}</h3><span class="tag t-warn">Needs manual verification</span></div><ul style="margin:6px 0;padding-left:20px">${body}<li>${link('https://www.smartraveller.gov.au/destinations','Smartraveller advice (Australian travellers)')}</li></ul><div class="sub" style="margin:0">Checked by you on: <input type="date" data-chk="${esc(c)}" value="${esc((S.checked||{})[c]||'')}"></div></div>`};
 return `<h1>More</h1><h2>Entry requirements</h2><p class="sub">For ${esc(nat)}. This app doesn’t decide visa rules. Open each official page, confirm, then record the date you checked.</p>
 ${cs.some(isSch)?`<div class="card"><div class="row sp"><h3>ETIAS (Schengen)</h3><span class="tag ${S.etias.status==='Verified — official source checked'?'t-ok':'t-warn'}">${esc(S.etias.status)}</span></div>
 <p style="margin:6px 0">The European Commission says ETIAS is not in operation and no applications are being collected. No launch date was confirmed when this was last checked. Don’t apply through any other site: unofficial sites are scams or add fees.</p>
 <ul style="margin:6px 0;padding-left:20px"><li>${link('https://home-affairs.ec.europa.eu/policies/schengen-borders-and-visa/smart-borders/european-travel-information-authorisation-system_en','European Commission: ETIAS status')}</li><li>${link('https://travel-europe.europa.eu/etias_en','Official ETIAS portal')}</li></ul>
 <div class="sub" style="margin:0">Last checked ${S.etias.checked?fmtD(S.etias.checked):'never'}. Seeded on 17 Oct 2026 from EU pages found by search, not a live check. Fee: EU pages say €7, but other sources report €20, so confirm when applications open. Your trip is in Dec 2026 and Jan 2027, so recheck before you book and again within a week of departure.</div>
 <label>Status you have confirmed</label><select data-es>${['Application not yet available','Action required','Verified — official source checked','Awaiting confirmation','Not applicable','Needs manual verification'].map(o=>`<option ${o===S.etias.status?'selected':''}>${o}</option>`).join('')}</select>
 <button class="sm" style="margin-top:8px" data-etiaschk>I rechecked the official page today</button></div>`:''}
 ${cs.length?cs.map(card).join(''):'<p class="sub">Add destinations to see official links.</p>'}
 <div class="note t-warn">Use only official government sites. Third-party visa sites often add large fees.</div>
 ${safeGuide(cs)}<h2>Your data</h2><div class="card"><div class="row"><button data-export>Export backup</button><button class="alt" data-theme>Switch light/dark</button><button class="alt" data-wipe>Delete all data</button></div></div>
 <h2>Not included yet</h2><div class="card sub">Live flight, hotel, train, weather and menu search; maps; document uploads; push notifications; accounts and sync; and offline caching need a server, API keys and accounts. This version doesn’t invent any of that data. Where it would appear, it links to the official source instead.</div>`}
const COL={'Attractions and viewpoints':'#c8372d','Historic sites':'#7c5c3b','Museums and galleries':'#8e44ad','Parks and gardens':'#2e8b57','Markets':'#d4a017','Food and drink':'#e67e22','Entertainment and nightlife':'#0ea5e9','Transport stations':'#2563eb','Health and emergency':'#111827'};
const CATKEYS={all:'All types',attractions:'Attractions and viewpoints',historic:'Historic sites',museums:'Museums and galleries',parks:'Parks and gardens',markets:'Markets',food:'Food and drink',entertainment:'Entertainment and nightlife',transport:'Transport stations',health:'Health and emergency'};
const SAFE={'singapore':['Singapore Police Force','https://www.police.gov.sg/'],'france':['Ministry of the Interior','https://www.interieur.gouv.fr/'],'belgium':['Statbel','https://statbel.fgov.be/'],'netherlands':['Statistics Netherlands (CBS)','https://www.cbs.nl/'],'denmark':['Statistics Denmark','https://www.dst.dk/'],'sweden':['Swedish National Council for Crime Prevention','https://bra.se/'],'finland':['Statistics Finland','https://stat.fi/'],'estonia':['Statistics Estonia','https://www.stat.ee/'],'latvia':['Official Statistics Portal','https://stat.gov.lv/'],'poland':['Polish Police statistics','https://statystyka.policja.pl/'],'czechia':['Czech Police','https://www.policie.cz/'],'germany':['Federal Criminal Police Office (BKA)','https://www.bka.de/'],'united kingdom':['data.police.uk','https://data.police.uk/'],'ireland':['Central Statistics Office','https://www.cso.ie/']};
const N={pos:null,label:'',cc:'',country:'',res:[],wx:null,at:null,r:1000,cat:'all',indoor:'any',free:false,hours:false,time:120,now:false,busy:'',err:'',found:[],q:'',crime:null,capped:false};
async function apiP(p,b){return request(p,b)}
function locate(){if(!navigator.geolocation){N.err='This browser has no location service. Search for a place instead.';render();return}
 N.busy='Finding your location…';N.err='';render();
 navigator.geolocation.getCurrentPosition(p=>setPos(p.coords.latitude,p.coords.longitude,'GPS',p.coords.accuracy),e=>{N.busy='';N.err=e.code===1?'Location is turned off for this site. On iPhone, go to Settings, Privacy and Security, Location Services, Safari Websites, or search for a place below.':e.code===2?'Your phone couldn’t work out its position. Search for a place instead.':'Finding your location took too long. Try again or search for a place.';render()},{enableHighAccuracy:true,timeout:15000,maximumAge:60000})}
async function setPos(lat,lon,src,acc){const requestSeq=N.seq=(N.seq||0)+1;N.pos={lat,lon,src,acc};N.err='';N.crime=null;N.found=[];N.busy='Finding places…';render();
 const[rv,nb]=await Promise.allSettled([apiP('/api/reverse',{lat,lon}),apiP('/api/nearby',{lat,lon,radius:N.r,cat:N.cat})]);if(requestSeq!==N.seq)return;N.busy='';
 if(rv.status==='fulfilled'){N.label=rv.value.label;N.cc=rv.value.cc;N.country=rv.value.country}else{N.label='';N.cc='';N.country=''}
 if(nb.status==='fulfilled'){N.res=nb.value.items;N.wx=nb.value.weather;N.capped=nb.value.capped;N.at=nb.value.fetchedAt}else{N.res=[];N.err='Couldn’t load places: '+nb.reason.message+'. The place provider did not respond. Try Refresh or search a different area.'}
 render()}
const refetch=()=>{if(N.pos)setPos(N.pos.lat,N.pos.lon,N.pos.src,N.pos.acc)};
async function nsearch(){const q=((document.getElementById('nq')||{}).value||'').trim();if(!q)return toast('Type a place first.');N.q=q;N.busy='Searching…';N.err='';render();
 try{const j=await api('/api/geocode?q='+encodeURIComponent(q));N.found=j.results;N.busy='';if(!j.results.length)N.err='No match. Try a city or street name.';render()}catch(e){N.busy='';N.err='Search failed: '+e.message;render()}}
async function ncrime(){if(!N.pos)return;const key=N.pos.lat+','+N.pos.lon;N.busy='Loading official crime figures…';render();let data;try{data=await apiP('/api/crime',{lat:N.pos.lat,lon:N.pos.lon})}catch(e){data={status:'unavailable',message:e.message}}if(!N.pos||N.pos.lat+','+N.pos.lon!==key)return;N.crime=data;N.busy='';render()}
function nclear(){N.seq=(N.seq||0)+1;Object.assign(N,{pos:null,label:'',cc:'',country:'',res:[],wx:null,at:null,found:[],q:'',crime:null,busy:'',err:'',capped:false,now:false});render()}
const fm=d=>d<1000?Math.round(d/10)*10+' m':(d/1000).toFixed(1)+' km';
const dirG=x=>'https://www.google.com/maps/dir/?api=1&destination='+x.lat+','+x.lon+'&travelmode=walking',dirA=x=>'https://maps.apple.com/?dirflg=w&daddr='+x.lat+','+x.lon;
function nearList(){const wet=N.wx&&(N.wx.rainProb>=60||N.wx.snow>0.5),maxD=N.now?(N.time/3)*80:1e9;
 const L=N.res.filter(x=>(N.indoor==='any'||(N.indoor==='indoor'?x.indoor===true:x.indoor===false))&&(!N.free||x.fee==='free')&&(!N.hours||x.hours)&&(!N.now||(x.openNow===true&&x.kind!=='Transport stations'&&x.kind!=='Health and emergency'))&&x.dist<=maxD);
 L.forEach(x=>{x.score=x.dist/1000+(x.openNow===true?-.3:x.openNow===false?2:0)+(wet&&x.indoor===false?1.5:0)});return L.sort((a,b)=>a.score-b.score)}
function card(x){const wet=N.wx&&(N.wx.rainProb>=60||N.wx.snow>0.5);
 return `<div class="card"><div class="row sp"><b>${esc(x.name)}</b><span class="tag t-n">${esc(x.kind)}</span></div>
 <div class="sub" style="margin:2px 0">${fm(x.dist)} away, about ${Math.max(1,Math.round(x.dist/80))} min walk in a straight line</div>
 <div>${x.openNow===true?'<span class="tag t-ok">Open now</span> ':x.openNow===false?'<span class="tag t-warn">Closed now</span> ':''}${x.hours?esc(x.hours):'Opening hours not listed'}</div>
 <div class="sub" style="margin:2px 0">${x.fee==='free'?'Free to enter.':x.fee==='paid'?'Paid entry, price not listed.':'Cost not listed.'} No ratings are available from this source.${wet&&x.indoor===false?' Ranked lower because rain or snow is likely.':''}</div>
 ${x.desc?`<div>${esc(x.desc)}</div>`:''}
 <div class="row" style="margin-top:6px"><a class="btn alt sm" target="_blank" rel="noopener" href="${dirA(x)}">Apple Maps</a><a class="btn alt sm" target="_blank" rel="noopener" href="${dirG(x)}">Google Maps</a>${x.website?`<a class="btn alt sm" target="_blank" rel="noopener" href="${esc(x.website)}">Website</a>`:''}</div>
 <div class="sub" style="margin:6px 0 0">Source: <a target="_blank" rel="noopener" href="https://www.openstreetmap.org/${esc(x.id)}">OpenStreetMap</a>${x.edited?', last edited '+fmtD(x.edited.slice(0,10)):''}. Community data, so confirm before you go.</div></div>`}
function drawMap(){try{const el=document.getElementById('map');if(!el||!N.pos)return;if(typeof L==='undefined'){el.textContent='The map couldn’t load. You may be offline.';return}
 const m=L.map(el).setView([N.pos.lat,N.pos.lon],N.r>=10000?10:N.r>=5000?12:N.r>=1000?14:15);L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© OpenStreetMap contributors'}).addTo(m);
 L.circleMarker([N.pos.lat,N.pos.lon],{radius:9,color:'#fff',weight:3,fillColor:'#14213d',fillOpacity:1}).addTo(m).bindPopup(N.pos.src==='GPS'?'Your location':'Searched location');
 nearList().slice(0,80).forEach(x=>L.circleMarker([x.lat,x.lon],{radius:7,color:'#fff',weight:2,fillColor:COL[x.kind]||'#555',fillOpacity:.95}).addTo(m).bindPopup('<b>'+esc(x.name)+'</b><br>'+esc(x.kind)+', '+fm(x.dist)+'<br><a target="_blank" rel="noopener" href="'+dirG(x)+'">Directions</a>'))}catch(e){}}
function crimeV(c){if(c.status!=='ok')return `<div class="note t-warn">${esc(c.message||'No figures available.')} <a target="_blank" rel="noopener" href="${esc(c.source||'https://data.police.uk/')}">data.police.uk</a></div>`;
 return `<b>Recorded incidents ${esc(c.area)}</b><div class="sub" style="margin:0">${esc(c.measure)}. Latest data published ${esc(c.published)}.</div>
 ${c.fetchedAt?'<p class="sub">Fetched '+esc(new Date(c.fetchedAt).toLocaleString('en-AU'))+'</p>':''}
 ${c.months.length>1?'<p>Change from preceding month: '+(c.months[0].total-c.months[1].total)+' reported incidents. Counts, not population-adjusted rates.</p>':''}
 ${c.months.map(m=>`<div class="row sp"><span>${esc(m.month)}</span><b>${m.total}</b></div>`).join('')}
 <div class="sub" style="margin:6px 0 2px">Latest month by type:</div>${Object.entries(c.months[0].by).sort((a,b)=>b[1]-a[1]).map(([k,v])=>`<div class="row sp"><span>${esc(k.replace(/-/g,' '))}</span><span>${v}</span></div>`).join('')||'<span class="sub">None recorded.</span>'}
 <div class="sub" style="margin-top:6px">${esc(c.limits)} Source: <a target="_blank" rel="noopener" href="${esc(c.source)}">data.police.uk</a>.</div>`}
function safetyBlock(){const a=SAFE[(N.country||'').toLowerCase()];
 return `<h2>Local safety guide</h2><div class="card"><p style="margin:0 0 8px">This gives official sources and figures. It doesn’t rate neighbourhoods, and a lack of data doesn’t mean an area is safe.</p>
 ${N.cc==='gb'?(N.crime?crimeV(N.crime):`<button class="sm" data-ncrime>Show recorded crime near here</button><div class="sub">England, Wales and Northern Ireland only.</div>`):`<p style="margin:0">Suburb-level official figures for ${esc(N.country||'this country')} aren’t available in this app, so risk can’t be reliably assessed at that level.${a?` Start with <a target="_blank" rel="noopener" href="${a[1]}">${esc(a[0])}</a>.`:''}</p>`}
 <p class="sub" style="margin:8px 0 0">Emergency: 112 works across the EU. In the UK call 999 (112 also works). This app has no route-level safety data, so it doesn’t rate routes. Use main, busy streets at night and check <a target="_blank" rel="noopener" href="https://www.smartraveller.gov.au/destinations">Smartraveller</a> and <a target="_blank" rel="noopener" href="https://meteoalarm.org/">MeteoAlarm</a> for official alerts.</p></div>`}
function safeGuide(cs){return `<h2>Local safety guide</h2><p class="sub">Official sources for each country. Find the crime statistics section on each site, and check the date and area covered.</p>`+(cs.map(c=>{const a=SAFE[c.toLowerCase()];return `<div class="card"><div class="row sp"><h3>${esc(c)}</h3><span class="tag t-warn">Needs manual verification</span></div>${a?`<a target="_blank" rel="noopener" href="${a[1]}">${esc(a[0])}</a>`:'No source listed yet.'}</div>`}).join('')||'<p class="sub">Add destinations to see sources.</p>')+`<div class="note t-warn">Official figures differ by country in what they count and how. Don’t compare countries directly, and never read a lack of data as a sign of safety.</div>`}
function near(){const L2=N.pos?nearList():[],late=N.wx&&(()=>{const h=new Date(Date.now()+N.wx.offset*1000).getUTCHours();return h>=21||h<5})();
 const opt=(arr,cur)=>arr.map(([k,v])=>`<option value="${k}" ${String(k)===String(cur)?'selected':''}>${v}</option>`).join('');
 return `<h1>Near me</h1><p class="sub">Your location is used only when you tap a button. It isn’t saved or tracked.</p>
 <div class="card"><button style="width:100%" data-locate>Use my current location</button>
 <label>Or search for a place</label><div class="row"><input id="nq" class="grow" value="${esc(N.q)}" placeholder="City, street or landmark"><button data-nsearch>Search</button></div>
 ${N.found.map((f,i)=>`<button class="alt sm" style="display:block;width:100%;text-align:left;margin-top:6px;height:auto" data-npick="${i}">${esc(f.label)}</button>`).join('')}</div>
 ${N.busy?`<div class="note t-n">${esc(N.busy)}</div>`:''}${N.err?`<div class="note t-bad">${esc(N.err)}</div>`:''}
 ${N.pos?`<div class="card"><b>${esc(N.label||'Selected location')}</b><div class="sub" style="margin:0">${N.pos.acc?'Accuracy about '+Math.round(N.pos.acc)+' m. ':''}${N.at?'Places updated '+new Date(N.at).toLocaleTimeString('en-AU')+'.':''}</div>
 <div class="row" style="margin-top:6px"><button class="alt sm" data-nrefresh>Refresh</button><button class="alt sm" data-nclear>Clear location</button></div></div>
 <div class="g2"><div><label>Distance</label><select data-nf="r">${opt([[500,'500 m'],[1000,'1 km'],[5000,'5 km'],[10000,'10 km'],[25000,'25 km']],N.r)}</select></div>
 <div><label>Type</label><select data-nf="cat">${opt(Object.entries(CATKEYS),N.cat)}</select></div>
 <div><label>Indoor or outdoor</label><select data-nf="indoor">${opt([['any','Any'],['indoor','Indoor'],['outdoor','Outdoor']],N.indoor)}</select></div>
 <div><label>Time available</label><select data-nf="time">${opt([[30,'30 min'],[60,'1 hour'],[120,'2 hours'],[240,'4 hours']],N.time)}</select></div></div>
 <label class="chk"><input type="checkbox" data-nf="free" ${N.free?'checked':''}>Free to enter only</label><label class="chk"><input type="checkbox" data-nf="hours" ${N.hours?'checked':''}>Opening hours listed</label>
 <button style="width:100%;margin:6px 0" data-nnow>${N.now?'Showing open places close by. Tap to show all':'What can I do nearby right now?'}</button>
 ${N.wx?`<div class="sub">Forecast here today: up to ${N.wx.tmax}°C, rain chance ${N.wx.rainProb}%. Outdoor places rank lower when it’s wet.</div>`:''}
 ${late?'<div class="note t-warn">It’s late. Check the last public transport times, and consider a licensed taxi or a reputable rideshare app.</div>':''}
 <div id="map"></div><div class="sub">Map colours: ${Object.entries(COL).map(([k,c])=>`<span style="color:${c}">●</span> ${esc(k)}`).join(', ')}</div>
 ${N.capped?'<div class="note t-warn">Many places found, so this is only a sample. Choose a smaller distance or one type.</div>':''}
 ${L2.map(card).join('')||(N.err?'': '<p class="sub">No matching places from this source. Try a larger distance or fewer filters.</p>')}
 ${safetyBlock()}`:''}`}
function hint(a,b){const s=(a+'>'+b).toLowerCase(),has=x=>s.includes(x);
 if(has('singapore'))return['Flight','Flight. A rail pass doesn’t cover it.'];
 if(has('stockholm>helsinki')||has('helsinki>tallinn'))return['Ferry','Sea crossing. Check whether your pass gives a discount.'];
 if(has('tallinn>riga')||has('riga>warsaw'))return['Bus','Few or no through trains. Check buses or flights.'];
 if(has('edinburgh>ireland')||has('edinburgh>belfast'))return['Ferry','Needs a sea crossing. Check rail-and-sail options.'];
 if(has('>london'))return['Train (pass day)','Eurostar needs a reservation and has a limited number of pass seats.'];
 return['Train (pass day)','Check whether a seat reservation is required.']}
function legList(){const o=[];const sorted=[...S.dests].sort((a,b)=>a.from.localeCompare(b.from));for(let i=1;i<sorted.length;i++){const a=sorted[i-1],b=sorted[i];if(a.city===b.city&&a.country===b.country)continue;o.push({k:b.from+'|'+b.city,date:b.from,a,b,h:hint(a.city,b.city)})}return o}
function railCard(){const r=S.rail,L=legList(),mode=l=>(S.legs[l.k]||{}).mode||l.h[0],res=l=>(S.legs[l.k]||{}).res||'Unknown';
 const used=new Set(L.filter(l=>mode(l)==='Train (pass day)').map(l=>l.date)).size,need=L.filter(l=>mode(l).startsWith('Train')&&res(l)!=='Not needed'&&res(l)!=='Booked').length,over=r.kind==='Flexi'&&used>r.days;
 return `<h2>Train pass and journeys</h2>
 <div class="note t-warn">Interrail is for European residents. If you live in ${/australia/i.test(S.setup.home)?'Australia':'Asia, Africa, the Americas or Oceania'}, you buy a Eurail pass instead. It covers the same trains with the same reservation fees. Buy only from interrail.eu or eurail.com.</div>
 <div class="card"><div class="g2"><div><label>Pass type</label><select data-r="kind">${['Flexi','Continuous'].map(o=>`<option ${o===r.kind?'selected':''}>${o}</option>`).join('')}</select></div><div><label>Travel days included</label><input type="number" data-r="days" value="${esc(r.days)}"></div>
 <div><label>Pass price</label><input type="number" step="0.01" data-r="price" value="${esc(r.price)}"></div><div><label>Currency</label><input data-r="cur" value="${esc(r.cur)}"></div></div>
 <div class="row sp" style="margin-top:8px"><span>Pass days planned: <b>${used}</b>${r.kind==='Flexi'?' of '+esc(r.days):''}</span><span class="tag ${over?'t-bad':'t-ok'}">${over?'Over your pass':'Fits'}</span></div>
 <div class="sub" style="margin:4px 0">${need} train journey(s) with no confirmed reservation status.</div>
 <div class="row"><button class="sm" data-addpass>Add pass to payments</button><a class="btn alt sm" target="_blank" rel="noopener" href="https://www.eurail.com/">Eurail</a><a class="btn alt sm" target="_blank" rel="noopener" href="https://www.interrail.eu/">Interrail</a></div></div>
 ${L.map(l=>`<div class="card"><b>${esc(l.a.city)} to ${esc(l.b.city)}</b><div class="sub" style="margin:0">${fmtD(l.date)}</div><div class="sub" style="margin:2px 0 6px">${esc(l.h[1])}</div>
 <div class="g2"><select aria-label="Travel mode" data-lm="${esc(l.k)}">${['Train (pass day)','Train (own ticket)','Ferry','Bus','Car','Flight'].map(o=>`<option ${o===mode(l)?'selected':''}>${o}</option>`).join('')}</select><select aria-label="Seat reservation" data-lr="${esc(l.k)}">${['Unknown','Not needed','Needed','Booked'].map(o=>`<option ${o===res(l)?'selected':''}>${o}</option>`).join('')}</select></div>
 <div class="row" style="margin-top:6px"><span class="tag t-warn">Needs manual verification</span><a class="btn alt sm" target="_blank" rel="noopener" href="https://www.google.com/search?q=${encodeURIComponent('train timetable '+l.a.city+' to '+l.b.city)}">Find timetable</a></div></div>`).join('')||'<p class="sub">Add two or more destinations to see journeys.</p>'}`}
document.addEventListener('change',e=>{const t=e.target;if(t.dataset.pk!==undefined){S.pack[+t.dataset.pk].done=t.checked;save();render()}if(t.dataset.es!==undefined){S.etias.status=t.value;save();render()}
 if(t.dataset.r){render()}
 if(t.dataset.nf){const k=t.dataset.nf;N[k]=t.type==='checkbox'?t.checked:(k==='r'||k==='time')?+t.value:t.value;if(k==='r'||k==='cat')refetch();else render()}
 if(t.dataset.lm!==undefined){S.legs[t.dataset.lm]=Object.assign(S.legs[t.dataset.lm]||{},{mode:t.value});save();render()}
 if(t.dataset.lr!==undefined){S.legs[t.dataset.lr]=Object.assign(S.legs[t.dataset.lr]||{},{res:t.value});save();render()}if(t.dataset.s&&['depart','ret','cur'].includes(t.dataset.s))render()});
document.addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;const d=b.dataset,v=id=>document.getElementById(id).value.trim();
 if(d.go!==undefined){tab=d.go;render();scrollTo(0,0);return}
 if(d.locate!==undefined){tab='near';locate();return}
 if(d.nrefresh!==undefined){if(N.pos)refetch();else locate();return}
 if(d.nclear!==undefined){nclear();return}
 if(d.nsearch!==undefined){nsearch();return}
 if(d.npick!==undefined){const f=N.found[+d.npick];setPos(f.lat,f.lon,'Searched place',null);return}
 if(d.nnow!==undefined){N.now=!N.now;render();return}
 if(d.ncrime!==undefined){ncrime();return}
 if(d.adddest!==undefined){const c=v('dc'),k=v('dk'),f=v('df'),t=v('dt');if(!c||!k||!f||!t)return toast('Fill in city, country and both dates.');if(t<f)return toast('Leave date must be after arrival.');S.dests.push({id:uid(),city:c,country:k,from:f,to:t});S.dests.sort((a,b)=>a.from.localeCompare(b.from))}
 else if(d.deld!==undefined)S.dests=S.dests.filter(x=>x.id!==d.deld);
 else if(d.up!==undefined||d.dn!==undefined){const i=+(d.up??d.dn),j=d.up!==undefined?i-1:i+1;if(S.dests[j])[S.dests[i],S.dests[j]]=[S.dests[j],S.dests[i]]}
 else if(d.adda!==undefined){const day=d.adda,q=s=>document.querySelector(`[data-${s}="${day}"]`),ti=q('a').value.trim();if(!ti)return toast('Type an activity first.');S.acts.push({id:uid(),date:day,time:q('t').value,title:ti,cost:'',cur:cur()})}
 else if(d.rest!==undefined)S.acts.push({id:uid(),date:d.rest,time:'',title:'Rest day: keep it light',cost:''});
 else if(d.dela!==undefined)S.acts=S.acts.filter(a=>a.id!==d.dela);
 else if(d.mv!==undefined){const[id,o]=d.mv.split('|'),a=S.acts.find(x=>x.id===id),n=shiftDate(a.date,+o);if(days().includes(n))a.date=n;else return toast('That’s outside your trip dates.')}
 else if(d.adde!==undefined){const ds=v('ed'),am=parseFloat(document.getElementById('ea').value);if(!ds||isNaN(am))return toast('Add a description and amount.');S.exp.push({id:uid(),desc:ds,amt:am,cur:(v('ec')||cur()).toUpperCase(),cat:v('ek'),due:v('eu'),ref:v('er'),status:'Unpaid'})}
 else if(d.tg!==undefined){const x=S.exp.find(e=>e.id===d.tg);x.status=x.status==='Paid'?'Unpaid':'Paid'}
 else if(d.dele!==undefined)S.exp=S.exp.filter(x=>x.id!==d.dele);
 else if(d.addr!==undefined){const c=v('rc').toUpperCase(),r=parseFloat(document.getElementById('rv').value);if(!c||!(r>0))return toast('Enter a currency and rate.');S.rates[c+'>'+cur()]={r,at:today()}}
 else if(d.addp!==undefined){const t=v('pn');if(t)S.pack.push({t,done:false})}
 else if(d.delp!==undefined)S.pack.splice(+d.delp,1);
 else if(d.wx!==undefined){wx(d.wx);return}
 else if(d.fxlive!==undefined){fxLive();return}
 else if(d.addpass!==undefined){if(!(S.rail.price>0))return toast('Enter the pass price first.');S.exp.push({id:uid(),desc:S.rail.kind+' rail pass',amt:+S.rail.price,cur:String(S.rail.cur||cur()).toUpperCase(),cat:'Intercity transport',due:'',ref:'',status:'Unpaid'})}
 else if(d.etiaschk!==undefined){S.etias.checked=today()}
 else if(d.adddoc!==undefined){const t=v('bt');if(!t)return toast('Add a name.');S.docs.push({id:uid(),t,ref:v('br'),note:v('bn')})}
 else if(d.deldoc!==undefined)S.docs=S.docs.filter(x=>x.id!==d.deldoc);
 else if(d.export!==undefined){const a=document.createElement('a');a.href='data:application/json;charset=utf-8,'+encodeURIComponent(JSON.stringify(S,null,2));a.download='eurotrip-backup.json';a.click();return}
 else if(d.theme!==undefined){const r=document.documentElement,dk=getComputedStyle(r).colorScheme==='dark';r.dataset.theme=dk?'light':'dark';return}
 else if(d.wipe!==undefined){if(confirm('Delete everything stored on this device?')){try{localStorage.removeItem(KEY)}catch(x){}S=blank()}else return}
 else return;save();const y=scrollY;render();scrollTo(0,y)});
async function api(p){return request(p)}
async function wx(date){const el=document.getElementById('wx-'+date),de=destOn(date);if(!el||!de)return;el.textContent='Checking forecast…';
 try{const j=await api('/api/weather?city='+encodeURIComponent(de.city)+'&date='+date);
 el.textContent=j.status==='forecast'?'Forecast for '+j.place+': '+j.tmin+'° to '+j.tmax+'° (feels '+j.feelsMin+'° to '+j.feelsMax+'°), rain chance '+j.rainProb+'%, snow '+j.snow+' cm, wind '+j.wind+' km/h, sunrise '+String(j.sunrise).slice(11)+', sunset '+String(j.sunset).slice(11)+'. Provider forecast (Open-Meteo), checked '+new Date(j.fetchedAt).toLocaleString('en-AU')+'.':j.message}
 catch(e){el.textContent='No forecast: '+e.message+'. This needs the backend running.'}}
async function fxLive(){const h=cur(),set=new Set(allExpenses().map(e=>e.cur));Object.keys(S.rates).filter(k=>k.endsWith('>'+h)).forEach(k=>set.add(k.split('>')[0]));set.delete(h);let n=0;const bad=[];
 for(const c of set){try{const j=await api('/api/fx?from='+c+'&to='+h);S.rates[c+'>'+h]={r:j.rate,at:j.date};n++}catch(e){bad.push(c)}}
 save();render();toast(n+' rate(s) updated'+(bad.length?'. Failed: '+bad.join(', '):''))}
