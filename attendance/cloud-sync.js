'use strict';
// Live attendance through Supabase (see supabase-config.js). Sessions, taps, the student roster, messages, corrections,
// the audit log and the admin setup (rooms, readers, courses, users, settings) are shared with the Unity door reader,
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

 // attendance_docs: whole documents (last save wins) and lists stored one row per item (no lost messages).
 const DOCS=['rooms','readers','users','courses','courseTitles','settings'];
 const LISTS={queries:q=>q.id,corrections:c=>[c.tagId,c.sessionId,c.timestamp].join('|'),audit:a=>a.id,lateTapReviews:r=>[r.tagId,r.sessionId,r.direction,r.timestamp].join('|')};
 const docSynced=new Map(),listBefore=new Set(Object.keys(LISTS).flatMap(c=>data[c]||[]));
 let docsOn=true;
 const snapshot=()=>JSON.stringify([data.sessions,data.events,people,...DOCS.map(c=>data[c]),...Object.keys(LISTS).map(c=>data[c])]);

 function pull(){
  if(pulling){again=true;return pulling}
  let changed=false;
  pulling=(async()=>{
   const [s,e,st,d]=await Promise.all([db.from('sessions').select('*'),db.from('attendance_events').select('*').order('ts'),db.from('students').select('*').order('id'),docsOn?db.from('attendance_docs').select('collection,key,doc'):{data:[],error:null}]);
   if(s.error||e.error||st.error)throw s.error||e.error||st.error;
   if(d.error){if(/attendance_docs/.test(d.error.message||''))docsOn=false;else throw d.error}   // table not created yet: share sessions and taps only
   const before=snapshot();
   if(st.data.length)people.splice(0,people.length,...st.data.map(r=>({id:r.id,name:r.name,tag:r.tag_id,modules:r.modules||[]})));
   for(const r of s.data){let local=data.sessions.find(x=>x.id===r.id);if(local)Object.assign(local,fromRow(r));else data.sessions.push(local=fromRow(r));synced.set(r.id,JSON.stringify(toRow(local)))}
   data.events=[...e.data.map(fromEvent),...data.events.filter(pending)];
   if(docsOn){
    for(const c of DOCS){const r=d.data.find(x=>x.collection===c&&x.key==='*');if(r){data[c]=r.doc;docSynced.set(c+'|*',JSON.stringify(r.doc))}}
    for(const [c,keyOf] of Object.entries(LISTS)){
     const rows=d.data.filter(x=>x.collection===c).sort((a,b)=>String(a.doc.timestamp||'').localeCompare(String(b.doc.timestamp||'')));
     const keys=new Set(rows.map(x=>x.key));rows.forEach(x=>docSynced.set(c+'|'+x.key,JSON.stringify(x.doc)));
     data[c]=[...rows.map(x=>x.doc),...(data[c]||[]).filter(item=>!keys.has(keyOf(item))&&!listBefore.has(item))];
    }
   }
   changed=snapshot()!==before;
   save();ready=true;state='Live';
  })().catch(err=>{state='Offline: '+(err.message||err)}).finally(()=>{pulling=null;show();if(changed)refresh();if(again){again=false;pull()}});
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
  if(docsOn){
   const sendDoc=(c,k,doc)=>{const json=JSON.stringify(doc);if(docSynced.get(c+'|'+k)===json)return;docSynced.set(c+'|'+k,json);
    writes.push(db.from('attendance_docs').upsert({collection:c,key:k,doc}).then(({error})=>{if(error)fail(error.message)}))};
   for(const c of DOCS)if(data[c]!==undefined)sendDoc(c,'*',data[c]);
   for(const [c,keyOf] of Object.entries(LISTS))for(const item of data[c]||[])if(!listBefore.has(item))sendDoc(c,keyOf(item),item);
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

 const channel=db.channel('kinecto-attendance');
 for(const table of ['sessions','attendance_events'])channel.on('postgres_changes',{event:'*',schema:'public',table},()=>pull());
 channel.subscribe(status=>{if(status==='SUBSCRIBED')pull();else if(status!=='CLOSED'){state='Reconnecting';show()}});
 // Separate channel: if the roster or shared-docs feed fails, sessions and taps stay live.
 const extra=db.channel('kinecto-attendance-docs');
 for(const table of ['students','attendance_docs'])extra.on('postgres_changes',{event:'*',schema:'public',table},()=>pull());
 extra.subscribe();
 show();pull();
 window.KinectoCloud={enabled:true,pull,push,status:()=>state};
})();
