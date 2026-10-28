'use strict';
// Browser-side integration adapter. The server must authenticate devices and validate taps.
// Expected GET response: {events:[{id,reader_id,tag_id,direction,ts,session_id}]} or array.
(function(){
 const CFG='kinecto-api-config-v1';
 const defaults={url:'',interval:5000,enabled:false};
 let config;try{config={...defaults,...JSON.parse(localStorage.getItem(CFG)||'{}')}}catch{config={...defaults}}
 let timer=null,busy=false,lastError='',lastSync='',imported=0;
 const getStatus=()=>({config:{...config},lastError,lastSync,imported});
 function configure(next){config={...config,...next};config.url=String(config.url||'').trim().replace(/\/$/,'');config.interval=Math.max(2000,Number(config.interval)||5000);localStorage.setItem(CFG,JSON.stringify(config));restart()}
 function normalize(raw){
  const id=String(raw.id??raw.event_id??'').trim();
  const readerId=String(raw.reader_id??raw.readerId??'').trim();
  const tag=String(raw.tag_id??raw.tagId??'').trim();
  const direction=String(raw.direction??'').toUpperCase();
  const timestamp=String(raw.ts??raw.timestamp??'').trim();
  const sessionId=String(raw.session_id??raw.sessionId??'').trim();
  if(!readerId||!tag||!['IN','OUT'].includes(direction)||!timestamp||!Number.isFinite(Date.parse(timestamp)))return null;
  return {id,readerId,tag,direction,timestamp,sessionId};
 }
 function ingest(raw){
  const x=normalize(raw);if(!x)return 'invalid';
  // Demo tag-to-student lookup. Production must resolve this on the server.
  const p=people.find(p=>p.tag===x.tag||p.id===x.tag);if(!p)return 'unknown tag';
  const matches=data.sessions.filter(s=>s.reader===x.readerId&&s.status==='open'&&p.modules.includes(s.module));
  const s=x.sessionId?data.sessions.find(s=>s.id===x.sessionId):matches.length===1?matches[0]:null;
  if(!s||s.reader!==x.readerId||s.status!=='open'||!p.modules.includes(s.module))return 'unresolved session';
  const key=x.id||[x.readerId,x.tag,x.direction,x.timestamp,s.id].join('|');
  data.integrationIds ||= [];
  if(data.integrationIds.includes(key))return 'duplicate';
  // GET feed must contain backend-validated, accepted events only.
  // Local checks protect the demo UI from invalid ordering and duplicate attendance.
  const previous=data.events.filter(e=>e.sessionId===s.id&&e.tagId===p.id);
  if(previous.some(e=>e.direction===x.direction))return 'duplicate direction';
  if(x.direction==='OUT'&&!previous.some(e=>e.direction==='IN'))return 'missing IN';
  data.events.push({tagId:p.id,direction:x.direction,sessionId:s.id,readerId:x.readerId,source:'Unity API',timestamp:x.timestamp});
  data.integrationIds.push(key);
  if(data.integrationIds.length>5000)data.integrationIds=data.integrationIds.slice(-5000);
  data.audit.push({id:'API-'+key,action:'NFC tap',detail:p.id+' · '+x.direction+' · '+s.id+' · Unity API',actor:'Attendance API',timestamp:x.timestamp});
  save();return 'accepted';
 }
 async function poll(){
  if(busy||!config.enabled||!config.url)return;
  busy=true;
  try{
   const response=await fetch(config.url,{method:'GET',headers:{Accept:'application/json'},cache:'no-store'});
   if(!response.ok)throw new Error('HTTP '+response.status);
   const body=await response.json();const events=Array.isArray(body)?body:body.events;
   if(!Array.isArray(events))throw new Error('Expected an array or {events: [...]}');
   let count=0,ignored=0;for(const event of events){const outcome=ingest(event);if(outcome==='accepted')count++;else if(outcome!=='duplicate'&&outcome!=='duplicate direction')ignored++}
   imported+=count;lastSync=new Date().toISOString();lastError=ignored?ignored+' event(s) not imported (invalid, unknown tag, or ambiguous session).':'';
   if(count&&typeof render==='function'&&role)render();
   else if(document.getElementById('apiStatus'))document.getElementById('apiStatus').textContent=statusText();
  }catch(e){lastError=String(e.message||e);if(document.getElementById('apiStatus'))document.getElementById('apiStatus').textContent=statusText()}
  finally{busy=false}
 }
 function statusText(){return !config.enabled?'Local demo mode. API polling is off.':!config.url?'Enter an events URL to connect.':lastError?'API: '+lastError:lastSync?'Last synced: '+new Date(lastSync).toLocaleString()+' · Imported '+imported+' event(s)':'Waiting for first API response.'}
 function restart(){if(timer)clearInterval(timer);timer=null;if(config.enabled&&config.url){poll();timer=setInterval(poll,config.interval)}}
 window.KinectoIntegration={configure,poll,getStatus,statusText,ingest};
 window.addEventListener('DOMContentLoaded',restart);
})();
