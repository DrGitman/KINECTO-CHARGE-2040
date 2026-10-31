// Lecturer (and assistant) screens: Figma 08b (Today, Register, Reports) and 08c (Sessions, New session,
// Session closed, Student detail, Settings).
import { T, api } from './store.js';
import { esc, pill, dotPill, btn, chip, kpi, avatar, empty, toggle, field, input, select, icon, toast, downloadCsv, bars } from './ui.js';
import * as D from './derive.js';

const head = (title, sub, actions = '', crumbs = '') => `<header class="page-head">${crumbs ? `<p class="crumbs">${crumbs}</p>` : ''}<div><h1>${esc(title)}</h1>${sub ? `<p class="muted">${esc(sub)}</p>` : ''}</div><div class="actions">${actions}</div></header>`;
const canMark = (me) => me.role !== 'assistant';
const settingsOf = (me) => ({ late: 10, openBefore: 5, autoClose: true, tapPopups: true, readerOffline: true, absences3: true, dailySummary: false, autoOpened: false, markedByOther: true, ...(me.settings || {}) });
const sessionLine = (s) => `${s.type || 'Session'} · Room ${s.room || '—'} · ${D.hhmm(s.starts_at)} – ${D.hhmm(s.ends_at)}`;
const courseName = (code) => D.course(code)?.title || code;

function readerPill(s) {
  const r = D.reader(s.reader_id);
  const st = D.readerState(r);
  return st === 'online' ? dotPill(`reader ${s.reader_id} online`, 'green') : st === 'offline' ? dotPill(`reader ${s.reader_id} offline`, 'pink', 'red') : dotPill('no reader in this room', 'yellow', 'gold');
}

function statePill(s) {
  const st = D.sessionState(s);
  return { live: pill('Live', 'green'), closed: pill('Closed', 'grey'), soon: pill(`Opens ${D.hhmm(new Date(new Date(s.starts_at) - (s.open_before_min ?? 5) * 60000))}`, 'cyan'), planned: pill('Planned', 'lav'), missed: pill('Not opened', 'pink') }[st];
}

const regRow = (r) => [r.student.name, r.student.id, r.tin ? D.hhmm(r.tin.ts) : '', r.tout ? D.hhmm(r.tout.ts) : '', D.STATE_LABEL[r.state], r.mark ? r.mark.reason : ''];
function exportRegister(s, me) {
  const reg = D.register(s);
  downloadCsv(`${s.id}.csv`, [['Student', 'Student no.', 'Tap in', 'Tap out', 'Status', 'Reason'], ...reg.rows.map(regRow)]);
  api.audit(me.name, 'Export', `${s.module} ${s.type || ''} · ${D.dayLabel(s.starts_at)} · CSV`).catch(() => {});
}

// rows that appeared since this page was last drawn get a short highlight
function fresh(ui, key) {
  if (ui.seen.has(key)) return '';
  ui.seen.add(key);
  return ui.seenReady ? 'new' : '';
}

