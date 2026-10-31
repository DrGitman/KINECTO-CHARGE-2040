// NUST admin screens: Figma 08b (Readers & rooms) and 08c (Overview, Rooms, Courses, Campus reports,
// Roles & access, Audit log, Reader detail + add reader).
import { T, api } from './store.js';
import { esc, pill, dotPill, btn, chip, kpi, avatar, empty, field, input, select, icon, toast, downloadCsv, bars } from './ui.js';
import * as D from './derive.js';

const head = (title, sub, actions = '', crumbs = '') => `<header class="page-head">${crumbs ? `<p class="crumbs">${crumbs}</p>` : ''}<div><h1>${esc(title)}</h1>${sub ? `<p class="muted">${esc(sub)}</p>` : ''}</div><div class="actions">${actions}</div></header>`;
const cap = (s) => String(s || '').charAt(0).toUpperCase() + String(s || '').slice(1);
const todays = () => T.sessions.filter((s) => s.starts_at && D.dayKey(s.starts_at) === D.today());
const tapsToday = () => T.attendance_events.filter((e) => D.dayKey(e.ts) === D.today());
const thisWeekClosed = () => { const mon = D.mondayOf(new Date()); return T.sessions.filter((s) => s.status === 'closed' && s.starts_at && new Date(s.starts_at) >= mon); };
const attendanceOf = (sessions) => { let seats = 0, inc = 0; for (const s of sessions) { const c = D.register(s).counts; seats += c.total; inc += c.in; } return seats ? inc / seats : null; };
const readerStatusPill = (r) => (D.readerOnline(r) ? pill('Online', 'green') : pill(r.last_seen ? 'Offline' : 'Never seen', 'pink'));

// ================= Overview =================
function overview() {
  const tdy = todays();
  const live = T.sessions.filter((s) => s.status === 'open');
  const offline = T.readers.filter((r) => !D.readerOnline(r));
  const campus = attendanceOf(thisWeekClosed());
  const attention = [];
  for (const r of offline) {
    const needed = tdy.filter((s) => s.reader_id === r.id && s.status !== 'closed');
    attention.push({ text: `Reader ${r.id} ${r.last_seen ? `offline since ${D.ago(r.last_seen)}` : 'has never been seen'}${needed.length ? ` · ${needed.length} session${needed.length === 1 ? '' : 's'} today` : ''}`, tone: needed.length ? 'pink' : 'grey', href: `#/reader?id=${r.id}`, label: 'View' });
  }
  for (const s of live.filter((x) => !x.reader_id)) attention.push({ text: `${s.module} ${s.type || ''} is open with no reader`, tone: 'yellow', href: '#/rooms', label: 'View' });
  for (const c of T.courses) {
    const cs = D.courseStats(c.code);
    if (!c.lecturer_id) attention.push({ text: `${c.code} has no lecturer`, tone: 'pink', href: '#/courses', label: 'Assign' });
    if (cs.below.length) attention.push({ text: `${c.code}: ${cs.below.length} student${cs.below.length === 1 ? '' : 's'} below 75%`, tone: 'yellow', href: '#/reports', label: 'View' });
  }
  const byCourse = T.courses.map((c) => ({ c, pct: attendanceOf(thisWeekClosed().filter((s) => s.module === c.code)) }));
  return `${head('Campus overview', `${D.longDay(new Date())}`, btn('Export week', 'exportWeek', { icon: 'download' }))}
    <div class="kpis five">${kpi('Sessions today', tdy.length, 'cyan', 'ov-today')}${kpi('Live right now', live.length, 'green', 'ov-live')}${kpi('Taps today', tapsToday().length, 'grey', 'ov-taps')}${kpi('Readers offline', offline.length, 'pink', 'ov-off')}${kpi('Attendance this week', D.pct(campus), 'yellow')}</div>
    <div class="grid overview-grid">
      <section class="card"><div class="card-head"><h3>Attendance by course this week</h3></div>
        <ul class="meters">${byCourse.map(({ c, pct }) => `<li><span>${esc(c.code)} · ${esc(c.title)}</span><div class="meter"><i class="${pct != null && pct < 0.8 ? 'gold' : ''}" style="width:${pct == null ? 0 : pct * 100}%"></i></div><b>${D.pct(pct)}</b></li>`).join('')}</ul>
        <p class="muted small">— means no session of that course has closed this week yet.</p></section>
      <section class="card"><div class="card-head"><h3>Needs attention</h3></div>
        ${attention.length ? `<ul class="attention">${attention.slice(0, 7).map((a) => `<li class="${a.tone}"><span>${esc(a.text)}</span><a class="btn secondary sm" href="${esc(a.href)}">${esc(a.label)}</a></li>`).join('')}</ul>` : empty('All clear', 'Every reader is online and no course is below 75%.')}</section>
    </div>
    <section class="card"><div class="card-head"><h3>Live sessions now</h3></div>
      ${live.length ? `<div class="table-wrap"><table class="table"><thead><tr><th>Course</th><th>Room</th><th>Lecturer</th><th>Checked in</th><th>Reader</th><th>Status</th></tr></thead><tbody>${live.map((s) => { const c = D.register(s).counts; const lec = D.staffById(D.course(s.module)?.lecturer_id); const r = D.reader(s.reader_id); return `<tr><td><b>${esc(s.module)} ${esc(s.type || '')}</b></td><td>${esc(s.room || '—')}</td><td>${esc(lec?.name || '—')}</td><td><b>${c.in} / ${c.total}</b></td><td>${esc(s.reader_id || '—')} ${r ? (D.readerOnline(r) ? '' : '<span class="bad small">offline</span>') : ''}</td><td>${pill('Live', 'green')}</td></tr>`; }).join('')}</tbody></table></div>` : empty('No session is open right now')}</section>`;
}

