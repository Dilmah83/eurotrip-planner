const plain=s=>typeof s==='string'?s.replace(/<[^>]*>/g,' ').replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&#39;/g,"'").replace(/\s+/g,' ').trim():'';
function safeLink(value){try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password?u.href:null}catch{return null}}
module.exports=({getJSON})=>async(q,b={})=>{
 const query=typeof b.query==='string'?b.query.trim():'';if(query.length<3||query.length>300)return [400,{error:'Enter a search of 3–300 characters.'}];
 const key=b.apiKey||process.env.BRAVE_SEARCH_API_KEY||'';
 if(!/^[\x21-\x7E]{10,500}$/.test(key))return [428,{error:'Save your Brave Search API key under More → API connections.'}];
 if(!b.apiKey&&!process.env.ACCESS_TOKEN)return [503,{error:'The server needs ACCESS_TOKEN before using a shared Brave key. Alternatively, save your own key on this device.'}];
 const url='https://api.search.brave.com/res/v1/web/search?'+new URLSearchParams({q:query,count:'8',country:'AU',search_lang:'en'});
 try{const j=await getJSON(url,{headers:{Accept:'application/json','X-Subscription-Token':key}},1);if(j.error||(!j.web&&!j.query))throw Error('Invalid response');
 const seen=new Set(),results=(j.web?.results||[]).slice(0,8).flatMap(r=>{const url=safeLink(r.url);if(!url||seen.has(url))return [];seen.add(url);return [{title:plain(r.title).slice(0,250),description:plain(r.description).slice(0,1000),url}]});
 return [200,{results,source:'https://search.brave.com/',fetchedAt:new Date().toISOString(),notice:'Web search results, not verified train schedules, fares, availability or government advice.'}];
 }catch(e){const status=e.status||Number(String(e.message).match(/HTTP (\d+)/)?.[1]);return [[401,403].includes(status)?403:status===429?429:502,{error:[401,403].includes(status)?'Brave rejected this key. Check that it has Web Search API access.':status===429?'Brave’s rate limit was reached. Wait before searching again.':status===402?'Your Brave account needs an active plan or credits.':'Brave Search is unavailable. Try again later.'}]}
};
module.exports.safeLink=safeLink;