// ================= Today =================
function today({ me, ui }) {
  const mine = D.sessionsOf(me);
  const todays = mine.filter((s) => s.starts_at && D.dayKey(s.starts_at) === D.today()).sort((a, b) => new Date(a.starts_at) - new Date(b.starts_at));
  const live = mine.filter((s) => s.status === 'open').sort((a, b) => (D.dayKey(b.starts_at) === D.today()) - (D.dayKey(a.starts_at) === D.today()))[0];
  const next = todays.find((s) => s.status === 'scheduled' && new Date(s.ends_at) > Date.now());
  const term = String(ui.form.todaySearch || '').trim().toLowerCase();
  const myStudents = [...new Map(D.coursesOf(me).flatMap((c) => D.enrolled(c.code)).map((s) => [s.id, s])).values()];
  const hits = term ? myStudents.filter((s) => s.name.toLowerCase().includes(term) || s.id.toLowerCase().includes(term)).slice(0, 6) : [];

  const search = `<div class="search">${icon('search')}<input data-bind="todaySearch" data-live placeholder="Search student number or name" value="${esc(ui.form.todaySearch || '')}" aria-label="Search students">
    ${term ? `<div class="search-results">${hits.length ? hits.map((s) => `<a href="#/student?id=${esc(s.id)}">${avatar(D.initials(s.name), 'cyan', 'sm')}<span><b>${esc(s.name)}</b><small>${esc(s.id)}</small></span></a>`).join('') : '<p class="muted">No student found</p>'}</div>` : ''}</div>`;
  const openBtn = next ? btn('Open session', 'openSession', { data: { 'data-id': next.id } }) : btn('New session', 'newSession', { icon: 'plus' });

  let liveCard;
  if (live) {
    const reg = D.register(live), c = reg.counts;
    const frac = c.total ? c.in / c.total : 0;
    liveCard = `<section class="card live-card">
      ${readerPill(live)}
      <h2>${esc(live.module)} · ${esc(courseName(live.module))}</h2>
      <p class="muted">${esc(sessionLine(live))} · opened ${esc(D.hhmm(live.opened_at))}</p>
      <div class="big-count"><strong data-num="live-in">${c.in}</strong><span>/ ${c.total} checked in</span></div>
      <div class="progress"><i style="width:${(frac * 100).toFixed(1)}%"></i></div>
      <div class="kpis four">
        ${kpi('On time', c.present, 'green', 'live-present')}${kpi(`Late (after ${D.hhmm(D.lateCutoff(live))})`, c.late, 'yellow', 'live-late')}
        ${kpi('Not yet', c.notyet, 'pink', 'live-notyet')}${kpi('Fixed by hand', c.manual, 'lav', 'live-manual')}
      </div>
      <div class="row gap wrap">
        ${btn('Close session', 'closeSession', { kind: 'dark', data: { 'data-id': live.id } })}
        ${canMark(me) ? `<a class="btn secondary" href="#/register?s=${esc(live.id)}&mark=1">Mark present by hand</a>` : ''}
        <span class="muted small">Taps after close are rejected · late window ${live.late_after_min ?? 10} min</span>
      </div>
    </section>`;
  } else {
    liveCard = `<section class="card live-card idle">
      ${pill('No session open', 'grey')}
      ${next ? `<h2>Next: ${esc(next.module)} · ${esc(courseName(next.module))}</h2>
        <p class="muted">${esc(sessionLine(next))}</p>
        <div class="row gap wrap">${readerPill(next)}<span class="muted small">${next.auto_open ? `Opens by itself at ${D.hhmm(new Date(new Date(next.starts_at) - (next.open_before_min ?? 5) * 60000))}` : 'Opens only by hand'}</span></div>
        <div class="row gap">${btn('Open session now', 'openSession', { data: { 'data-id': next.id } })}<a class="btn secondary" href="#/register?s=${esc(next.id)}">View register</a></div>`
      : `<h2>No more sessions today</h2><p class="muted">Plan one on the Sessions page, or open a past session from its register.</p><div class="row gap">${btn('New session', 'newSession', { icon: 'plus' })}<a class="btn secondary" href="#/sessions">See the week</a></div>`}
    </section>`;
  }

  // live feed: accepted taps of the live session plus rejected taps at its door
  let feed = '';
  if (live) {
    const evs = T.attendance_events.filter((e) => e.session_id === live.id).map((e) => ({ kind: 'event', ts: e.ts, e }));
    const rej = T.tap_attempts.filter((a) => !a.ok && a.reader_id === live.reader_id && new Date(a.ts) >= new Date(live.opened_at || live.starts_at)).map((a) => ({ kind: 'rej', ts: a.ts, a }));
    const items = [...evs, ...rej].sort((a, b) => new Date(b.ts) - new Date(a.ts)).slice(0, 8);
    const cutoff = D.lateCutoff(live);
    feed = items.length ? items.map((it) => {
      if (it.kind === 'rej') {
        const st = D.student(it.a.student_id);
        return `<li class="${fresh(ui, 'a' + it.a.id)}"><time>${D.hhmm(it.ts)}</time><div><b>${esc(st?.name || it.a.tag)}</b><small>${esc(it.a.message || 'Rejected')}</small></div>${pill('Rejected', 'pink')}</li>`;
      }
      const st = D.student(it.e.student_id);
      const late = it.e.direction === 'IN' && cutoff && new Date(it.e.ts) > cutoff;
      return `<li class="${fresh(ui, 'e' + it.e.id)}"><time>${D.hhmm(it.ts)}</time><div><b>${esc(st?.name || it.e.student_id)}</b><small>${esc(it.e.student_id)} · ${esc(it.e.source || '')}</small></div>${it.e.direction === 'OUT' ? pill('Out', 'grey') : late ? pill('Late', 'yellow') : pill('In', 'green')}</li>`;
    }).join('') : `<li class="muted feed-empty">Waiting for the first tap at ${esc(live.reader_id)}…</li>`;
  }
  ui.seenReady = true;

  const table = todays.length ? `<div class="table-wrap"><table class="table">
      <thead><tr><th>Time</th><th>Course</th><th>Type</th><th>Room · reader</th><th>Checked in</th><th>Status</th><th></th></tr></thead>
      <tbody>${todays.map((s) => {
        const c = D.register(s).counts, st = D.sessionState(s);
        const action = st === 'closed' ? `<a class="btn secondary sm" href="#/summary?s=${esc(s.id)}">View summary</a>`
          : st === 'live' ? `<a class="btn secondary sm" href="#/register?s=${esc(s.id)}">Open register</a>`
          : st === 'missed' ? `<a class="btn secondary sm" href="#/register?s=${esc(s.id)}">View register</a>`
          : btn('Open', 'openSession', { kind: 'secondary', size: 'sm', data: { 'data-id': s.id } });
        return `<tr class="${st === 'live' ? 'hl' : ''}"><td><b>${D.hhmm(s.starts_at)}</b></td><td>${esc(s.module)} ${esc(courseName(s.module))}</td><td class="muted">${esc(s.type || '')}</td><td>${esc(s.room || '—')} · ${esc(s.reader_id || '—')}</td><td><b>${st === 'planned' || st === 'soon' ? '—' : c.in} / ${c.total}</b></td><td>${statePill(s)}</td><td class="right">${action}</td></tr>`;
      }).join('')}</tbody></table></div>`
    : empty('No sessions today', 'Your timetable has nothing on today.', `<a class="btn secondary sm" href="#/sessions">Open the week</a>`);

  return `${head('Today', `${D.longDay(new Date())} · ${todays.length} session${todays.length === 1 ? '' : 's'}`, `${search}${openBtn}`)}
    <div class="grid today-grid">
      ${liveCard}
      <section class="card feed-card"><div class="card-head"><h3>Live taps</h3><span class="muted small">newest first</span></div>
        ${live ? `<ul class="feed">${feed}</ul>` : empty('No live session', 'Taps show here as soon as a session is open.')}</section>
    </div>
    <section class="card"><div class="card-head"><h3>Today's sessions</h3></div>${table}
      <p class="note grey">The jacket cuff only sends a tag ID and time. The desk matches it to the NUST class list, so you see student numbers; no location is ever stored.</p></section>`;
}