// ================= Readers =================
function readers({ ui }) {
  const online = T.readers.filter(D.readerOnline).length;
  const rejected = T.tap_attempts.filter((a) => !a.ok && D.dayKey(a.ts) === D.today()).length;
  const sel = ui.form.readerSel && D.reader(ui.form.readerSel);
  return `${head('Readers & rooms', `${T.readers.length} cuff readers on campus · ${online} online`, btn('Add reader', 'openModal', { icon: 'plus', data: { 'data-m': 'reader' } }))}
    <div class="kpis four">${kpi('Online', online, 'green', 'rd-on')}${kpi('Offline', T.readers.length - online, 'pink', 'rd-off')}${kpi('Taps today', tapsToday().length, 'cyan', 'rd-taps')}${kpi('Rejected today', rejected, 'yellow', 'rd-rej')}</div>
    <div class="grid side-grid">
      <section class="card">${T.readers.length ? `<div class="table-wrap"><table class="table"><thead><tr><th>Reader</th><th>Room</th><th>Status</th><th>Last tap</th><th>Firmware</th><th></th></tr></thead><tbody>
        ${T.readers.map((r) => { const last = T.tap_attempts.filter((a) => a.reader_id === r.id).at(-1); const rm = D.room(r.room_id); return `<tr class="${sel?.id === r.id ? 'selected' : ''}"><td><b>${esc(r.id)}</b>${r.is_virtual ? ' ' + pill('Virtual', 'lav', 'xs') : ''}</td><td>${esc(rm ? `${rm.name} · ${rm.building || ''}` : '—')}</td><td>${readerStatusPill(r)}</td><td class="muted">${esc(last ? D.ago(last.ts) : '—')}</td><td class="muted">${esc(r.firmware)}</td><td class="right"><a class="btn secondary sm" href="#/reader?id=${esc(r.id)}">${D.readerOnline(r) ? 'Details' : 'Check'}</a></td></tr>`; }).join('')}</tbody></table></div>` : empty('No readers yet', '', btn('Add reader', 'openModal', { data: { 'data-m': 'reader' } }))}</section>
      ${rolesCard()}
    </div>`;
}

function rolesCard() {
  return `<aside class="col gap"><section class="card"><div class="card-head"><h3>Roles</h3></div>
      <div class="role-cards"><div class="cyan"><b>Lecturer</b><span>Own courses: open sessions, register, reports</span></div><div class="yellow"><b>Admin</b><span>All readers, rooms, courses and reports</span></div><div class="green"><b>Student / staff wearer</b><span>Sees own taps in Kinecto Care only</span></div></div></section>
    <section class="card navy-card"><h3>Privacy rules</h3><ul class="plain"><li>Stored per tap: session id, time, tag id</li><li>Never stored: location, movement, temperature</li><li>Tag id is matched to the student number on the server</li><li>Sign-in with NUST email only</li></ul></section></aside>`;
}

