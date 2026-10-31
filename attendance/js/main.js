// Kinecto Attendance: sign-in, the app shell, routing and one click handler for every screen.
import { T, status, onChange, onInsert, loadAll, startRealtime, api, configured } from './store.js';
import { esc, icon, LOGO, toast, avatar } from './ui.js';
import { initials, staffById, coursesOf, sessionsOf, sessionById, student as studentOf, dayKey, hhmm } from './derive.js';
import { lecturerPages } from './lecturer.js';
import { adminPages } from './admin.js';

const SIGNED_IN = 'kinecto-desk-staff';   // the only thing kept in the browser: who is signed in on this tab

export const ui = { form: {}, modal: null, drawer: null, signin: { step: 'email' }, navOpen: false, seen: new Set(), nums: new Map() };
let lastRoute = '';

const NAV = {
  lecturer: [['today', 'Today'], ['sessions', 'Sessions'], ['register', 'Register'], ['reports', 'Reports'], ['settings', 'Settings']],
  assistant: [['today', 'Today'], ['sessions', 'Sessions'], ['register', 'Register'], ['settings', 'Settings']],
  admin: [['overview', 'Overview'], ['readers', 'Readers'], ['rooms', 'Rooms'], ['courses', 'Courses'], ['reports', 'Reports'], ['roles', 'Roles'], ['audit', 'Audit log']],
};
const MOBILE_NAV = { lecturer: ['today', 'register', 'reports', 'settings'], assistant: ['today', 'sessions', 'register', 'settings'], admin: ['overview', 'readers', 'reports', 'audit'] };

export function me() {
  const id = sessionStorage.getItem(SIGNED_IN);
  return id ? staffById(id) : null;
}

