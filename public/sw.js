const CACHE='eurotrip-v6-national-rail-brave',SHELL=['./','./index.html','./app.js','./planner.js','./live-ui.js','./rail-ui.js','./connections.js','./manifest.webmanifest','./icon-180.png','./icon-512.png'];
async function cacheApp(){const c=await caches.open(CACHE);await c.addAll(SHELL);}
self.addEventListener('install',event=>event.waitUntil(cacheApp()));
self.addEventListener('activate',event=>event.waitUntil(Promise.all([caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('eurotrip-')&&k!==CACHE).map(k=>caches.delete(k)))),self.clients.claim()])));
self.addEventListener('message',event=>{if(event.data?.type==='CACHE_APP')event.waitUntil(cacheApp().then(()=>event.ports[0]?.postMessage({ok:true})).catch(()=>event.ports[0]?.postMessage({ok:false,error:'Could not save every app file. Stay online and retry.'})));});
self.addEventListener('fetch',event=>{
 const u=new URL(event.request.url);if(event.request.method!=='GET'||u.origin!==location.origin||u.pathname.startsWith('/api/'))return;
 // Only app files are cached. No live responses, access codes, map tiles or arbitrary documents.
 if(!SHELL.some(p=>new URL(p,self.registration.scope).pathname===u.pathname))return;
 event.respondWith(fetch(event.request).then(async r=>{if(r.ok){const c=await caches.open(CACHE);await c.put(event.request,r.clone())}return r}).catch(async()=>{const c=await caches.open(CACHE);const hit=await c.match(event.request);return hit||(event.request.mode==='navigate'?await c.match('./index.html'):new Response('Offline',{status:503}))}));
});