function readerDetail({ q }) {
  const r = D.reader(q.id);
  if (!r) return head('Reader', '') + empty('Reader not found', '', '<a class="btn secondary" href="#/readers">Back to readers</a>');
  const rm = D.room(r.room_id);
  const att = T.tap_attempts.filter((a) => a.reader_id === r.id);
  const todayAtt = att.filter((a) => D.dayKey(a.ts) === D.today());
  const hours = Array.from({ length: 11 }, (_, i) => i + 7);
  const perHour = hours.map((h) => todayAtt.filter((a) => new Date(a.ts).getHours() === h).length);
  const maxH = Math.max(1, ...perHour);
  const scheduled = todays().filter((s) => s.reader_id === r.id);
  const online = D.readerOnline(r);
  return `${head(`Reader ${r.id}`, '', `${online ? '' : btn('Notify ICT', 'notifyIct', { data: { 'data-id': r.id } })}`, `<a href="#/readers">Readers</a> / ${esc(r.id)}`)}
    <div class="row gap">${online ? dotPill(`Online · seen ${D.ago(r.last_seen)}`, 'green') : dotPill(r.last_seen ? `Offline since ${D.ago(r.last_seen)}` : 'Never seen: no tap has reached it yet', 'pink', 'red')}</div>
    <div class="grid two-col">
      <section class="card"><div class="card-head"><h3>Details</h3></div>
        <dl class="facts"><dt>Room</dt><dd>${esc(rm ? `${rm.name} · ${rm.building || ''}${r.door ? ', ' + r.door : ''}` : '—')}</dd><dt>Type</dt><dd>${r.is_virtual ? 'Virtual reader in the Unity lab (online while the lab runs)' : 'Classroom door reader'}</dd><dt>Firmware</dt><dd>${esc(r.firmware)}</dd><dt>Key</dt><dd>Stored as a sha256 hash only</dd><dt>Added</dt><dd>${esc(D.dayLabel(r.created_at))} by ${esc(r.added_by)}</dd><dt>Sessions today</dt><dd>${scheduled.length ? scheduled.map((s) => `${D.hhmm(s.starts_at)} ${esc(s.module)} ${esc(s.type || '')}`).join(' · ') : 'None'}</dd></dl></section>
      <section class="card"><div class="card-head"><h3>Taps today</h3><span class="muted small">${todayAtt.length} total · ${todayAtt.filter((a) => !a.ok).length} rejected</span></div>
        <div class="hist">${hours.map((h, i) => `<div class="bar"><b style="height:${(perHour[i] / maxH) * 100}%">${perHour[i] ? `<em>${perHour[i]}</em>` : ''}</b><span>${String(h).padStart(2, '0')}:00</span></div>`).join('')}</div>
        ${!online && scheduled.some((s) => s.status !== 'closed') ? `<p class="bad small">Nothing is coming in while ${scheduled.length} session${scheduled.length === 1 ? ' is' : 's are'} scheduled here today.</p>` : ''}</section>
    </div>
    <section class="card"><div class="card-head"><h3>Latest taps at this reader</h3></div>
      ${att.length ? `<div class="table-wrap"><table class="table"><thead><tr><th>Time</th><th>Student</th><th>Direction</th><th>Result</th></tr></thead><tbody>${att.slice(-12).reverse().map((a) => `<tr><td><b>${esc(D.ago(a.ts))}</b></td><td>${esc(D.student(a.student_id)?.name || a.tag)}</td><td>${esc(a.direction)}</td><td>${a.ok ? pill('Recorded', 'green') : pill(a.message || 'Rejected', 'pink')}</td></tr>`).join('')}</tbody></table></div>` : empty('No taps yet', 'Tap a cuff at this reader to test it.')}</section>`;
}

