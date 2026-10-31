// Kinecto Attendance: the one connection to Supabase.
// Every table is loaded once, then kept up to date by Supabase Realtime, so all screens show what Unity, the phone
// app and other browsers do within a second. Nothing is kept in browser storage except who is signed in.
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';

const cfg = window.KINECTO_SUPABASE || {};
export const configured = !!(cfg.url && cfg.anonKey);
export const db = configured ? createClient(cfg.url, cfg.anonKey, { auth: { persistSession: false } }) : null;

// table -> primary key and how much to load
const TABLES = {
  sessions: { pk: 'id', order: ['starts_at', true] },
  students: { pk: 'id', order: ['id', true] },
  attendance_events: { pk: 'id', order: ['ts', true] },
  attendance_corrections: { pk: 'id', order: ['created_at', true] },
  tap_attempts: { pk: 'id', order: ['ts', false], limit: 20000 },
  rooms: { pk: 'id', order: ['id', true] },
  readers: { pk: 'id', order: ['id', true] },
  staff: { pk: 'id', order: ['name', true] },
  courses: { pk: 'code', order: ['code', true] },
  audit_log: { pk: 'id', order: ['at', false], limit: 500 },
  jacket_status: { pk: 'jacket_id', order: ['jacket_id', true] },
};

export const T = Object.fromEntries(Object.keys(TABLES).map((t) => [t, []]));
export const status = { state: configured ? 'connecting' : 'not-configured', error: '', loadedAt: null };

const listeners = new Set();
export const onChange = (fn) => listeners.add(fn);
// called once for each new row that arrives over Realtime (not for the first load)
const inserts = new Set();
export const onInsert = (fn) => inserts.add(fn);
let pending = null;
function notify(table) {
  if (pending) { pending.add(table); return; }
  pending = new Set([table]);
  requestAnimationFrame(() => { const t = pending; pending = null; listeners.forEach((fn) => fn(t)); });
}

// Supabase returns at most 1000 rows per request, so big tables are read page by page.
const PAGE = 1000;
async function loadTable(name) {
  const def = TABLES[name];
  const max = def.limit || Infinity;
  const rows = [];
  for (let from = 0; from < max; from += PAGE) {
    const to = Math.min(from + PAGE, max) - 1;
    const { data, error } = await db.from(name).select('*').order(def.order[0], { ascending: def.order[1] }).order(def.pk, { ascending: def.order[1] }).range(from, to);
    if (error) throw new Error(`${name}: ${error.message}`);
    rows.push(...data);
    if (data.length < to - from + 1) break;
  }
  T[name] = def.order[1] ? rows : rows.reverse();   // keep every list oldest first
}

export async function loadAll() {
  if (!configured) return;
  try {
    await Promise.all(Object.keys(TABLES).map(loadTable));
    status.state = 'live'; status.error = ''; status.loadedAt = new Date();
  } catch (e) {
    status.state = 'error'; status.error = e.message;
    if (/does not exist|schema cache/i.test(e.message)) status.error += ' · apply supabase/migrations/20261030100000_attendance_desk.sql';
  }
  notify('*');
}

function apply(name, payload) {
  const pk = TABLES[name].pk;
  const list = T[name];
  if (payload.eventType === 'DELETE') {
    const id = payload.old?.[pk];
    T[name] = list.filter((r) => r[pk] !== id);
  } else {
    const row = payload.new;
    const i = list.findIndex((r) => r[pk] === row[pk]);
    if (i >= 0) list[i] = row; else list.push(row);
    const lim = TABLES[name].limit;
    if (lim && list.length > lim) list.splice(0, list.length - lim);
    if (payload.eventType === 'INSERT' && i < 0) inserts.forEach((fn) => { try { fn(name, row); } catch (e) { console.error(e); } });
  }
  notify(name);
}

export function startRealtime() {
  if (!configured) return;
  const ch = db.channel('kinecto-attendance-desk');
  for (const name of Object.keys(TABLES)) {
    ch.on('postgres_changes', { event: '*', schema: 'public', table: name }, (p) => apply(name, p));
  }
  ch.subscribe((s) => {
    if (s === 'SUBSCRIBED') { if (status.state !== 'live') loadAll(); }
    else if (s === 'CHANNEL_ERROR' || s === 'TIMED_OUT') { status.state = 'reconnecting'; notify('*'); }
  });
  // After the laptop sleeps or the network drops, reload so nothing is missed.
  window.addEventListener('online', loadAll);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) loadAll(); });
}

// ---------- writes (each one shows up everywhere through Realtime) ----------
async function run(promise) {
  const { data, error } = await promise;
  if (error) throw new Error(error.message);
  return data;
}

export const api = {
  openSession: (id, by) => run(db.from('sessions').update({ status: 'open', opened_at: new Date().toISOString(), closed_at: null, changed_by: by }).eq('id', id)),
  closeSession: (id, by) => run(db.from('sessions').update({ status: 'closed', closed_at: new Date().toISOString(), changed_by: by }).eq('id', id)),
  createSessions: (rows) => run(db.from('sessions').insert(rows)),
  markByHand: (row) => run(db.from('attendance_corrections').insert(row).select().single()),
  undoMark: (id) => run(db.from('attendance_corrections').update({ undone_at: new Date().toISOString() }).eq('id', id)),
  tap: (tag, direction, readerId, sessionId) => run(db.rpc('record_tap', { p_tag: tag, p_direction: direction, p_reader_id: readerId, p_session_id: sessionId, p_source: 'Kinecto Attendance test' })),
  autoSessions: () => db.rpc('auto_sessions'),
  audit: (actor, action, detail) => run(db.from('audit_log').insert({ actor, action, detail })),
  saveStaff: (id, patch) => run(db.from('staff').update(patch).eq('id', id)),
  addStaff: (row) => run(db.from('staff').insert(row)),
  addRoom: (row) => run(db.from('rooms').insert(row)),
  saveRoom: (id, patch) => run(db.from('rooms').update(patch).eq('id', id)),
  addReader: (row) => run(db.from('readers').insert(row)),
  addCourse: (row) => run(db.from('courses').insert(row)),
  saveCourse: (code, patch) => run(db.from('courses').update(patch).eq('code', code)),
};
