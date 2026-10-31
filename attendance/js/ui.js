// Small view helpers shared by every screen (Figma: App Design boards 08b and 08c).
export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const attr = (o) => Object.entries(o).filter(([, v]) => v != null && v !== false).map(([k, v]) => (v === true ? k : `${k}="${esc(v)}"`)).join(' ');

export const pill = (label, tone = 'grey', extra = '') => `<span class="pill ${tone} ${extra}">${esc(label)}</span>`;
export const dotPill = (label, tone, dot) => `<span class="pill ${tone}"><i class="dot ${dot || tone}"></i>${esc(label)}</span>`;

// data-act buttons are handled in main.js
export const btn = (label, act, opts = {}) =>
  `<button ${attr({ class: `btn ${opts.kind || 'primary'} ${opts.size || ''}`, 'data-act': act, ...opts.data, disabled: opts.disabled, title: opts.title, type: 'button' })}>${opts.icon ? icon(opts.icon) : ''}<span>${esc(label)}</span></button>`;

export const chip = (label, act, active, data = {}) =>
  `<button ${attr({ class: `chip ${active ? 'active' : ''}`, 'data-act': act, ...data, type: 'button', 'aria-pressed': active ? 'true' : 'false' })}>${esc(label)}</button>`;

export const kpi = (label, value, tone, key) => `<div class="kpi ${tone}"><span>${esc(label)}</span><strong ${key ? `data-num="${esc(key)}"` : ''}>${esc(value)}</strong></div>`;

export const avatar = (text, tone = 'yellow', size = '') => `<span class="avatar ${tone} ${size}">${esc(text)}</span>`;

export const empty = (title, body = '', action = '') => `<div class="empty"><strong>${esc(title)}</strong>${body ? `<p>${esc(body)}</p>` : ''}${action}</div>`;

export const toggle = (on, act, data = {}) => `<button ${attr({ class: `switch ${on ? 'on' : ''}`, 'data-act': act, ...data, role: 'switch', 'aria-checked': on ? 'true' : 'false', type: 'button' })}><i></i></button>`;

export const field = (label, inner, hint = '') => `<label class="field"><span>${esc(label)}</span>${inner}${hint ? `<small>${esc(hint)}</small>` : ''}</label>`;
export const input = (bind, value, extra = {}) => `<input ${attr({ 'data-bind': bind, value: value ?? '', ...extra })}>`;
export const select = (bind, value, options, extra = {}) =>
  `<select ${attr({ 'data-bind': bind, ...extra })}>${options.map((o) => { const [v, l] = Array.isArray(o) ? o : [o, o]; return `<option value="${esc(v)}" ${String(v) === String(value) ? 'selected' : ''}>${esc(l)}</option>`; }).join('')}</select>`;

// Simple line icons (stroke = currentColor), sized by CSS.
const P = {
  today: '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4M16 3v4"/>',
  sessions: '<rect x="3" y="4" width="18" height="17" rx="3"/><path d="M3 9h18M9 4v17"/>',
  register: '<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1.3"/><circle cx="4.5" cy="12" r="1.3"/><circle cx="4.5" cy="18" r="1.3"/>',
  reports: '<path d="M5 20V11M12 20V5M19 20v-7"/>',
  settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z"/>',
  overview: '<rect x="3" y="3" width="7" height="9" rx="2"/><rect x="14" y="3" width="7" height="5" rx="2"/><rect x="14" y="12" width="7" height="9" rx="2"/><rect x="3" y="16" width="7" height="5" rx="2"/>',
  readers: '<rect x="6" y="2" width="12" height="20" rx="3"/><path d="M10 18h4"/><circle cx="12" cy="8" r="2.5"/>',
  rooms: '<path d="M3 21h18M5 21V5l7-2 7 2v16M9 21v-5h6v5"/>',
  courses: '<path d="M2 8l10-5 10 5-10 5z"/><path d="M6 10v5c0 1.7 2.7 3 6 3s6-1.3 6-3v-5"/>',
  roles: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.8-3.5 3.4-5.5 6.5-5.5s5.7 2 6.5 5.5"/><circle cx="17.5" cy="9" r="2.5"/><path d="M17 14.5c2.4.2 4 1.8 4.6 4.5"/>',
  audit: '<path d="M7 3h7l5 5v13H7z"/><path d="M14 3v5h5M10 13h6M10 17h6"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  close: '<path d="M6 6l12 12M18 6L6 18"/>',
  menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
  bell: '<path d="M6 9a6 6 0 1 1 12 0c0 6 2.5 7.5 2.5 7.5h-17S6 15 6 9z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
  download: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
  arrowL: '<path d="M15 6l-6 6 6 6"/>',
  arrowR: '<path d="M9 6l6 6-6 6"/>',
  play: '<path d="M8 5l11 7-11 7z"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7"/>',
  me: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4.2 4.2-6.5 8-6.5s7 2.3 8 6.5"/>',
};
export const icon = (name, cls = '') => `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true">${P[name] || ''}</svg>`;