// ================= Rooms =================
function rooms({ q, ui }) {
  const buildings = [...new Set(T.rooms.map((r) => r.building || 'Other'))];
  const f = q.b || 'all';
  const list = T.rooms.filter((r) => f === 'all' || (r.building || 'Other') === f);
  const sel = D.room(ui.form.roomSel) || list[0];
  const weekStart = D.mondayOf(new Date()), weekEnd = new Date(+weekStart + 7 * 864e5);
  const stat = (r) => { const rd = T.readers.filter((x) => x.room_id === r.id); return !rd.length ? pill('No reader', 'yellow') : rd.some(D.readerOnline) ? pill('Ready', 'green') : pill('Reader offline', 'pink'); };
  const perWeek = (r) => T.sessions.filter((s) => s.room === r.id && s.starts_at && new Date(s.starts_at) >= weekStart && new Date(s.starts_at) < weekEnd).length;
  return `${head('Rooms', `${T.rooms.length} teaching rooms · ${T.readers.length} readers`, btn('Add room', 'openModal', { icon: 'plus', data: { 'data-m': 'room' } }))}
    <div class="row gap wrap chips">${[['all', `All ${T.rooms.length}`], ...buildings.map((b) => [b, `${b} ${T.rooms.filter((r) => (r.building || 'Other') === b).length}`])].map(([k, l]) => `<a class="chip ${f === k ? 'active' : ''}" href="#/rooms${k === 'all' ? '' : `?b=${encodeURIComponent(k)}`}">${esc(l)}</a>`).join('')}</div>
    <div class="grid side-grid">
      <section class="card">${list.length ? `<div class="table-wrap"><table class="table"><thead><tr><th>Room</th><th>Building</th><th>Seats</th><th>Readers</th><th>Sessions / week</th><th>Status</th></tr></thead><tbody>
        ${list.map((r) => `<tr class="clickable ${sel?.id === r.id ? 'selected' : ''}" data-act="selRoom" data-id="${esc(r.id)}" tabindex="0"><td><b>${esc(r.name)}</b></td><td>${esc(r.building || '—')}</td><td>${esc(r.seats ?? '—')}</td><td>${esc(T.readers.filter((x) => x.room_id === r.id).map((x) => x.id).join(', ') || '—')}</td><td>${perWeek(r)}</td><td>${stat(r)}</td></tr>`).join('')}</tbody></table></div>` : empty('No rooms')}</section>
      <aside class="card">${sel ? `<p class="muted small">Selected room</p><h2>${esc(sel.name)} · ${esc(sel.building || '')}</h2>
        <dl class="facts"><dt>Seats</dt><dd>${esc(sel.seats ?? '—')}</dd><dt>Readers</dt><dd>${esc(T.readers.filter((x) => x.room_id === sel.id).map((x) => `${x.id}${x.door ? ` (${x.door})` : ''}`).join(', ') || 'None: students cannot tap in here')}</dd><dt>Access</dt><dd>${esc(sel.access || '—')}</dd><dt>Used by</dt><dd>${esc([...new Set(T.sessions.filter((s) => s.room === sel.id).map((s) => s.module))].join(', ') || '—')}</dd></dl>
        ${btn('Edit room', 'openModal', { kind: 'secondary', data: { 'data-m': 'room', 'data-id': sel.id } })}` : empty('Pick a room')}</aside>
    </div>`;
}

// ================= Courses =================
function courses() {
  const lecturers = T.staff.filter((s) => s.role === 'lecturer');
  return `${head('Courses', `${T.courses.length} courses · ${T.students.length} students enrolled`, btn('Add course', 'openModal', { icon: 'plus', data: { 'data-m': 'course' } }))}
    <section class="card">${T.courses.length ? `<div class="table-wrap"><table class="table"><thead><tr><th>Course</th><th>Title</th><th>Lecturer</th><th>Students</th><th>Sessions held</th><th>Attendance</th><th></th></tr></thead><tbody>
      ${T.courses.map((c) => { const cs = D.courseStats(c.code); const flag = !c.lecturer_id ? pill('No lecturer', 'pink') : cs.pct != null && cs.pct < D.TARGET ? pill('Below 75%', 'yellow') : ''; return `<tr><td><b>${esc(c.code)}</b></td><td>${esc(c.title)}</td><td><select data-change="setLecturer" data-code="${esc(c.code)}" aria-label="Lecturer for ${esc(c.code)}"><option value="">—</option>${lecturers.map((l) => `<option value="${esc(l.id)}" ${l.id === c.lecturer_id ? 'selected' : ''}>${esc(l.name)}</option>`).join('')}</select></td><td>${D.enrolled(c.code).length}</td><td>${cs.held.length}</td><td><b>${D.pct(cs.pct)}</b></td><td class="right">${flag}</td></tr>`; }).join('')}</tbody></table></div>` : empty('No courses yet')}</section>`;
}

