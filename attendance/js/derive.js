// Everything the screens show is worked out here from the live tables, so no number is typed into a page.
import { T } from './store.js';

export const ONLINE_MS = 2 * 60 * 1000;      // a reader seen in the last 2 minutes is online
export const TARGET = 0.75;                  // NUST 75% attendance rule

// ---------- dates (Windhoek local time, as the browser shows it) ----------
export const dayKey = (d) => { d = new Date(d); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };
export const today = () => dayKey(new Date());
export const hhmm = (d) => d ? new Date(d).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' }) : '—';
export const dayLabel = (d) => new Date(d).toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' });
export const longDay = (d) => new Date(d).toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' });
export const ago = (d) => {
  if (!d) return 'never';
  const s = Math.round((Date.now() - new Date(d)) / 1000);
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.round(s / 60)} min ago`;
  if (dayKey(d) === today()) return hhmm(d);
  const y = new Date(); y.setDate(y.getDate() - 1);
  if (dayKey(d) === dayKey(y)) return 'yesterday';
  return dayLabel(d);
};
export const mondayOf = (d) => { d = new Date(d); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - ((d.getDay() + 6) % 7)); return d; };

// ---------- lookups ----------
export const student = (id) => T.students.find((s) => s.id === id);
export const course = (code) => T.courses.find((c) => c.code === code);
export const staffById = (id) => T.staff.find((s) => s.id === id);
export const reader = (id) => T.readers.find((r) => r.id === id);
export const room = (id) => T.rooms.find((r) => r.id === id);
export const sessionById = (id) => T.sessions.find((s) => s.id === id);
export const initials = (name) => String(name || '?').replace(/^(Dr|Ms|Mr|Mrs|Prof)\.?\s+/i, '').split(/[\s.]+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('');

// the person's courses, busiest first (most students, then most sessions)
export const coursesOf = (me) => (me?.role === 'admin' ? T.courses : T.courses.filter((c) => c.lecturer_id === me?.id || (me?.role === 'assistant' && (me.settings?.courses || []).includes(c.code))))
  .slice().sort((a, b) => enrolled(b.code).length - enrolled(a.code).length || T.sessions.filter((s) => s.module === b.code).length - T.sessions.filter((s) => s.module === a.code).length);
// the room a course is usually taught in
export const usualRoom = (code) => { const n = {}; for (const s of T.sessions) if (s.module === code && s.room) n[s.room] = (n[s.room] || 0) + 1; return Object.entries(n).sort((a, b) => b[1] - a[1])[0]?.[0]; };
export const sessionsOf = (me) => { const codes = new Set(coursesOf(me).map((c) => c.code)); return T.sessions.filter((s) => codes.has(s.module)); };
export const enrolled = (module) => T.students.filter((s) => (s.modules || []).includes(module));

export const readerOnline = (r) => !!(r && r.last_seen && Date.now() - new Date(r.last_seen) < ONLINE_MS);
export const readerState = (r) => (!r ? 'none' : readerOnline(r) ? 'online' : 'offline');

// ---------- one session's register ----------
export function sessionState(s) {
  if (s.status === 'open') return 'live';
  if (s.status === 'closed') return 'closed';
  const start = s.starts_at ? new Date(s.starts_at) : null;
  if (start && start - Date.now() < 60 * 60 * 1000 && start > Date.now()) return 'soon';
  if (s.ends_at && new Date(s.ends_at) < Date.now()) return 'missed';
  return 'planned';
}

export function lateCutoff(s) {
  return s.starts_at ? new Date(new Date(s.starts_at).getTime() + (s.late_after_min ?? 10) * 60000) : null;
}

export function register(s) {
  const events = T.attendance_events.filter((e) => e.session_id === s.id);
  const marks = T.attendance_corrections.filter((c) => c.session_id === s.id && !c.undone_at);
  const cutoff = lateCutoff(s);
  const rows = enrolled(s.module).map((st) => {
    const tin = events.find((e) => e.student_id === st.id && e.direction === 'IN');
    const tout = events.find((e) => e.student_id === st.id && e.direction === 'OUT');
    const mark = marks.find((m) => m.student_id === st.id);
    let state;
    if (tin) state = cutoff && new Date(tin.ts) > cutoff ? 'late' : 'present';
    else if (mark) state = 'manual';
    else state = s.status === 'closed' || sessionState(s) === 'missed' ? 'absent' : s.status === 'open' ? 'notyet' : 'planned';
    return { student: st, tin, tout, mark, state };
  });
  const count = (k) => rows.filter((r) => r.state === k).length;
  const c = { total: rows.length, present: count('present'), late: count('late'), manual: count('manual'), absent: count('absent'), notyet: count('notyet') };
  c.in = c.present + c.late + c.manual;
  return { rows, counts: c, events, marks };
}

export const STATE_LABEL = { present: 'Present', late: 'Late', manual: 'Fixed by hand', absent: 'Absent', notyet: 'Not yet', planned: '—' };
export const STATE_TONE = { present: 'green', late: 'yellow', manual: 'lav', absent: 'pink', notyet: 'pink', planned: 'grey' };

// ---------- course and student statistics (closed sessions only) ----------
export function heldSessions(module) {
  return T.sessions.filter((s) => s.module === module && s.status === 'closed').sort((a, b) => new Date(a.starts_at) - new Date(b.starts_at));
}

export function studentStats(studentId, module) {
  const held = heldSessions(module);
  let attended = 0, late = 0, manual = 0;
  const history = held.map((s) => {
    const r = register(s).rows.find((x) => x.student.id === studentId);
    const st = r ? r.state : 'absent';
    if (st === 'present' || st === 'late' || st === 'manual') attended++;
    if (st === 'late') late++;
    if (st === 'manual') manual++;
    return { session: s, row: r, state: st };
  });
  const remaining = T.sessions.filter((s) => s.module === module && s.status !== 'closed' && s.starts_at && new Date(s.ends_at || s.starts_at) > Date.now()).length;
  const pct = held.length ? attended / held.length : null;
  const total = held.length + remaining;
  const need = Math.max(0, Math.ceil(TARGET * total) - attended);
  return { held: held.length, attended, late, manual, pct, history, remaining, need, reachable: need <= remaining };
}

export function courseStats(module) {
  const held = heldSessions(module);
  const regs = held.map(register);
  const seats = regs.reduce((a, r) => a + r.counts.total, 0);
  const inc = regs.reduce((a, r) => a + r.counts.in, 0);
  const manual = regs.reduce((a, r) => a + r.counts.manual, 0);
  const below = enrolled(module).map((st) => ({ st, s: studentStats(st.id, module) })).filter((x) => x.s.pct != null && x.s.pct < TARGET).sort((a, b) => a.s.pct - b.s.pct);
  return { held, regs, pct: seats ? inc / seats : null, manualPct: inc ? manual / inc : null, below };
}

// attendance per teaching week, oldest first, from the first held session
export function weeklySeries(modules) {
  const held = T.sessions.filter((s) => modules.includes(s.module) && s.status === 'closed' && s.starts_at);
  if (!held.length) return [];
  const first = mondayOf(Math.min(...held.map((s) => new Date(s.starts_at))));
  const weeks = new Map();
  for (const s of held) {
    const w = Math.floor((mondayOf(s.starts_at) - first) / (7 * 864e5));
    const c = register(s).counts;
    const cur = weeks.get(w) || { seats: 0, inc: 0 };
    cur.seats += c.total; cur.inc += c.in; weeks.set(w, cur);
  }
  return [...weeks.entries()].sort((a, b) => a[0] - b[0]).map(([w, v]) => ({ label: `W${w + 1}`, pct: v.seats ? v.inc / v.seats : 0 }));
}

// door quality from every tap attempt at these sessions' readers
// taps at a session's reader during its time window (also the ones rejected before it was opened)
export function doorAttempts(s) {
  const from = s.starts_at ? new Date(s.starts_at).getTime() - 30 * 60000 : 0;
  const to = s.ends_at ? new Date(s.ends_at).getTime() + 30 * 60000 : Infinity;
  return T.tap_attempts.filter((a) => a.session_id === s.id || (!a.session_id && a.reader_id === s.reader_id && +new Date(a.ts) >= from && +new Date(a.ts) <= to));
}

export function tapQuality(sessions) {
  const att = sessions.flatMap(doorAttempts);
  const ok = att.filter((a) => a.ok).length;
  const dup = att.filter((a) => /already recorded/i.test(a.message || '')).length;
  const rejected = att.filter((a) => !a.ok).length;
  return { all: att.length, ok, dup, rejected, firstTime: att.length ? ok / (att.length - dup || 1) : null };
}

export const pct = (v, d = 0) => (v == null ? '—' : `${(v * 100).toFixed(d)}%`);