export const LOGO = `<svg class="logo" viewBox="0 0 200 200" aria-label="Kinecto Attendance"><path d="M129.7 18.4c34.9 12.3 59.9 45.5 59.9 84.6 0 49.5-40.1 89.7-89.6 89.7S10.3 152.5 10.3 103c0-39.1 25-72.4 60-84.6l2.9 21.8C48.8 50.6 31.7 74.8 31.7 103c0 37.7 30.6 68.3 68.3 68.3s68.3-30.6 68.3-68.3c0-28.2-17.1-52.4-41.5-62.8z" fill="#F2A900"/><path d="M107.2 14.7c.8 0 1.4.6 1.4 1.4v33.8H120c3.4 0 6.2 2.8 6.2 6.2v34.5h3.4c1.9 0 3.4 1.5 3.4 3.4v9c0 1.9-1.5 3.4-3.4 3.4h-11v28.3c0 1.1-.9 2.1-2.1 2.1h-4.1c-1.1 0-2.1-.9-2.1-2.1v-28.3H89.7v28.3c0 1.1-.9 2.1-2.1 2.1h-4.1c-1.1 0-2.1-.9-2.1-2.1v-28.3h-11c-1.9 0-3.4-1.5-3.4-3.4v-9c0-1.9 1.5-3.4 3.4-3.4h3.4V56.1c0-3.4 2.8-6.2 6.2-6.2h11.4V16.1c0-.8.6-1.4 1.4-1.4z" fill="#D62828"/></svg>`;

// ---------- toasts (live outside the re-rendered app) ----------
export function toast(message, opts = {}) {
  const box = document.getElementById('toasts');
  const t = document.createElement('div');
  t.className = `toast ${opts.tone || ''}`;
  t.setAttribute('role', 'status');
  t.innerHTML = `<span>${esc(message)}</span>${opts.action ? `<button type="button">${esc(opts.action)}</button>` : ''}`;
  if (opts.action) t.querySelector('button').onclick = () => { opts.onAction?.(); t.remove(); };
  box.appendChild(t);
  const ms = opts.ms ?? 4000;
  setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 300); }, ms);
  return t;
}

// ---------- CSV export ----------
export function downloadCsv(filename, rows) {
  const csv = rows.map((r) => r.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(',')).join('\r\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' }));
  a.download = filename;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
}

// bar chart with an optional target line (values 0..1)
export function bars(series, { target = null, height = 220, accent = (v) => v < 0.8, label = true } = {}) {
  if (!series.length) return '';
  return `<div class="bars" style="--h:${height}px">${target != null ? `<i class="target" style="bottom:calc(28px + (var(--h) - 54px) * ${target})">${label ? `<em>target ${Math.round(target * 100)}%</em>` : ''}</i>` : ''}${series.map((s) => `<div class="bar"><b style="height:${Math.max(2, s.pct * 100)}%" class="${accent(s.pct) ? 'gold' : ''}"><em>${Math.round(s.pct * 100)}%</em></b><span>${esc(s.label)}</span></div>`).join('')}</div>`;
}