// ================= Campus reports =================
function reportsPage() {
  const modules = T.courses.map((c) => c.code);
  const closed = T.sessions.filter((s) => s.status === 'closed');
  const campus = attendanceOf(closed);
  const below = new Set(T.courses.flatMap((c) => D.courseStats(c.code).below.map((b) => b.st.id))).size;
  const tq = D.tapQuality(closed);
  const regs = closed.map(D.register);
  const inc = regs.reduce((a, r) => a + r.counts.in, 0), man = regs.reduce((a, r) => a + r.counts.manual, 0);
  const lowest = T.courses.map((c) => ({ c, p: D.courseStats(c.code).pct })).filter((x) => x.p != null).sort((a, b) => a.p - b.p).slice(0, 5);
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'], slots = [8, 10, 12, 14, 16];
  const heat = days.map((_, di) => slots.map((h) => T.attendance_events.filter((e) => { const d = new Date(e.ts); return (d.getDay() + 6) % 7 === di && d.getHours() >= h && d.getHours() < h + 2; }).length));
  const maxHeat = Math.max(1, ...heat.flat());
  const shade = (n) => ['#EEF2F8', '#D7E3F2', '#A9C1E0', '#5F86B8', '#0B2545'][n ? Math.min(4, 1 + Math.floor((n / maxHeat) * 3.99)) : 0];
  return `${head('Campus reports', `All courses · ${closed.length} closed session${closed.length === 1 ? '' : 's'}`, btn('Export CSV', 'exportCampus', { icon: 'download' }))}
    <div class="kpis four">${kpi('Campus attendance', D.pct(campus), 'green')}${kpi('Students below 75%', below, 'pink')}${kpi('Taps read first time', D.pct(tq.firstTime, 1), 'cyan')}${kpi('Marked by hand', inc ? D.pct(man / inc, 1) : '—', 'lav')}</div>
    <section class="card"><div class="card-head"><h3>Attendance per week, campus</h3><span class="bad small">target 75%</span></div>${D.weeklySeries(modules).length ? bars(D.weeklySeries(modules), { target: D.TARGET, label: false }) : empty('No closed sessions yet')}</section>
    <div class="grid two-col">
      <section class="card"><div class="card-head"><h3>Lowest courses</h3></div>${lowest.length ? `<ul class="meters">${lowest.map(({ c, p }) => `<li><span>${esc(c.code)}</span><div class="meter"><i class="gold" style="width:${p * 100}%"></i></div><b class="${p < D.TARGET ? 'bad' : ''}">${D.pct(p)}</b></li>`).join('')}</ul>` : empty('No data yet')}</section>
      <section class="card"><div class="card-head"><h3>Busiest times</h3><span class="muted small">taps per weekday and time</span></div>
        <div class="heat"><span></span>${slots.map((h) => `<span class="muted small">${String(h).padStart(2, '0')}:00</span>`).join('')}${days.map((d, di) => `<span class="muted small">${d}</span>${heat[di].map((n) => `<i style="background:${shade(n)}" title="${n} taps"></i>`).join('')}`).join('')}</div></section>
    </div>`;
}

// ================= Roles & access =================
// lecturers: the courses they teach; assistants: chips to pick the courses they help with
function staffCourses(s) {
  if (s.role === 'admin') return '<span class="muted">All</span>';
  if (s.role === 'lecturer') { const own = T.courses.filter((c) => c.lecturer_id === s.id).map((c) => c.code); return own.length ? esc(own.join(', ')) : '<span class="muted">None yet · assign on Courses</span>'; }
  const mine = s.settings?.courses || [];
  return `<div class="row gap wrap">${T.courses.map((c) => chip(c.code, 'toggleAsstCourse', mine.includes(c.code), { 'data-id': s.id, 'data-code': c.code })).join('')}</div>`;
}

function roles({ q }) {
  const f = q.r || 'all';
  const list = T.staff.filter((s) => f === 'all' || s.role === f);
  const count = (r) => T.staff.filter((s) => s.role === r).length;
  return `${head('Roles & access', 'Who can use Kinecto Attendance · NUST email only', btn('Add person', 'openModal', { icon: 'plus', data: { 'data-m': 'person' } }))}
    <div class="row gap wrap chips">${[['all', `All ${T.staff.length}`], ['admin', `Admins ${count('admin')}`], ['lecturer', `Lecturers ${count('lecturer')}`], ['assistant', `Assistants ${count('assistant')}`]].map(([k, l]) => `<a class="chip ${f === k ? 'active' : ''}" href="#/roles${k === 'all' ? '' : `?r=${k}`}">${esc(l)}</a>`).join('')}</div>
    <div class="grid side-grid">
      <section class="card"><div class="table-wrap"><table class="table"><thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Courses</th><th>Last sign-in</th></tr></thead><tbody>
        ${list.map((s) => `<tr><td><div class="who">${avatar(D.initials(s.name), s.role === 'admin' ? 'yellow' : 'cyan', 'sm')}<b>${esc(s.name)}</b></div></td><td class="muted">${esc(s.email)}</td><td><select data-change="setRole" data-id="${esc(s.id)}" aria-label="Role for ${esc(s.name)}">${['lecturer', 'assistant', 'admin'].map((r) => `<option value="${r}" ${r === s.role ? 'selected' : ''}>${cap(r)}</option>`).join('')}</select></td><td>${staffCourses(s)}</td><td class="muted">${esc(s.last_sign_in ? D.ago(s.last_sign_in) : 'never')}</td></tr>`).join('')}</tbody></table></div></section>
      <aside class="card"><div class="card-head"><h3>What each role can do</h3></div>
        <div class="role-cards"><div class="yellow"><b>Admin</b><span>All rooms, readers, courses, reports, roles and the audit log</span></div><div class="cyan"><b>Lecturer</b><span>Own courses: sessions, register, mark by hand, reports</span></div><div class="lav"><b>Assistant</b><span>Open and close sessions for a course; cannot mark by hand</span></div><div class="green"><b>Wearer</b><span>Phone app only: sees own taps</span></div></div>
        <p class="muted small">Lecturer roles come from the NUST timetable. Admins are added here by hand, and every change is in the audit log.</p></aside>
    </div>`;
}