export function route() {
  const [path, qs] = location.hash.replace(/^#\/?/, '').split('?');
  const q = Object.fromEntries(new URLSearchParams(qs || ''));
  return { page: path || '', q };
}

export function go(page, q = {}) {
  const qs = new URLSearchParams(Object.entries(q).filter(([, v]) => v != null && v !== '')).toString();
  location.hash = `#/${page}${qs ? `?${qs}` : ''}`;
}

const PARENT = { reader: 'readers', summary: 'today', student: 'register' };
const pagesFor = (role) => (role === 'admin' ? adminPages : lecturerPages);

// ---------- sign-in (Figma 08c "Shared · Web sign-in") ----------
function signInView() {
  const s = ui.signin;
  const known = s.staff;
  const codeBoxes = Array.from({ length: 6 }, (_, i) => `<span class="${(ui.form.code || '').length > i ? 'filled' : ''}">${esc((ui.form.code || '')[i] || '')}</span>`).join('');
  return `<div class="signin">
    <section class="signin-side">
      ${LOGO}
      <h1>Kinecto Attendance</h1>
      <p>Cuff-tap attendance for NUST lecturers and admins</p>
      <ul>
        <li><strong>Open a session in one tap</strong><span>Live check-ins from the cuff tap</span></li>
        <li><strong>Fix a missed tap</strong><span>With a reason, logged for audit</span></li>
        <li><strong>Reports in seconds</strong><span>Weekly attendance against the 75% rule</span></li>
      </ul>
      <small>Only session, time and tag id are stored per tap. No location.</small>
    </section>
    <section class="signin-main">
      <form class="signin-form" data-form="${s.step === 'email' ? 'signinEmail' : 'signinCode'}" novalidate>
        <h2>Sign in</h2>
        <p class="muted">Use your NUST email. We send a 6-digit code.</p>
        <label class="field"><span>NUST email</span>
          <input data-bind="email" type="email" autocomplete="username" placeholder="name@nust.na" value="${esc(ui.form.email || '')}" ${s.step === 'code' ? 'readonly' : ''} required></label>
        ${known ? `<div class="note green">${esc(known.role === 'admin' ? 'Admin' : known.role === 'assistant' ? 'Assistant' : 'Staff')} email found · role: ${esc(cap(known.role))}${known.role === 'lecturer' ? ' (from the NUST timetable)' : ''}</div>` : ''}
        ${s.step === 'code' ? `
          <label class="field"><span>Code</span>
            <div class="code-boxes">${codeBoxes}<input data-bind="code" inputmode="numeric" maxlength="6" autocomplete="one-time-code" value="${esc(ui.form.code || '')}" aria-label="6-digit code"></div></label>
          <p class="muted small">Demo code <b>${esc(s.expected)}</b> · NUST email delivery is not connected in this prototype · <a href="#" data-act="resendCode">Resend code</a></p>` : ''}
        ${s.error ? `<div class="note pink">${esc(s.error)}</div>` : ''}
        <button class="btn primary" type="submit">${s.step === 'email' ? 'Send code' : 'Sign in'}</button>
        ${s.step === 'code' ? `<button class="btn link" type="button" data-act="changeEmail">Use another email</button>` : ''}
        <p class="muted small">Students and staff wearers use the Kinecto Care phone app instead.</p>
        ${s.step === 'email' && T.staff.length ? `<details class="demo-accounts"><summary>Demo accounts</summary>${T.staff.map((p) => `<button type="button" class="chip" data-act="pickEmail" data-email="${esc(p.email)}">${esc(p.name)} · ${esc(cap(p.role))}</button>`).join('')}</details>` : ''}
      </form>
    </section>
  </div>`;
}

const cap = (s) => String(s || '').charAt(0).toUpperCase() + String(s || '').slice(1);

function newCode() { return String(Math.floor(100000 + Math.random() * 900000)); }

const signinActs = {
  signinEmail() {
    const email = String(ui.form.email || '').trim().toLowerCase();
    const s = ui.signin;
    if (!/^[^@\s]+@(nust\.na|students\.nust\.na)$/.test(email)) { s.error = 'That email is not a NUST address. Use @nust.na or your NUST student email.'; s.staff = null; return render(); }
    const found = T.staff.find((p) => p.email.toLowerCase() === email);
    if (!found) { s.error = 'This NUST email has no Kinecto Attendance role. Students use the Kinecto Care phone app; staff ask an admin to add them.'; s.staff = null; return render(); }
    Object.assign(s, { step: 'code', staff: found, expected: newCode(), error: '' });
    ui.form.code = '';
    render();
    document.querySelector('[data-bind="code"]')?.focus();
  },
  async signinCode() {
    const s = ui.signin;
    if ((ui.form.code || '') !== s.expected) { s.error = 'That code is not right. Check it and try again.'; return render(); }
    sessionStorage.setItem(SIGNED_IN, s.staff.id);
    api.saveStaff(s.staff.id, { last_sign_in: new Date().toISOString() }).catch(() => {});
    ui.signin = { step: 'email' }; ui.form = {};
    go(s.staff.role === 'admin' ? 'overview' : 'today');
  },
  resendCode(el, ev) { ev.preventDefault(); ui.signin.expected = newCode(); ui.form.code = ''; render(); toast('New code sent'); },
  changeEmail() { ui.signin = { step: 'email' }; render(); },
  pickEmail(el) { ui.form.email = el.dataset.email; signinActs.signinEmail(); },
};

// ---------- shell ----------
function shell(person, body, page) {
  const nav = NAV[person.role] || NAV.lecturer;
  const live = status.state === 'live';
  const item = ([key, label]) => `<a href="#/${key}" class="${key === page ? 'active' : ''}" ${key === page ? 'aria-current="page"' : ''}>${icon(key === 'audit' ? 'audit' : key)}<i class="nav-dot"></i><span>${esc(label)}</span></a>`;
  const mob = (MOBILE_NAV[person.role] || []).map((k) => nav.find((n) => n[0] === k)).filter(Boolean);
  return `<div class="layout ${ui.navOpen ? 'nav-open' : ''}">
    <aside class="sidebar" aria-label="Main navigation">
      <div class="brand">${LOGO}<div><strong>Kinecto Attendance</strong><small>${person.role === 'admin' ? 'Admin' : person.role === 'assistant' ? 'Assistant desk' : 'Lecturer desk'}</small></div>
        <button class="icon-btn close-nav" data-act="toggleNav" aria-label="Close menu">${icon('close')}</button></div>
      <nav class="nav">${nav.map(item).join('')}</nav>
      <div class="sync ${live ? 'live' : 'off'}" title="${esc(status.error || '')}"><i></i>${live ? 'Live · Supabase' : status.state === 'reconnecting' ? 'Reconnecting…' : 'Offline'}</div>
      <div class="profile">${avatar(initials(person.name), 'yellow')}<div><strong>${esc(person.name)}</strong><small>${esc(cap(person.role))}${person.role !== 'admin' ? ' · ' + esc(coursesOf(person).map((c) => c.code)[0] || '') : ' · ICT'}</small></div>
        <button class="icon-btn" data-act="signOut" title="Sign out" aria-label="Sign out">${icon('arrowR')}</button></div>
    </aside>
    <div class="scrim" data-act="toggleNav"></div>
    <header class="topbar">
      <button class="icon-btn" data-act="toggleNav" aria-label="Open menu">${icon('menu')}</button>
      <div class="brand mini">${LOGO}<strong>Kinecto Attendance</strong></div>
      <span class="sync-dot ${live ? 'live' : 'off'}" title="${live ? 'Live' : 'Offline'}"></span>
    </header>
    <main class="content" id="content">${body}</main>
    <nav class="tabbar" aria-label="Quick navigation">${mob.map(([k, l]) => `<a href="#/${k}" class="${k === page ? 'active' : ''}">${icon(k === 'settings' ? 'me' : k)}<span>${esc(k === 'settings' ? 'Me' : l)}</span></a>`).join('')}</nav>
  </div>`;
}

function statusScreen(title, body) {
  return `<div class="boot">${LOGO}<h1>${esc(title)}</h1><p>${esc(body)}</p>${status.state === 'error' ? '<button class="btn primary" data-act="retry">Try again</button>' : ''}</div>`;
}

// ---------- render: keep typing, focus and scroll while live data redraws the page ----------
export function render() {
  const app = document.getElementById('app');
  const focus = document.activeElement?.dataset?.bind;
  const sel = focus ? [document.activeElement.selectionStart, document.activeElement.selectionEnd] : null;
  const scroll = document.getElementById('content')?.scrollTop;
  const drawerScroll = document.querySelector('.drawer-body')?.scrollTop;

  let html;
  if (!configured) html = statusScreen('Supabase is not configured', 'Fill in attendance/supabase-config.js with the project URL and publishable key.');
  else if (status.state === 'connecting' && !status.loadedAt) html = statusScreen('Connecting…', 'Loading the shared register from Supabase.');
  else if (status.state === 'error' && !status.loadedAt) html = statusScreen('Could not load the register', status.error);
  else {
    const person = me();
    const { page, q } = route();
    if (!person) html = signInView();
    else {
      const pages = pagesFor(person.role);
      const nav = NAV[person.role] || NAV.lecturer;
      const key = pages[page] && (nav.some((n) => n[0] === page) || pages[page].hidden) ? page : nav[0][0];
      if (key !== page) { go(key, q); return; }
      const routeKey = person.id + '|' + page + '|' + JSON.stringify(q);
      const changed = routeKey !== lastRoute;
      if (changed) { ui.modal = q.new && pages[page].modal ? 'new' : null; ui.drawer = null; ui.navOpen = false; }
      lastRoute = routeKey;
      const body = pages[page].render({ me: person, q, ui });
      const modal = ui.modal && pages[page].modal ? pages[page].modal({ me: person, q, ui }) : '';
      html = shell(person, `<div class="page ${changed ? 'enter' : ''}">${body}</div>${modal ? `<div class="modal-wrap" data-act="closeModal"><div class="modal" role="dialog" aria-modal="true">${modal}</div></div>` : ''}`, PARENT[page] || page);
    }
  }
  app.innerHTML = html;

  // bump animation on numbers that changed since the last draw
  app.querySelectorAll('[data-num]').forEach((el) => {
    const k = el.dataset.num, v = el.textContent;
    if (ui.nums.has(k) && ui.nums.get(k) !== v) { el.classList.add('bump'); }
    ui.nums.set(k, v);
  });
  if (focus) {
    const el = app.querySelector(`[data-bind="${CSS.escape(focus)}"]`);
    if (el) { el.focus(); try { if (sel && el.setSelectionRange) el.setSelectionRange(sel[0], sel[1]); } catch { /* not a text field */ } }
  }
  const c = document.getElementById('content');
  if (c && scroll != null && !app.querySelector('.page.enter')) c.scrollTop = scroll;
  const d = document.querySelector('.drawer-body');
  if (d && drawerScroll != null) d.scrollTop = drawerScroll;
}

// ---------- one handler for every click, form and input ----------
const shellActs = {
  toggleNav() { ui.navOpen = !ui.navOpen; render(); },
  signOut() { sessionStorage.removeItem(SIGNED_IN); ui.form = {}; ui.signin = { step: 'email' }; go(''); render(); },
  retry() { status.state = 'connecting'; render(); loadAll(); },
  closeModal(el, ev) { if (ev.target === el) { ui.modal = null; render(); } },
};

function actsFor() {
  const person = me();
  const { page } = route();
  const pageActs = person ? pagesFor(person.role)[page]?.acts || {} : {};
  return { ...signinActs, ...shellActs, ...pageActs };
}

async function dispatch(name, el, ev) {
  const fn = actsFor()[name];
  if (!fn) return;
  const person = me();
  try {
    await fn(el, ev, { me: person, q: route().q, ui, render, go });
  } catch (e) {
    toast(e.message || String(e), { tone: 'error', ms: 6000 });
    render();
  }
}

document.addEventListener('click', (ev) => {
  const el = ev.target.closest('[data-act]');
  if (!el || el.disabled) return;
  if (el.tagName === 'A' && el.getAttribute('href') === '#') ev.preventDefault();
  if (el.dataset.act === 'closeModal' && ev.target !== el) return;
  dispatch(el.dataset.act, el, ev);
});

document.addEventListener('submit', (ev) => {
  const form = ev.target.closest('[data-form]');
  if (!form) return;
  ev.preventDefault();
  dispatch(form.dataset.form, form, ev);
});

document.addEventListener('input', (ev) => {
  const el = ev.target;
  if (!el.dataset.bind) return;
  ui.form[el.dataset.bind] = el.type === 'checkbox' ? el.checked : el.value;
  if (el.dataset.live !== undefined || el.dataset.bind === 'code') {
    if (el.dataset.bind === 'code') { el.value = el.value.replace(/\D/g, '').slice(0, 6); ui.form.code = el.value; if (el.value.length === 6) return signinActs.signinCode(); }
    render();
  }
});

document.addEventListener('change', (ev) => {
  const el = ev.target;
  if (el.dataset.bind) { ui.form[el.dataset.bind] = el.type === 'checkbox' ? el.checked : el.value; }
  if (el.dataset.change) dispatch(el.dataset.change, el, ev);
  else if (el.tagName === 'SELECT' || el.type === 'radio' || el.type === 'checkbox') render();
});

document.addEventListener('keydown', (ev) => {
  if (ev.key === 'Escape' && (ui.modal || ui.drawer || ui.navOpen)) { ui.modal = null; ui.drawer = null; ui.navOpen = false; render(); }
});

window.addEventListener('hashchange', render);
onChange(() => render());

// ---------- tap pop-ups: every tap IN / OUT at one of my readers, live ----------
function tapIsMine(a, who) {
  if (who.role === 'admin') return true;
  const mine = sessionsOf(who);
  if (a.session_id) return mine.some((s) => s.id === a.session_id);
  const day = dayKey(a.ts);
  return mine.some((s) => s.reader_id === a.reader_id && s.starts_at && dayKey(s.starts_at) === day);
}

function showTap(a) {
  const who = me();
  if (!who || who.settings?.tapPopups === false || !tapIsMine(a, who)) return;
  const st = a.student_id ? studentOf(a.student_id) : null;
  const s = a.session_id ? sessionById(a.session_id) : null;
  const name = st?.name || `Tag ${a.tag || 'unknown'}`;
  const dir = a.direction === 'OUT' ? 'OUT' : 'IN';
  const dup = /already recorded/i.test(a.message || '');
  const title = !a.ok ? (dup ? `${name} already tapped ${dir.toLowerCase()}` : 'Tap rejected') : `${name} tapped ${dir.toLowerCase()}`;
  const where = [s ? `${s.module} ${s.type || ''}`.trim() : null, s?.room ? `Room ${s.room}` : `Reader ${a.reader_id}`, hhmm(a.ts)].filter(Boolean).join(' · ');
  const reason = !a.ok && !dup ? String(a.message || '').replace(/^[^:]+:\s*/, '') : '';
  const body = !a.ok && !dup ? `${name} at ${s?.room ? `Room ${s.room}` : `reader ${a.reader_id}`}, ${hhmm(a.ts)}. ${reason}` : where;
  const action = st ? 'View student' : s ? 'View register' : null;

  let box = document.getElementById('taps');
  if (!box) { box = document.createElement('div'); box.id = 'taps'; box.setAttribute('aria-live', 'polite'); document.body.appendChild(box); }
  const el = document.createElement('div');
  el.className = 'tap-pop';
  el.setAttribute('role', 'status');
  el.innerHTML = `<div class="tp-head"><strong>${esc(title)}</strong><button type="button" class="tp-x" aria-label="Close">${icon('close')}</button></div>
    <p>${esc(body)}</p>${action ? `<button type="button" class="tp-go">${esc(action)}</button>` : ''}`;
  const close = () => { el.classList.add('gone'); setTimeout(() => el.remove(), 250); };
  el.querySelector('.tp-x').onclick = close;
  el.querySelector('.tp-go')?.addEventListener('click', () => { el.remove(); if (st) go('student', { id: st.id, ...(s ? { c: s.module } : {}) }); else go('register', { s: s.id }); });
  box.prepend(el);
  while (box.children.length > (innerWidth <= 640 ? 2 : 3)) box.lastElementChild.remove();
  let timer = setTimeout(close, 6000);
  el.onmouseenter = () => clearTimeout(timer);            // stays while the mouse is on it
  el.onmouseleave = () => { timer = setTimeout(close, 3000); };

  // When the desk is behind Unity or another window, also show a system notification.
  if (document.hidden && 'Notification' in window && Notification.permission === 'granted') {
    try { new Notification(title, { body, tag: `tap-${a.id}`, icon: 'assets/logo.svg' }); } catch { /* not supported */ }
  }
}
onInsert((table, row) => { if (table === 'tap_attempts') showTap(row); });

// relative times, reader online status and auto open / close
setInterval(() => { if (me()) render(); }, 20000);
setInterval(() => { if (status.state === 'live') api.autoSessions(); }, 30000);

render();
loadAll().then(() => api.autoSessions());
startRealtime();
