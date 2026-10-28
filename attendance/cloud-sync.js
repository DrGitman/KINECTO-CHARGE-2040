'use strict';
// Live attendance through Supabase (see supabase-config.js). Sessions and taps are shared with the Unity door reader,
// other browsers and other devices; Supabase is the source of truth and this browser's store mirrors it.
// Taps go through the record_tap database function, the same rules the Unity reader uses.
// Off when supabase-config.js is empty: the local demo mode then works exactly as before.
(function(){
 const cfg=window.KINECTO_SUPABASE||{};
 if(!cfg.url||!cfg.anonKey||!window.supabase){window.KinectoCloud={enabled:false};return}
 const db=window.supabase.createClient(cfg.url,cfg.anonKey);
 const synced=new Map(),sending=new Set(),fromBefore=new Set(data.events);
 let ready=false,state='Connecting',pulling=null,again=false,deferred=false;
 const toRow=s=>({id:s.id,module:s.module,title:s.title||null,type:s.type||null,room:s.room||null,reader_id:s.reader||null,time_label:s.time||null,date:s.date||null,status:s.status,opened_at:s.openedAt||null,closed_at:s.closedAt||null});
 const fromRow=r=>({id:r.id,module:r.module,title:r.title,type:r.type,room:r.room,reader:r.reader_id,time:r.time_label,date:r.date||undefined,status:r.status,openedAt:r.opened_at||undefined,closedAt:r.closed_at||undefined});
 const fromEvent=r=>({cloudId:r.id,tagId:r.student_id,direction:r.direction,sessionId:r.session_id,readerId:r.reader_id,source:r.source,timestamp:r.ts});
 // Local-only taps from before cloud mode are not uploaded; taps made on this page are.
 const pending=e=>e.cloudId==null&&!fromBefore.has(e);

 function pull(){
  if(pulling){again=true;return pulling}
  pulling=(async()=>{
   const [s,e]=await Promise.all([db.from('sessions').select('*'),db.from('attendance_events').select('*').order('ts')]);
   if(s.error||e.error)throw s.error||e.error;
   for(const r of s.data){let local=data.sessions.find(x=>x.id===r.id);if(local)Object.assign(local,fromRow(r));else data.sessions.push(local=fromRow(r));synced.set(r.id,JSON.stringify(toRow(local)))}
   data.events=[...e.data.map(fromEvent),...data.events.filter(pending)];
   save();ready=true;state='Live';
  })().catch(err=>{state='Offline: '+(err.message||err)}).finally(()=>{pulling=null;show();refresh();if(again){again=false;pull()}});
  return pulling;
 }

 async function push(){
  if(!ready)return;
  const writes=[];
  for(const s of data.sessions){
   const key=JSON.stringify(toRow(s));if(synced.get(s.id)===key)continue;
   synced.set(s.id,key);
   writes.push(db.from('sessions').upsert(toRow(s)).then(({error})=>{if(error)fail(error.message)}));
  }
  for(const ev of data.events){
   if(!pending(ev)||sending.has(ev))continue;
   sending.add(ev);
   writes.push(db.rpc('record_tap',{p_tag:ev.tagId,p_direction:ev.direction,p_reader_id:ev.readerId||null,p_session_id:ev.sessionId,p_source:ev.source||'browser'}).then(({data:r,error})=>{
    sending.delete(ev);
    if(!error&&r&&r.ok){ev.cloudId=r.event_id;return}
    // Another device got there first, or the session was closed meanwhile: the shared register wins.
    data.events=data.events.filter(x=>x!==ev);fail(error?error.message:r&&r.message);
   }));
  }
  if(writes.length){await Promise.all(writes);pull()}
 }

 function fail(message){notice='Not saved to the shared register: '+(message||'unknown error');save()}

 // Re-render for remote changes, but never while someone is typing in a form on the page.
 function refresh(){const a=document.activeElement;if(a&&a.matches('input,textarea,select')&&$('app').contains(a)){deferred=true;return}if(role)baseRender()}
 document.addEventListener('focusout',()=>{if(deferred){deferred=false;setTimeout(refresh,0)}});

 function show(){
  let b=$('cloudStatus');
  if(!b){b=document.createElement('div');b.id='cloudStatus';b.className='cloud-status';b.setAttribute('role','status');document.body.appendChild(b)}
  b.textContent='Shared register · '+state;b.dataset.state=state==='Live'?'live':'off';
 }

 const baseRender=render;
 render=function(){baseRender();push()};
 setInterval(push,2000);

 db.channel('kinecto-attendance')
  .on('postgres_changes',{event:'*',schema:'public',table:'sessions'},()=>pull())
  .on('postgres_changes',{event:'*',schema:'public',table:'attendance_events'},()=>pull())
  .subscribe(status=>{if(status==='SUBSCRIBED')pull();else if(status!=='CLOSED'){state='Reconnecting';show()}});
 show();pull();
 window.KinectoCloud={enabled:true,pull,push,status:()=>state};
})();