// ================= Audit log =================
const AUDIT_GROUPS = { all: () => true, marks: (a) => /Marked by hand|Undo/.test(a.action), roles: (a) => /Role|Person/.test(a.action), readers: (a) => /Reader/.test(a.action), sessions: (a) => /Session/.test(a.action), exports: (a) => /Export|Reminder|Summary|Referral/.test(a.action) };
const auditTone = (a) => (/Marked/.test(a.action) ? 'lav' : /opened|set up/.test(a.action) ? 'green' : /closed/.test(a.action) ? 'grey' : /Role|Person/.test(a.action) ? 'yellow' : /Reader/.test(a.action) ? 'cyan' : /offline|Notify/.test(a.action) ? 'pink' : 'grey');
function audit({ q }) {
  const g = q.g || 'all';
  const list = T.audit_log.filter(AUDIT_GROUPS[g] || AUDIT_GROUPS.all).slice().reverse();
  return `${head('Audit log', 'Every manual change, kept for the semester · read only', btn('Export CSV', 'exportAudit', { icon: 'download', data: { 'data-g': g } }))}
    <div class="row gap wrap chips">${[['all', 'All'], ['marks', 'Marked by hand'], ['roles', 'Role changes'], ['readers', 'Readers'], ['sessions', 'Sessions'], ['exports', 'Exports & messages']].map(([k, l]) => `<a class="chip ${g === k ? 'active' : ''}" href="#/audit${k === 'all' ? '' : `?g=${k}`}">${esc(l)}</a>`).join('')}</div>
    <section class="card">${list.length ? `<div class="table-wrap"><table class="table"><thead><tr><th>When</th><th>Who</th><th>What</th><th>Details</th></tr></thead><tbody>${list.slice(0, 200).map((a) => `<tr><td><b>${esc(D.dayLabel(a.at))} ${D.hhmm(a.at)}</b></td><td>${esc(a.actor)}</td><td>${pill(a.action, auditTone(a))}</td><td class="muted">${esc(a.detail || '')}</td></tr>`).join('')}</tbody></table></div>` : empty('Nothing here yet')}</section>`;
}

// ================= modals =================
function modal({ ui }) {
  const f = ui.form, m = ui.modal;
  const headM = (t, s) => `<div class="modal-head"><div><h2>${esc(t)}</h2>${s ? `<p class="muted">${esc(s)}</p>` : ''}</div><button type="button" class="icon-btn" data-act="closeModalBtn" aria-label="Close">${icon('close')}</button></div>`;
  const err = f.m_error ? `<p class="note pink">${esc(f.m_error)}</p>` : '';
  const actions = (label) => `<div class="row gap"><button class="btn primary" type="submit">${esc(label)}</button><button class="btn secondary" type="button" data-act="closeModalBtn">Cancel</button></div>`;
  if (m?.type === 'reader') {
    if (m.step === 'test') {
      const r = D.reader(m.id);
      const got = T.tap_attempts.filter((a) => a.reader_id === m.id && new Date(a.ts) > new Date(m.since));
      return `${headM('Test the reader', `${m.id} · ${D.room(r?.room_id)?.name || ''}`)}
        <ol class="steps"><li class="done"><b>Pick the room</b></li><li class="done"><b>Reader added</b></li><li class="${got.length ? 'done' : 'now'}"><b>Test it</b><span>Tap a staff or student cuff at the reader. A green light = ready.</span></li></ol>
        ${got.length ? `<p class="note green">First tap received ${D.ago(got.at(-1).ts)}: "${esc(got.at(-1).message)}". The reader works.</p>` : `<p class="note cyan">Waiting for the first tap at ${esc(m.id)}… This updates by itself.</p><p class="muted small">A real reader needs its device key set up by ICT (see docs/live-sync-setup.md, step 3).</p>`}
        <div class="row gap">${btn(got.length ? 'Done' : 'Close', 'closeModalBtn')}</div>`;
    }
    return `<form data-form="saveReader">${headM('Add a reader', 'Three steps. The reader starts working as soon as ICT gives it its device key.')}
      <ol class="steps"><li class="now"><b>Pick the room</b></li><li><b>Name the reader</b></li><li><b>Test it</b></li></ol>
      <div class="form-grid two">${field('Room', select('m_room', f.m_room || T.rooms[0]?.id, T.rooms.map((r) => [r.id, `${r.name} · ${r.building || ''}`])))}
      ${field('Reader id', input('m_id', f.m_id || '', { placeholder: 'e.g. E310-A', required: true, pattern: '[A-Za-z0-9\\-]+' }))}
      ${field('Door', input('m_door', f.m_door || '', { placeholder: 'e.g. Front door' }))}
      ${field('Firmware', input('m_fw', f.m_fw || '2.1.0'))}</div>${err}${actions('Continue')}</form>`;
  }
  if (m?.type === 'room') {
    const r = m.id ? D.room(m.id) : null;
    return `<form data-form="saveRoom">${headM(r ? `Edit ${r.name}` : 'Add a room')}
      <div class="form-grid two">${field('Room id', input('m_rid', f.m_rid ?? r?.id ?? '', { required: true, readonly: r ? true : null, placeholder: 'e.g. E310' }))}
      ${field('Building', input('m_building', f.m_building ?? r?.building ?? '', { placeholder: 'e.g. Engineering' }))}
      ${field('Seats', input('m_seats', f.m_seats ?? r?.seats ?? '', { type: 'number', min: 1 }))}
      ${field('Access', input('m_access', f.m_access ?? r?.access ?? '', { placeholder: 'e.g. Ramp at side door' }))}</div>${err}${actions(r ? 'Save room' : 'Add room')}</form>`;
  }
  if (m?.type === 'course') {
    return `<form data-form="saveCourseNew">${headM('Add a course')}
      <div class="form-grid two">${field('Course code', input('m_code', f.m_code || '', { required: true, placeholder: 'e.g. CSI521S' }))}
      ${field('Title', input('m_title', f.m_title || '', { required: true }))}
      ${field('Faculty', input('m_faculty', f.m_faculty || 'Computing & Informatics'))}
      ${field('Lecturer', select('m_lec', f.m_lec || '', [['', '—'], ...T.staff.filter((s) => s.role === 'lecturer').map((s) => [s.id, s.name])]))}</div>${err}${actions('Add course')}</form>`;
  }
  if (m?.type === 'person') {
    return `<form data-form="savePerson">${headM('Add a person', 'They sign in with this NUST email')}
      <div class="form-grid two">${field('Name', input('m_name', f.m_name || '', { required: true }))}
      ${field('NUST email', input('m_email', f.m_email || '', { type: 'email', required: true, placeholder: 'name@nust.na' }))}
      ${field('Role', select('m_role', f.m_role || 'lecturer', [['lecturer', 'Lecturer'], ['assistant', 'Assistant'], ['admin', 'Admin']]))}</div>${err}${actions('Add person')}</form>`;
  }
  return '';
}