// ================= Sessions (week) =================
function sessions({ me, q }) {
  const w = Number(q.w || 0);
  const mon = D.mondayOf(new Date()); mon.setDate(mon.getDate() + w * 7);
  const days = Array.from({ length: 5 }, (_, i) => { const d = new Date(mon); d.setDate(d.getDate() + i); return d; });
  const mine = D.sessionsOf(me).filter((s) => s.starts_at);
  const weekS = mine.filter((s) => { const t = new Date(s.starts_at); const end = new Date(mon); end.setDate(end.getDate() + 7); return t >= mon && t < end; });
  const slots = [8, 10, 12, 14, 16];
  const slotOf = (s) => { const h = new Date(s.starts_at).getHours(); return Math.max(0, Math.min(slots.length - 1, Math.floor((h - 8) / 2))); };
  const tone = { live: 'yellow', closed: 'green', soon: 'cyan', planned: 'lav', missed: 'pink' };
  const label = { live: 'Live', closed: 'Closed', soon: 'Opens soon', planned: 'Planned', missed: 'Not opened' };
  const block = (s) => {
    const st = D.sessionState(s), c = D.register(s).counts;
    const href = st === 'closed' ? `#/summary?s=${s.id}` : `#/register?s=${s.id}`;
    return `<a class="ev ${tone[st]}" href="${esc(href)}"><b>${esc(s.module)} ${esc(s.type || '')}</b><small>${esc(s.room || '')}${st === 'closed' || st === 'live' ? ` · ${c.in}/${c.total}` : ` · ${D.hhmm(s.starts_at)}`}</small>${pill(label[st], 'white')}</a>`;
  };
  const range = `${days[0].toLocaleDateString('en-GB', { day: 'numeric', month: 'long' })}`;
  return `${head('Sessions', `Week of ${range} · ${weekS.length} session${weekS.length === 1 ? '' : 's'} · ${D.coursesOf(me).length} courses`,
      `<a class="btn secondary sm" href="#/sessions?w=${w - 1}">${icon('arrowL')}<span>Prev week</span></a>${w ? `<a class="btn secondary sm" href="#/sessions">This week</a>` : ''}<a class="btn secondary sm" href="#/sessions?w=${w + 1}"><span>Next week</span>${icon('arrowR')}</a>${btn('New session', 'newSession', { icon: 'plus' })}`)}
    <section class="card week">
      <div class="week-grid" style="--days:${days.length}">
        <div></div>${days.map((d) => `<div class="day ${D.dayKey(d) === D.today() ? 'now' : ''}">${d.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric' })}</div>`).join('')}
        ${slots.map((h, si) => `<div class="hour">${String(h).padStart(2, '0')}:00</div>${days.map((d) => `<div class="cell">${weekS.filter((s) => D.dayKey(s.starts_at) === D.dayKey(d) && slotOf(s) === si).sort((a, b) => new Date(a.starts_at) - new Date(b.starts_at)).map(block).join('')}</div>`).join('')}`).join('')}
      </div>
      <div class="legend">${Object.entries(label).map(([k, l]) => `<span><i class="sw ${tone[k]}"></i>${l}</span>`).join('')}</div>
    </section>`;
}

function newSessionModal({ me, ui }) {
  const f = ui.form, set = settingsOf(me);
  const courses = D.coursesOf(me);
  const code = f.ns_course || courses[0]?.code || '';
  const roomId = f.ns_room || D.usualRoom(code) || set.defaultRoom || T.rooms[0]?.id || '';
  const readers = T.readers.filter((r) => r.room_id === roomId);
  const rd = readers[0];
  const late = Number(f.ns_late || set.late || 10);
  const rep = f.ns_repeat || 'once';
  return `<form data-form="createSession" class="modal-form">
    <div class="modal-head"><div><h2>New session</h2><p class="muted">Students tap in at the door reader of the room you pick</p></div><button type="button" class="icon-btn" data-act="closeModalBtn" aria-label="Close">${icon('close')}</button></div>
    <div class="form-grid two">
      ${field('Course', select('ns_course', code, courses.map((c) => [c.code, `${c.code} · ${c.title}`])))}
      ${field('Type', select('ns_type', f.ns_type || 'Lecture', ['Lecture', 'Tutorial', 'Lab', 'Seminar', 'Exam']))}
      ${field('Room', select('ns_room', roomId, T.rooms.map((r) => [r.id, `${r.name} · ${r.building || ''}`])))}
      ${field('Reader', `<div class="static">${rd ? `${esc(rd.id)} · ${D.readerOnline(rd) ? '<span class="ok">online</span>' : '<span class="bad">offline</span>'}` : '<span class="bad">No reader in this room: students cannot tap in</span>'}</div>`)}
    </div>
    <div class="form-grid three">
      ${field('Date', input('ns_date', f.ns_date || D.today(), { type: 'date', required: true }))}
      ${field('Starts', input('ns_start', f.ns_start || '10:00', { type: 'time', required: true }))}
      ${field('Ends', input('ns_end', f.ns_end || '12:00', { type: 'time', required: true }))}
    </div>
    <div class="field"><span>Late after</span><div class="row gap">${[5, 10, 15].map((m) => chip(`${m} min`, 'setForm', late === m, { 'data-k': 'ns_late', 'data-v': m })).join('')}</div></div>
    <div class="field"><span>Repeat</span><div class="row gap wrap">${[['once', 'Once'], ['weekly', 'Every week · 6 weeks'], ['semester', 'Until end of semester']].map(([k, l]) => chip(l, 'setForm', rep === k, { 'data-k': 'ns_repeat', 'data-v': k })).join('')}</div></div>
    <p class="note cyan">The session opens itself ${set.openBefore} minutes before the start and closes at the end. You can still open or close it by hand.</p>
    ${f.ns_error ? `<p class="note pink">${esc(f.ns_error)}</p>` : ''}
    <div class="row gap"><button class="btn primary" type="submit">Create session</button><button class="btn secondary" type="button" data-act="closeModalBtn">Cancel</button></div>
  </form>`;
}

async function createSession(el, ev, { me, ui, render }) {
  const f = ui.form, set = settingsOf(me);
  const code = f.ns_course || D.coursesOf(me)[0]?.code;
  const roomId = f.ns_room || D.usualRoom(code) || set.defaultRoom || T.rooms[0]?.id;
  const date = f.ns_date || D.today(), start = f.ns_start || '10:00', end = f.ns_end || '12:00';
  const type = f.ns_type || 'Lecture';
  const late = Number(f.ns_late || set.late || 10);
  if (!code) { f.ns_error = 'You have no course to add a session to.'; return render(); }
  if (end <= start) { f.ns_error = 'The session must end after it starts.'; return render(); }
  const rd = T.readers.find((r) => r.room_id === roomId);
  const first = new Date(`${date}T${start}`);
  let count = 1;
  if (f.ns_repeat === 'weekly') count = 6;
  if (f.ns_repeat === 'semester') {
    const last = Math.max(...T.sessions.filter((s) => s.module === code && s.starts_at).map((s) => +new Date(s.starts_at)), +first + 5 * 7 * 864e5);
    count = Math.floor((last - first) / (7 * 864e5)) + 1;
  }
  const rows = [];
  for (let i = 0; i < count; i++) {
    const d = new Date(first); d.setDate(d.getDate() + i * 7);
    const dk = D.dayKey(d);
    const s0 = new Date(`${dk}T${start}`), e0 = new Date(`${dk}T${end}`);
    const clash = T.sessions.find((s) => s.room === roomId && s.starts_at && new Date(s.starts_at) < e0 && new Date(s.ends_at) > s0);
    if (clash) { f.ns_error = `${T.rooms.find((r) => r.id === roomId)?.name || roomId} is already booked on ${D.dayLabel(s0)} (${clash.module} ${clash.type || ''} ${D.hhmm(clash.starts_at)}).`; return render(); }
    rows.push({
      id: `${code}-${type.slice(0, 4).toUpperCase()}-${dk.replace(/-/g, '')}-${start.replace(':', '')}`,
      module: code, title: D.course(code)?.title || code, type, room: roomId, reader_id: rd?.id || null,
      time_label: `${start} – ${end}`, date: dk, starts_at: s0.toISOString(), ends_at: e0.toISOString(),
      late_after_min: late, open_before_min: Number(set.openBefore ?? 5), auto_open: true, status: 'scheduled', changed_by: me.name,
    });
  }
  await api.createSessions(rows);
  ui.modal = null;
  for (const k of Object.keys(f)) if (k.startsWith('ns_')) delete f[k];
  toast(count > 1 ? `${count} sessions created` : 'Session created');
  render();
}

// ================= Register =================
function pickSession(me, q) {
  const mine = D.sessionsOf(me).filter((s) => s.starts_at);
  if (q.s) return D.sessionById(q.s);
  return mine.find((s) => s.status === 'open')
    || mine.filter((s) => new Date(s.starts_at) <= Date.now()).sort((a, b) => new Date(b.starts_at) - new Date(a.starts_at))[0]
    || mine.sort((a, b) => new Date(a.starts_at) - new Date(b.starts_at))[0];
}

function registerPage({ me, q, ui }) {
  const s = pickSession(me, q);
  if (!s) return head('Register', '') + empty('No sessions yet', 'Create a session first.', `<a class="btn primary" href="#/sessions">Go to Sessions</a>`);
  const reg = D.register(s), c = reg.counts;
  const filter = ui.form.regFilter || 'all';
  const term = String(ui.form.regSearch || '').trim().toLowerCase();
  const near = D.sessionsOf(me).filter((x) => x.starts_at && Math.abs(new Date(x.starts_at) - Date.now()) < 8 * 864e5).sort((a, b) => new Date(a.starts_at) - new Date(b.starts_at));
  if (!near.includes(s)) near.unshift(s);
  const rows = reg.rows.filter((r) => (filter === 'all' || r.state === filter) && (!term || r.student.name.toLowerCase().includes(term) || r.student.id.toLowerCase().includes(term)));
  const chips = [['all', `All ${c.total}`], ['present', `Present ${c.present}`], ['late', `Late ${c.late}`], [s.status === 'open' ? 'notyet' : 'absent', s.status === 'open' ? `Not yet ${c.notyet}` : `Absent ${c.absent}`], ['manual', `Fixed by hand ${c.manual}`]];
  const pick = ui.drawer?.student && reg.rows.find((r) => r.student.id === ui.drawer.student);
  const markable = canMark(me) && s.status !== 'scheduled';
  const sel = pick || (q.mark && markable ? reg.rows.find((r) => r.state === 'notyet' || r.state === 'absent') : null);
  if (sel && !ui.drawer) ui.drawer = { student: sel.student.id };

  const table = rows.length ? `<div class="table-wrap"><table class="table register">
    <thead><tr><th>Student</th><th>Student no.</th><th>Tap in</th><th>Tap out</th><th>Status</th></tr></thead>
    <tbody>${rows.map((r) => `<tr class="${sel && sel.student.id === r.student.id ? 'selected' : ''} ${r.state === 'manual' ? 'lav-row' : ''} clickable" data-act="selectStudent" data-id="${esc(r.student.id)}" tabindex="0">
      <td><div class="who">${avatar(D.initials(r.student.name), r.student.id.charCodeAt(r.student.id.length - 1) % 2 ? 'cyan' : 'yellow', 'sm')}<a href="#/student?id=${esc(r.student.id)}&c=${esc(s.module)}" class="strong">${esc(r.student.name)}</a></div></td>
      <td class="muted">${esc(r.student.id)}</td><td><b>${r.tin ? D.hhmm(r.tin.ts) : '—'}</b></td><td><b>${r.tout ? D.hhmm(r.tout.ts) : '—'}</b></td>
      <td>${pill(r.state === 'present' && s.status === 'closed' && !r.tout ? 'Present · no tap out' : D.STATE_LABEL[r.state], D.STATE_TONE[r.state])}</td></tr>`).join('')}</tbody></table></div>`
    : empty('Nobody here', term ? 'No student matches your search.' : 'No student has this status.');

  let drawer;
  if (!canMark(me)) drawer = `<div class="drawer-body"><h3>Mark present by hand</h3><p class="muted">Assistants open and close sessions. Only the lecturer can mark a student present by hand.</p></div>`;
  else if (!markable) drawer = `<div class="drawer-body"><h3>Mark present by hand</h3><p class="muted">This session has not started. Marks can be added once it is open.</p></div>`;
  else if (!sel || sel.state === 'present' || sel.state === 'late' || sel.state === 'manual') {
    drawer = `<div class="drawer-body"><h3>Mark present by hand</h3><p class="muted">For when a cuff tap did not reach the reader.</p>
      ${sel ? `<p class="note green">${esc(sel.student.name)} is already ${D.STATE_LABEL[sel.state].toLowerCase()}${sel.mark ? ` (${esc(sel.mark.reason)}, by ${esc(sel.mark.marked_by)})` : ''}.</p>${sel.mark ? btn('Undo this mark', 'undoMark', { kind: 'secondary', data: { 'data-id': sel.mark.id } }) : ''}` : '<p class="muted">Pick a student without a tap in the list.</p>'}</div>`;
  } else {
    const reason = ui.form.mkReason || 'Cuff tag unreadable (fault open)';
    const reasons = ['Cuff tag unreadable (fault open)', 'Reader offline in this room', 'Forgot the jacket today', 'Other'];
    drawer = `<form class="drawer-body" data-form="saveMark">
      <div class="drawer-top"><h3>Mark present by hand</h3><button type="button" class="icon-btn mobile-only" data-act="closeDrawer" aria-label="Close">${icon('close')}</button></div>
      <p class="muted">For when a cuff tap did not reach the reader</p>
      <div class="who card-soft">${avatar(D.initials(sel.student.name), 'yellow')}<div><b>${esc(sel.student.name)}</b><small>${esc(sel.student.id)} · no tap recorded</small></div></div>
      <div class="field"><span>Reason</span>${reasons.map((r) => `<label class="radio ${reason === r ? 'on' : ''}"><input type="radio" data-bind="mkReason" name="mkReason" value="${esc(r)}" ${reason === r ? 'checked' : ''}><i></i>${esc(r)}</label>`).join('')}</div>
      ${field('Note (optional)', `<textarea data-bind="mkNote" rows="3" placeholder="For example: showed me the app alert at the door">${esc(ui.form.mkNote || '')}</textarea>`)}
      <p class="note lav">Saved with your name and the time. The student sees it in Kinecto Care and the FabLab gets the cuff fault.</p>
      <div class="row gap"><button class="btn primary" type="submit">Save · mark present</button><button class="btn secondary" type="button" data-act="closeDrawer">Cancel</button></div>
      <p class="muted small">Undo is available for 10 s after saving</p>
    </form>`;
  }

  const sessionPicker = `<select data-change="pickSessionSel" aria-label="Choose a session">${near.map((x) => `<option value="${esc(x.id)}" ${x.id === s.id ? 'selected' : ''}>${esc(D.dayLabel(x.starts_at))} · ${D.hhmm(x.starts_at)} · ${esc(x.module)} ${esc(x.type || '')}</option>`).join('')}</select>`;
  return `${head('Register', `${s.module} ${s.type || ''} · ${D.dayLabel(s.starts_at)} · ${D.hhmm(s.starts_at)} – ${D.hhmm(s.ends_at)} · ${s.room || ''}`,
      `${sessionPicker}${btn('Export CSV', 'exportReg', { kind: 'secondary', data: { 'data-id': s.id } })}${btn('Send to ITS', 'noop', { disabled: true, title: 'NUST ITS is not connected in this prototype' })}`)}
    <div class="row gap wrap chips">${chips.map(([k, l]) => chip(l, 'setForm', filter === k, { 'data-k': 'regFilter', 'data-v': k })).join('')}
      <div class="search sm">${icon('search')}<input data-bind="regSearch" data-live placeholder="Search name or number" value="${esc(ui.form.regSearch || '')}" aria-label="Search the register"></div>
      <span class="spacer"></span>${statePill(s)}</div>
    <div class="grid register-grid ${ui.drawer ? 'drawer-on' : ''}">
      <section class="card">${table}</section>
      <aside class="card drawer">${drawer}</aside>
    </div>`;
}

async function saveMark(el, ev, { me, q, ui, render }) {
  const s = pickSession(me, q);
  const sid = ui.drawer?.student;
  if (!s || !sid) return;
  const reason = ui.form.mkReason || 'Cuff tag unreadable (fault open)';
  const row = await api.markByHand({ session_id: s.id, student_id: sid, reason: reason.replace(' (fault open)', ''), note: ui.form.mkNote || null, marked_by: me.name });
  const name = D.student(sid)?.name || sid;
  ui.form.mkNote = ''; ui.drawer = null;
  render();
  toast(`${name} marked present`, { action: 'Undo', ms: 10000, onAction: () => api.undoMark(row.id).then(() => toast('Mark undone')).catch((e) => toast(e.message, { tone: 'error' })) });
}

// ================= Reports =================
function reports({ me, q, ui }) {
  const courses = D.coursesOf(me);
  const code = q.c || courses[0]?.code;
  if (!code) return head('Reports', '') + empty('No courses', 'You are not the lecturer of any course yet.');
  const cs = D.courseStats(code);
  const series = D.weeklySeries([code]);
  const tq = D.tapQuality(cs.held);
  const marks = cs.regs.reduce((a, r) => a + r.counts.manual, 0);
  return `${head('Reports', `${code} · ${courseName(code)} · ${cs.held.length} session${cs.held.length === 1 ? '' : 's'} held`, `${courses.map((c) => `<a class="chip ${c.code === code ? 'active' : ''}" href="#/reports?c=${esc(c.code)}">${esc(c.code)}</a>`).join('')}${btn('Export CSV', 'exportReport', { kind: 'primary', data: { 'data-c': code } })}`)}
    <div class="kpis four">${kpi('Average attendance', D.pct(cs.pct), 'green')}${kpi('Sessions held', cs.held.length, 'cyan')}${kpi('Below 75%', `${cs.below.length} student${cs.below.length === 1 ? '' : 's'}`, 'pink')}${kpi('Fixed by hand', cs.manualPct == null ? '—' : `${D.pct(cs.manualPct)} of taps`, 'lav')}</div>
    <div class="grid reports-grid">
      <section class="card"><div class="card-head"><h3>Attendance per week</h3><span class="bad small">target 75%</span></div>
        ${series.length ? bars(series, { target: D.TARGET, label: false }) : empty('No closed sessions yet', 'Weeks appear here after the first session of this course is closed.')}</section>
      <section class="card"><div class="card-head"><h3>Students below 75%</h3></div>
        ${cs.below.length ? `<ul class="list">${cs.below.map(({ st, s }) => `<li><a href="#/student?id=${esc(st.id)}&c=${esc(code)}" class="strong">${esc(st.name)}</a><b class="bad">${D.pct(s.pct)}</b>${btn('Send reminder', 'remind', { kind: 'secondary', size: 'sm', data: { 'data-id': st.id, 'data-c': code } })}</li>`).join('')}</ul>` : empty('Everyone is above 75%', cs.held.length ? '' : 'No sessions held yet.')}</section>
    </div>
    <section class="card"><div class="card-head"><h3>Tap quality (this helps the jacket team)</h3></div>
      <div class="kpis four">${kpi('Taps read first time', D.pct(tq.firstTime, 1), 'green')}${kpi('Double taps ignored', tq.dup, 'cyan')}${kpi('Rejected taps', tq.rejected, 'pink')}${kpi('Marked by hand', marks, 'yellow')}</div>
      <p class="muted small">Reports use only session, time and student number. Rejected taps include taps before a session was opened.</p></section>`;
}

// ================= Session closed (summary) =================
function summary({ me, q }) {
  const s = q.s ? D.sessionById(q.s) : D.sessionsOf(me).filter((x) => x.status === 'closed').sort((a, b) => new Date(b.closed_at) - new Date(a.closed_at))[0];
  if (!s) return head('Session summary', '') + empty('No closed session yet', 'A summary appears here when a session closes.');
  const reg = D.register(s), c = reg.counts;
  const start = new Date(s.starts_at).getTime(), cutoff = D.lateCutoff(s);
  const bins = Array.from({ length: 13 }, (_, i) => ({ t: new Date(start + (i - 3) * 2 * 60000), n: 0 }));
  for (const e of reg.events.filter((x) => x.direction === 'IN')) {
    const i = Math.floor((new Date(e.ts) - start) / 120000) + 3;
    bins[Math.max(0, Math.min(bins.length - 1, i))].n++;
  }
  const maxN = Math.max(1, ...bins.map((b) => b.n));
  const absent = reg.rows.filter((r) => r.state === 'absent' || r.state === 'notyet');
  const door = D.doorAttempts(s);
  const dup = door.filter((a) => /already recorded/i.test(a.message || '')).length;
  const rejected = door.filter((a) => !a.ok && !/already recorded/i.test(a.message || ''));
  const nextS = T.sessions.filter((x) => x.module === s.module && x.starts_at && new Date(x.starts_at) > Date.now() && x.status !== 'closed').sort((a, b) => new Date(a.starts_at) - new Date(b.starts_at))[0];
  const r = D.reader(s.reader_id);
  return `${head(s.status === 'closed' ? 'Session closed' : 'Session so far', `${s.module} ${s.type || ''} · ${D.dayLabel(s.starts_at)} · ${D.hhmm(s.starts_at)} – ${D.hhmm(s.ends_at)} · ${s.room || ''}`,
      `<a class="btn secondary" href="#/register?s=${esc(s.id)}">Open register</a>${btn('Export CSV', 'exportReg', { data: { 'data-id': s.id } })}`)}
    <div class="kpis five">${kpi('Present', `${c.in} of ${c.total}`, 'green')}${kpi('On time', c.present, 'green')}${kpi('Late', c.late, 'yellow')}${kpi('Absent', c.absent + c.notyet, 'pink')}${kpi('Fixed by hand', c.manual, 'lav')}</div>
    <div class="grid summary-grid">
      <section class="card"><div class="card-head"><h3>Check-ins over time</h3><span class="gold-text small">Late after ${D.hhmm(cutoff)}</span></div>
        <div class="hist">${bins.map((b) => `<div class="bar"><b style="height:${(b.n / maxN) * 100}%" class="${cutoff && b.t >= cutoff ? 'gold' : ''}">${b.n ? `<em>${b.n}</em>` : ''}</b><span>${D.hhmm(b.t)}</span></div>`).join('')}</div></section>
      <section class="card"><div class="card-head"><h3>Absent (${absent.length})</h3></div>
        ${absent.length ? `<ul class="list">${absent.map((x) => { const st = D.studentStats(x.student.id, s.module); const n = st.held - st.attended; return `<li><a class="strong" href="#/student?id=${esc(x.student.id)}&c=${esc(s.module)}">${esc(x.student.name)}</a><span class="${n >= 3 ? 'bad' : 'muted'} small">${n ? `${n}${['th', 'st', 'nd', 'rd'][n % 10 > 3 || [11, 12, 13].includes(n % 100) ? 0 : n % 10]} absence` : 'first absence'}</span>${btn('Remind', 'remind', { kind: 'secondary', size: 'sm', data: { 'data-id': x.student.id, 'data-c': s.module } })}</li>`; }).join('')}</ul>` : empty('Nobody was absent')}</section>
    </div>
    <section class="note-card cyan"><h3>What happened at the door</h3>
      <p>${door.filter((a) => a.ok).length} taps read · ${dup} double tap${dup === 1 ? '' : 's'} ignored · ${rejected.length} rejected${rejected[0] ? ` (latest: "${esc(rejected[rejected.length - 1].message)}")` : ''} · ${c.manual} marked by hand · reader ${esc(s.reader_id || '—')} ${r ? (D.readerOnline(r) ? 'online now' : `last seen ${D.ago(r.last_seen)}`) : 'not set'}</p></section>
    <section class="card row between wrap">${nextS ? `<p><b>Next for this course:</b> ${esc(D.dayLabel(nextS.starts_at))} · ${D.hhmm(nextS.starts_at)} · ${esc(nextS.room || '')}${nextS.auto_open ? ` · opens itself at ${D.hhmm(new Date(new Date(nextS.starts_at) - (nextS.open_before_min ?? 5) * 60000))}` : ''}</p>` : '<p class="muted">No more sessions planned for this course.</p>'}
      ${btn('Send summary to students', 'remindAll', { kind: 'secondary', data: { 'data-id': s.id } })}</section>`;
}

// ================= Student detail =================
function studentPage({ me, q }) {
  const st = D.student(q.id);
  if (!st) return head('Student', '') + empty('Student not found');
  const shared = D.coursesOf(me).filter((c) => (st.modules || []).includes(c.code));
  const code = q.c && shared.some((c) => c.code === q.c) ? q.c : shared[0]?.code;
  if (!code) return head(st.name, st.id) + empty('Not in your courses', 'This student is not enrolled in a course you teach.');
  const s = D.studentStats(st.id, code);
  const last = s.history.slice(-10);
  const letter = { present: 'P', late: 'L', absent: 'A', manual: 'M' };
  const tone = { present: 'green', late: 'yellow', absent: 'pink', manual: 'lav' };
  const historyRows = s.history.slice().reverse().slice(0, 12).map((h) => {
    const r = h.row;
    const detail = h.state === 'manual' ? `${r.mark.reason} · by ${r.mark.marked_by}` : r?.tin ? `Reader ${r.tin.reader_id || h.session.reader_id}` : 'No tap';
    return `<tr><td><b>${esc(D.dayLabel(h.session.starts_at))} ${D.hhmm(h.session.starts_at)}</b></td><td class="muted">${r?.tin ? D.hhmm(r.tin.ts) : r?.mark ? D.hhmm(r.mark.created_at) : '—'}</td><td>${pill(D.STATE_LABEL[h.state], tone[h.state])}</td><td class="muted">${esc(detail)}</td></tr>`;
  }).join('');
  const below = s.pct != null && s.pct < D.TARGET;
  return `${head(st.name, `${st.id} · ${(st.modules || []).join(', ')}`, `${shared.length > 1 ? shared.map((c) => `<a class="chip ${c.code === code ? 'active' : ''}" href="#/student?id=${esc(st.id)}&c=${esc(c.code)}">${esc(c.code)}</a>`).join('') : ''}${btn('Message', 'remind', { data: { 'data-id': st.id, 'data-c': code } })}`, `<a href="#/register">Register</a> / ${esc(code)} / Student`)}
    <div class="kpis four">${kpi('Attendance this semester', D.pct(s.pct), below ? 'pink' : 'green')}${kpi('Sessions attended', `${s.attended} of ${s.held}`, 'grey')}${kpi('Late arrivals', s.late, 'yellow')}${kpi('Fixed by hand', s.manual, 'lav')}</div>
    <section class="card"><div class="card-head"><h3>Last ${last.length} session${last.length === 1 ? '' : 's'}</h3></div>
      ${last.length ? `<div class="strip">${last.map((h) => `<div class="tile ${tone[h.state]}"><b>${letter[h.state]}</b><small>${esc(D.dayLabel(h.session.starts_at))}</small></div>`).join('')}</div><p class="muted small">P present · L late · A absent · M marked by hand</p>` : empty('No sessions held yet')}</section>
    <div class="grid student-grid">
      <section class="card"><div class="card-head"><h3>Tap history</h3></div>${historyRows ? `<div class="table-wrap"><table class="table"><thead><tr><th>Session</th><th>Time</th><th>Status</th><th>Details</th></tr></thead><tbody>${historyRows}</tbody></table></div>` : empty('No history yet')}</section>
      <section class="card ${below ? 'pink-card' : 'green-card'}"><h3>${below ? 'Below the 75% rule' : 'On track'}</h3>
        <p>${below ? (s.reachable ? `${esc(st.name)} needs ${s.need} more session${s.need === 1 ? '' : 's'} present out of the ${s.remaining} left to reach 75% by the end of the semester.` : `${esc(st.name)} can no longer reach 75% this semester (${s.remaining} sessions left).`) : s.held ? `${esc(st.name)} is at ${D.pct(s.pct)}, above the 75% rule.` : 'No sessions held yet.'}</p>
        ${below ? `<div class="col gap">${btn('Send reminder', 'remind', { kind: 'secondary', data: { 'data-id': st.id, 'data-c': code } })}${btn('Refer to student support', 'refer', { kind: 'secondary', data: { 'data-id': st.id, 'data-c': code } })}</div>` : ''}
        <p class="muted small">Only you and NUST admins can see this page.</p></section>
    </div>`;
}

// ================= Settings =================
function settings({ me }) {
  const s = settingsOf(me);
  const opt = (k, v, options) => `<select data-change="saveSetting" data-k="${k}" aria-label="${k}">${options.map(([val, l]) => `<option value="${val}" ${String(val) === String(v) ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select>`;
  const alerts = [['tapPopups', 'Pop-up when a student taps in or out'], ['readerOffline', 'Reader in my room goes offline'], ['absences3', 'A student reaches 3 absences'], ['dailySummary', 'Daily summary email at 17:00'], ['autoOpened', 'Session opened by itself'], ['markedByOther', 'Student marked present by another lecturer']];
  return `${head('Settings', 'Your defaults for new sessions and alerts')}
    <div class="grid two-col">
      <section class="card"><div class="card-head"><h3>Session defaults</h3></div>
        <ul class="settings">
          <li><span>Late after</span>${opt('late', s.late, [[5, '5 min'], [10, '10 min'], [15, '15 min']])}</li>
          <li><span>Open the session</span>${opt('openBefore', s.openBefore, [[0, 'At the start'], [5, '5 min before start'], [10, '10 min before start'], [15, '15 min before start']])}</li>
          <li><span>Close the session</span>${opt('autoClose', s.autoClose, [[true, 'At the end time'], [false, 'Only by hand']])}</li>
          <li><span>Taps after close</span>${pill('Rejected', 'white')}</li>
          <li><span>Default room</span>${opt('defaultRoom', s.defaultRoom || T.rooms[0]?.id, T.rooms.map((r) => [r.id, `${r.name} · ${r.building || ''}`]))}</li>
        </ul></section>
      <section class="card"><div class="card-head"><h3>Alerts</h3></div>
        <ul class="settings">${alerts.map(([k, l]) => `<li><span>${esc(l)}</span>${toggle(!!s[k], 'toggleSetting', { 'data-k': k })}</li>`).join('')}
          <li><span>Desktop notifications<small class="muted block">Shows taps while Unity or another window is in front</small></span>${!('Notification' in window) ? pill('Not supported', 'grey') : Notification.permission === 'granted' ? pill('On', 'green') : Notification.permission === 'denied' ? pill('Blocked in browser', 'pink') : btn('Allow', 'allowNotify', { kind: 'secondary', size: 'sm' })}</li></ul></section>
      <section class="card"><div class="card-head"><h3>Export</h3></div>
        <dl class="facts"><dt>Format</dt><dd>CSV</dd><dt>Columns</dt><dd>Student, student no., time in, time out, status, reason</dd><dt>Send to NUST ITS</dt><dd class="muted">Not connected in this prototype</dd></dl></section>
      <section class="card navy-card"><div class="card-head"><h3>Account</h3></div>
        <p>${esc(me.email)}<br>Role: ${esc(me.role.charAt(0).toUpperCase() + me.role.slice(1))}${me.role === 'lecturer' ? ' (from the NUST timetable)' : ''}<br>Courses: ${esc(D.coursesOf(me).map((c) => c.code).join(', ') || '—')}</p>
        <p class="small soft">Roles are given by NUST ICT. Ask an admin if a course is missing.</p>
        ${btn('Sign out', 'signOut', { kind: 'secondary' })}</section>
    </div>`;
}

// ================= actions =================
const acts = {
  async openSession(el, ev, { me }) {
    const s = D.sessionById(el.dataset.id);
    const other = T.sessions.find((x) => x.status === 'open' && x.reader_id && x.reader_id === s.reader_id && x.id !== s.id);
    if (other) throw new Error(`${other.module} ${other.type || ''} is still open at reader ${s.reader_id}. Close it first, so taps go to the right session.`);
    await api.openSession(s.id, me.name);
    toast(`${s.module} ${s.type || ''} is open · students can tap in at ${s.reader_id || 'the reader'}`);
  },
  async closeSession(el, ev, { me, go }) {
    const s = D.sessionById(el.dataset.id);
    await api.closeSession(s.id, me.name);
    toast(`${s.module} ${s.type || ''} closed`);
    go('summary', { s: s.id });
  },
  newSession(el, ev, { ui, render, go }) {
    if (location.hash.split('?')[0] !== '#/sessions') return go('sessions', { new: 1 });
    ui.modal = 'new'; render();
  },
  closeModalBtn(el, ev, { ui, render }) { ui.modal = null; render(); },
  setForm(el, ev, { ui, render }) { ui.form[el.dataset.k] = el.dataset.v; render(); },
  createSession,
  selectStudent(el, ev, { ui, render }) { if (ev.target.closest('a')) return; ui.drawer = { student: el.dataset.id }; ui.form.mkNote = ''; render(); },
  closeDrawer(el, ev, { ui, render, go, q }) { ui.drawer = null; if (q.mark) go('register', { s: q.s }); else render(); },
  pickSessionSel(el, ev, { go, ui }) { ui.drawer = null; go('register', { s: el.value }); },
  saveMark,
  async undoMark(el) { await api.undoMark(el.dataset.id); toast('Mark undone'); },
  exportReg(el, ev, { me }) { exportRegister(D.sessionById(el.dataset.id), me); },
  exportReport(el, ev, { me }) {
    const code = el.dataset.c;
    const rows = D.enrolled(code).map((st) => { const s = D.studentStats(st.id, code); return [st.name, st.id, s.attended, s.held, s.pct == null ? '' : Math.round(s.pct * 100) + '%', s.late, s.manual]; });
    downloadCsv(`${code}-attendance.csv`, [['Student', 'Student no.', 'Attended', 'Held', 'Attendance', 'Late', 'Fixed by hand'], ...rows]);
    api.audit(me.name, 'Export', `${code} report · CSV`).catch(() => {});
  },
  async remind(el, ev, { me }) {
    const st = D.student(el.dataset.id);
    await api.audit(me.name, 'Reminder', `${st?.name || el.dataset.id} · ${el.dataset.c}`);
    toast(`Reminder logged for ${st?.name || el.dataset.id} · email delivery is not connected yet`);
  },
  async remindAll(el, ev, { me }) {
    const s = D.sessionById(el.dataset.id);
    await api.audit(me.name, 'Summary sent', `${s.module} ${s.type || ''} · ${D.dayLabel(s.starts_at)}`);
    toast('Summary logged · email delivery is not connected yet');
  },
  async refer(el, ev, { me }) {
    const st = D.student(el.dataset.id);
    await api.audit(me.name, 'Referral', `${st?.name || el.dataset.id} → student support · ${el.dataset.c}`);
    toast('Referral logged in the audit log');
  },
  async saveSetting(el, ev, { me }) {
    let v = el.value;
    if (v === 'true' || v === 'false') v = v === 'true'; else if (/^\d+$/.test(v)) v = Number(v);
    await api.saveStaff(me.id, { settings: { ...settingsOf(me), [el.dataset.k]: v } });
    toast('Saved');
  },
  async allowNotify(el, ev, { render }) {
    try { await Notification.requestPermission(); } catch { /* ignore */ }
    render();
  },
  async toggleSetting(el, ev, { me }) {
    const s = settingsOf(me);
    await api.saveStaff(me.id, { settings: { ...s, [el.dataset.k]: !s[el.dataset.k] } });
  },
  noop() {},
};

export const lecturerPages = {
  today: { render: today, acts },
  sessions: { render: sessions, acts, modal: newSessionModal },
  register: { render: registerPage, acts },
  reports: { render: reports, acts },
  settings: { render: settings, acts },
  summary: { render: summary, acts, hidden: true },
  student: { render: studentPage, acts, hidden: true },
};