const clearModal = (ui) => { ui.modal = null; for (const k of Object.keys(ui.form)) if (k.startsWith('m_')) delete ui.form[k]; };

const acts = {
  openModal(el, ev, { ui, render }) { clearModal(ui); ui.modal = { type: el.dataset.m, id: el.dataset.id }; render(); },
  closeModalBtn(el, ev, { ui, render }) { clearModal(ui); render(); },
  async saveReader(el, ev, { me, ui, render }) {
    const id = String(ui.form.m_id || '').trim().toUpperCase();
    if (!/^[A-Z0-9-]{2,20}$/.test(id)) { ui.form.m_error = 'Use letters, numbers and dashes, e.g. E310-A.'; return render(); }
    if (D.reader(id)) { ui.form.m_error = `Reader ${id} already exists.`; return render(); }
    await api.addReader({ id, room_id: ui.form.m_room || T.rooms[0]?.id, door: ui.form.m_door || null, firmware: ui.form.m_fw || '2.1.0', added_by: me.name });
    ui.modal = { type: 'reader', step: 'test', id, since: new Date().toISOString() };
    render();
  },
  async saveRoom(el, ev, { me, ui, render }) {
    const editing = ui.modal?.id;
    const id = editing || String(ui.form.m_rid || '').trim();
    if (!id) { ui.form.m_error = 'Give the room an id.'; return render(); }
    const row = { name: id, building: ui.form.m_building ?? D.room(id)?.building ?? null, seats: ui.form.m_seats ? Number(ui.form.m_seats) : D.room(id)?.seats ?? null, access: ui.form.m_access ?? D.room(id)?.access ?? null };
    if (editing) await api.saveRoom(id, row); else { if (D.room(id)) { ui.form.m_error = `${id} already exists.`; return render(); } await api.addRoom({ id, ...row }); }
    await api.audit(me.name, editing ? 'Room edited' : 'Room added', `${id} · ${row.building || ''}`);
    clearModal(ui); toast(editing ? 'Room saved' : 'Room added'); render();
  },
  async saveCourseNew(el, ev, { me, ui, render }) {
    const code = String(ui.form.m_code || '').trim().toUpperCase();
    if (!/^[A-Z]{3}\d{3}[A-Z]$/.test(code)) { ui.form.m_error = 'NUST course codes look like CSI521S.'; return render(); }
    if (D.course(code)) { ui.form.m_error = `${code} already exists.`; return render(); }
    await api.addCourse({ code, title: ui.form.m_title, faculty: ui.form.m_faculty || null, lecturer_id: ui.form.m_lec || null });
    await api.audit(me.name, 'Course added', `${code} · ${ui.form.m_title}`);
    clearModal(ui); toast('Course added'); render();
  },
  async savePerson(el, ev, { me, ui, render }) {
    const email = String(ui.form.m_email || '').trim().toLowerCase();
    if (!/^[^@\s]+@(nust\.na|students\.nust\.na)$/.test(email)) { ui.form.m_error = 'Only NUST emails can use the desk.'; return render(); }
    if (T.staff.some((s) => s.email.toLowerCase() === email)) { ui.form.m_error = 'This email already has a role.'; return render(); }
    await api.addStaff({ id: 'ST-' + Date.now().toString(36).toUpperCase(), name: ui.form.m_name, email, role: ui.form.m_role || 'lecturer', changed_by: me.name });
    clearModal(ui); toast('Person added'); render();
  },
  async toggleAsstCourse(el, ev, { me }) {
    const s = D.staffById(el.dataset.id); const code = el.dataset.code;
    const cur = s.settings?.courses || [];
    const next = cur.includes(code) ? cur.filter((c) => c !== code) : [...cur, code];
    await api.saveStaff(s.id, { settings: { ...(s.settings || {}), courses: next }, changed_by: me.name });
    await api.audit(me.name, 'Role changed', `${s.name} assists ${next.join(', ') || 'no courses'}`);
  },
  async setRole(el, ev, { me }) {
    if (el.dataset.id === me.id && el.value !== 'admin') { el.value = 'admin'; throw new Error('You cannot remove your own admin role.'); }
    await api.saveStaff(el.dataset.id, { role: el.value, changed_by: me.name });
    toast('Role changed');
  },
  async setLecturer(el, ev, { me }) {
    await api.saveCourse(el.dataset.code, { lecturer_id: el.value || null });
    await api.audit(me.name, 'Lecturer assigned', `${el.dataset.code} → ${D.staffById(el.value)?.name || 'nobody'}`);
    toast('Lecturer saved');
  },
  selRoom(el, ev, { ui, render }) { ui.form.roomSel = el.dataset.id; render(); },
  async notifyIct(el, ev, { me }) { await api.audit(me.name, 'Notify ICT', `Reader ${el.dataset.id} is offline`); toast('ICT notification logged in the audit log'); },
  exportWeek(el, ev, { me }) {
    const mon = D.mondayOf(new Date()), end = new Date(+mon + 7 * 864e5);
    const rows = T.sessions.filter((s) => s.starts_at && new Date(s.starts_at) >= mon && new Date(s.starts_at) < end).map((s) => { const c = D.register(s).counts; return [D.dayLabel(s.starts_at), D.hhmm(s.starts_at), s.module, s.type, s.room, s.status, c.in, c.total]; });
    downloadCsv('campus-week.csv', [['Day', 'Start', 'Course', 'Type', 'Room', 'Status', 'Checked in', 'Enrolled'], ...rows]);
    api.audit(me.name, 'Export', 'Campus week · CSV').catch(() => {});
  },
  exportCampus(el, ev, { me }) {
    const rows = T.courses.map((c) => { const cs = D.courseStats(c.code); return [c.code, c.title, D.staffById(c.lecturer_id)?.name || '', D.enrolled(c.code).length, cs.held.length, cs.pct == null ? '' : Math.round(cs.pct * 100) + '%', cs.below.length]; });
    downloadCsv('campus-report.csv', [['Course', 'Title', 'Lecturer', 'Students', 'Sessions held', 'Attendance', 'Below 75%'], ...rows]);
    api.audit(me.name, 'Export', 'Campus report · CSV').catch(() => {});
  },
  exportAudit(el, ev, { me }) {
    const list = T.audit_log.filter(AUDIT_GROUPS[el.dataset.g] || AUDIT_GROUPS.all);
    downloadCsv('audit-log.csv', [['When', 'Who', 'What', 'Details'], ...list.map((a) => [new Date(a.at).toISOString(), a.actor, a.action, a.detail || ''])]);
    api.audit(me.name, 'Export', 'Audit log · CSV').catch(() => {});
  },
};

export const adminPages = {
  overview: { render: overview, acts },
  readers: { render: readers, acts, modal },
  reader: { render: readerDetail, acts, hidden: true },
  rooms: { render: rooms, acts, modal },
  courses: { render: courses, acts, modal },
  reports: { render: reportsPage, acts },
  roles: { render: roles, acts, modal },
  audit: { render: audit, acts },
};
