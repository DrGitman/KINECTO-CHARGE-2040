-- Attendance Desk (Figma boards 08b + 08c): proper tables for everything the lecturer and admin screens show,
-- so the website reads and writes Supabase only (no browser storage) and every screen updates live.
--   rooms, readers (with a live last_seen), staff (roles), courses, attendance_corrections (marked by hand),
--   tap_attempts (every tap, accepted or rejected), audit_log, session start/end times, auto open / close.
-- record_tap keeps its signature, so the Unity door reader and the attendance-ingest Edge Function work unchanged.
-- MOCK DATA ONLY: same open demo policies as 20261028120000_kinecto_live_sync.sql.

-- ---------- Rooms and readers ----------
create table if not exists public.rooms (
  id text primary key,
  name text not null,
  building text,
  seats integer,
  access text,
  created_at timestamptz not null default now()
);

create table if not exists public.readers (
  id text primary key,
  room_id text references public.rooms (id) on delete set null,
  door text,
  firmware text not null default '2.1.0',
  is_virtual boolean not null default false,
  last_seen timestamptz,                  -- set by every tap at this reader (and by the Unity lab while it runs)
  added_by text not null default 'System',
  created_at timestamptz not null default now()
);

-- ---------- Staff (who may use the desk) and courses ----------
create table if not exists public.staff (
  id text primary key,
  name text not null,
  email text not null unique check (email ~* '^[^@]+@(nust\.na|students\.nust\.na)$'),
  role text not null check (role in ('lecturer', 'admin', 'assistant')),
  settings jsonb not null default '{}',
  changed_by text,
  last_sign_in timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.courses (
  code text primary key,
  title text not null,
  faculty text,
  lecturer_id text references public.staff (id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------- Sessions: real start and end times ----------
alter table public.sessions add column if not exists starts_at timestamptz;
alter table public.sessions add column if not exists ends_at timestamptz;
alter table public.sessions add column if not exists late_after_min integer not null default 10;
alter table public.sessions add column if not exists open_before_min integer not null default 5;
alter table public.sessions add column if not exists auto_open boolean not null default true;
alter table public.sessions add column if not exists changed_by text;

update public.sessions
   set starts_at = (date + split_part(time_label, ' – ', 1)::time) at time zone 'Africa/Windhoek',
       ends_at   = (date + split_part(time_label, ' – ', 2)::time) at time zone 'Africa/Windhoek'
 where starts_at is null and date is not null and time_label ~ '^\d\d:\d\d – \d\d:\d\d$';

-- Leftovers from earlier end-to-end test runs.
delete from public.sessions where id like 'E2E-%';

create index if not exists sessions_starts on public.sessions (starts_at);

-- ---------- Marked present by hand ----------
create table if not exists public.attendance_corrections (
  id bigint generated always as identity primary key,
  session_id text not null references public.sessions (id) on delete cascade,
  student_id text not null references public.students (id),
  reason text not null,
  note text,
  marked_by text not null,
  created_at timestamptz not null default now(),
  undone_at timestamptz
);

create index if not exists corrections_session on public.attendance_corrections (session_id);

-- ---------- Every tap, accepted or not (door quality, rejected taps) ----------
create table if not exists public.tap_attempts (
  id bigint generated always as identity primary key,
  ts timestamptz not null default now(),
  reader_id text,
  tag text,
  student_id text,
  session_id text,
  direction text,
  ok boolean not null,
  message text,
  source text
);

create index if not exists tap_attempts_ts on public.tap_attempts (ts desc);

-- ---------- Audit log ----------
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor text not null default 'System',
  action text not null,
  detail text
);

create index if not exists audit_log_at on public.audit_log (at desc);

-- ---------- record_tap: same rules, now also logs every attempt and marks the reader as seen ----------
create or replace function public.record_tap(
  p_tag text,
  p_direction text,
  p_reader_id text default null,
  p_session_id text default null,
  p_source text default 'browser'
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_student public.students;
  v_session public.sessions;
  v_matches integer;
  v_event_id bigint;
  v_dir text := upper(coalesce(p_direction, ''));
  v_source text := left(coalesce(nullif(p_source, ''), 'browser'), 40);
  v_result jsonb;
begin
  if coalesce(p_reader_id, '') <> '' then
    update public.readers set last_seen = now() where id = p_reader_id;
  end if;

  if v_dir not in ('IN', 'OUT') then
    v_result := jsonb_build_object('ok', false, 'message', 'Direction must be IN or OUT.');
  else
    select * into v_student from public.students where tag_id = p_tag or id = p_tag limit 1;
    if v_student.id is null then
      v_result := jsonb_build_object('ok', false, 'message', 'Unknown tag.');
    end if;
  end if;

  if v_result is null then
    if coalesce(p_session_id, '') <> '' then
      select * into v_session from public.sessions where id = p_session_id;
    else
      select count(*) into v_matches from public.sessions
        where reader_id = p_reader_id and status = 'open' and module = any (v_student.modules);
      if v_matches = 1 then
        select * into v_session from public.sessions
          where reader_id = p_reader_id and status = 'open' and module = any (v_student.modules);
      else
        v_result := jsonb_build_object('ok', false, 'message', case when v_matches = 0
          then 'No open session at this reader for this student.'
          else 'More than one open session at this reader.' end);
      end if;
    end if;
  end if;

  if v_result is null then
    if v_session.id is null then
      v_result := jsonb_build_object('ok', false, 'message', 'Session not found.');
    elsif not (v_session.module = any (v_student.modules)) then
      v_result := jsonb_build_object('ok', false, 'message', 'This student is not registered for the selected module.');
    elsif v_session.status <> 'open' then
      v_result := jsonb_build_object('ok', false, 'message', 'This session is not open. Tap rejected. No attendance recorded.');
    end if;
  end if;

  if v_result is null then
    perform pg_advisory_xact_lock(hashtext(v_session.id || '|' || v_student.id));
    if v_dir = 'OUT' and not exists (select 1 from public.attendance_events
        where session_id = v_session.id and student_id = v_student.id and direction = 'IN') then
      v_result := jsonb_build_object('ok', false, 'message', 'Tap OUT rejected. No earlier Tap IN exists.');
    else
      insert into public.attendance_events (session_id, student_id, direction, reader_id, source)
        values (v_session.id, v_student.id, v_dir, coalesce(nullif(p_reader_id, ''), v_session.reader_id), v_source)
        on conflict (session_id, student_id, direction) do nothing
        returning id into v_event_id;
      if v_event_id is null then
        v_result := jsonb_build_object('ok', false, 'message', format('Tap %s already recorded for this session.', v_dir));
      else
        v_result := jsonb_build_object(
          'ok', true,
          'message', format('%s: Tap %s recorded for %s.', v_student.name, v_dir, v_session.module),
          'event_id', v_event_id,
          'session_id', v_session.id,
          'student_id', v_student.id);
      end if;
    end if;
  end if;

  insert into public.tap_attempts (reader_id, tag, student_id, session_id, direction, ok, message, source)
    values (nullif(p_reader_id, ''), p_tag, v_student.id, v_session.id, v_dir, (v_result ->> 'ok')::boolean,
            v_result ->> 'message', v_source);
  return v_result;
end $$;

revoke execute on function public.record_tap(text, text, text, text, text) from public;
grant execute on function public.record_tap(text, text, text, text, text) to anon, authenticated, service_role;

-- ---------- The Unity lab hosts the virtual readers: while it sends telemetry, they are online ----------
create or replace function public.touch_virtual_readers() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.readers set last_seen = now()
   where is_virtual and (last_seen is null or last_seen < now() - interval '20 seconds');
  return new;
end $$;

drop trigger if exists jacket_status_touch_readers on public.jacket_status;
create trigger jacket_status_touch_readers after insert or update on public.jacket_status
  for each row execute function public.touch_virtual_readers();

-- ---------- Sessions open and close themselves ----------
-- Opens `open_before_min` before the start, closes at the end (only sessions opened inside their own time window,
-- so a lecturer can still open an old session by hand for a test). Runs every minute through pg_cron when the
-- project has it, and from every open Attendance desk page as a fallback.
create or replace function public.auto_sessions() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer := 0; m integer;
begin
  update public.sessions set status = 'open', opened_at = now(), changed_by = 'System'
   where status = 'scheduled' and auto_open and starts_at is not null and ends_at is not null
     and now() >= starts_at - make_interval(mins => open_before_min) and now() < ends_at;
  get diagnostics m = row_count; n := n + m;
  update public.sessions set status = 'closed', closed_at = now(), changed_by = 'System'
   where status = 'open' and auto_open and ends_at is not null and now() >= ends_at
     and opened_at is not null and opened_at <= ends_at;
  get diagnostics m = row_count; n := n + m;
  return n;
end $$;

grant execute on function public.auto_sessions() to anon, authenticated, service_role;

do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule(jobid) from cron.job where jobname = 'kinecto-auto-sessions';
  perform cron.schedule('kinecto-auto-sessions', '* * * * *', 'select public.auto_sessions()');
exception when others then
  raise notice 'pg_cron not available (%): sessions open and close from the Attendance desk page instead.', sqlerrm;
end $$;

-- ---------- Audit log, written by the database so it cannot be skipped ----------
create or replace function public.audit_sessions() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_log (actor, action, detail)
      values (coalesce(new.changed_by, 'System'), 'Session created',
              concat_ws(' · ', new.module || ' ' || coalesce(new.type, ''), new.room, to_char(new.starts_at at time zone 'Africa/Windhoek', 'DD Mon HH24:MI')));
  elsif new.status is distinct from old.status and new.status in ('open', 'closed') then
    insert into public.audit_log (actor, action, detail)
      values (coalesce(new.changed_by, 'System'), case new.status when 'open' then 'Session opened' else 'Session closed' end,
              concat_ws(' · ', new.module || ' ' || coalesce(new.type, ''), new.room,
                        case when coalesce(new.changed_by, 'System') = 'System' then 'by itself' end));
  end if;
  return new;
end $$;

drop trigger if exists sessions_audit on public.sessions;
create trigger sessions_audit after insert or update on public.sessions
  for each row execute function public.audit_sessions();

create or replace function public.audit_corrections() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_name text; v_module text;
begin
  select name into v_name from public.students where id = new.student_id;
  select module into v_module from public.sessions where id = new.session_id;
  if tg_op = 'INSERT' then
    insert into public.audit_log (actor, action, detail)
      values (new.marked_by, 'Marked by hand', concat_ws(' · ', v_name, v_module, new.reason));
  elsif new.undone_at is not null and old.undone_at is null then
    insert into public.audit_log (actor, action, detail)
      values (new.marked_by, 'Undo', concat_ws(' · ', 'Undid a manual mark', v_name, v_module));
  end if;
  return new;
end $$;

drop trigger if exists corrections_audit on public.attendance_corrections;
create trigger corrections_audit after insert or update on public.attendance_corrections
  for each row execute function public.audit_corrections();

create or replace function public.audit_staff() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_log (actor, action, detail)
      values (coalesce(new.changed_by, 'System'), 'Person added', new.email || ' → ' || initcap(new.role));
  elsif new.role is distinct from old.role then
    insert into public.audit_log (actor, action, detail)
      values (coalesce(new.changed_by, 'System'), 'Role change', new.email || ' → ' || initcap(new.role));
  end if;
  return new;
end $$;

drop trigger if exists staff_audit on public.staff;
create trigger staff_audit after insert or update on public.staff
  for each row execute function public.audit_staff();

create or replace function public.audit_readers() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_log (actor, action, detail)
    values (new.added_by, 'Reader added', concat_ws(' · ', new.id, new.room_id, 'firmware ' || new.firmware));
  return new;
end $$;

drop trigger if exists readers_audit on public.readers;
create trigger readers_audit after insert on public.readers
  for each row execute function public.audit_readers();

-- ---------- Row level security (demo policies) ----------
alter table public.rooms enable row level security;
alter table public.readers enable row level security;
alter table public.staff enable row level security;
alter table public.courses enable row level security;
alter table public.attendance_corrections enable row level security;
alter table public.tap_attempts enable row level security;
alter table public.audit_log enable row level security;

create policy "demo read" on public.rooms for select to anon, authenticated using (true);
create policy "demo insert" on public.rooms for insert to anon, authenticated with check (true);
create policy "demo update" on public.rooms for update to anon, authenticated using (true) with check (true);

create policy "demo read" on public.readers for select to anon, authenticated using (true);
create policy "demo insert" on public.readers for insert to anon, authenticated with check (true);
create policy "demo update" on public.readers for update to anon, authenticated using (true) with check (true);

create policy "demo read" on public.staff for select to anon, authenticated using (true);
create policy "demo insert" on public.staff for insert to anon, authenticated with check (true);
create policy "demo update" on public.staff for update to anon, authenticated using (true) with check (true);

create policy "demo read" on public.courses for select to anon, authenticated using (true);
create policy "demo insert" on public.courses for insert to anon, authenticated with check (true);
create policy "demo update" on public.courses for update to anon, authenticated using (true) with check (true);

create policy "demo read" on public.attendance_corrections for select to anon, authenticated using (true);
create policy "demo insert" on public.attendance_corrections for insert to anon, authenticated with check (true);
create policy "demo update" on public.attendance_corrections for update to anon, authenticated using (true) with check (true);
revoke update on public.attendance_corrections from anon, authenticated;
grant update (undone_at) on public.attendance_corrections to anon, authenticated;

-- Taps are logged only by record_tap; the audit log only grows.
create policy "demo read" on public.tap_attempts for select to anon, authenticated using (true);
create policy "demo read" on public.audit_log for select to anon, authenticated using (true);
create policy "demo insert" on public.audit_log for insert to anon, authenticated with check (true);
revoke update, delete on public.audit_log from anon, authenticated;

-- ---------- Realtime ----------
alter publication supabase_realtime add table
  public.rooms, public.readers, public.staff, public.courses,
  public.attendance_corrections, public.tap_attempts, public.audit_log;

-- ---------- Mock seed data (no audit rows for the seed itself) ----------
alter table public.sessions disable trigger sessions_audit;
alter table public.staff disable trigger staff_audit;
alter table public.readers disable trigger readers_audit;

insert into public.rooms (id, name, building, seats, access) values
  ('E201', 'E201', 'Engineering', 120, 'Ramp at the main entrance'),
  ('E105', 'E105', 'Engineering', 60, 'Lift to ground floor'),
  ('FabLab', 'FabLab', 'Engineering', 34, 'Ground floor, wide doors'),
  ('B07', 'B07', 'Business', 140, 'Ground floor'),
  ('L1', 'L1', 'Library', 40, 'Lift'),
  ('A12', 'A12', 'Auditorium', 400, 'Ramp at the side door')
on conflict (id) do nothing;

insert into public.readers (id, room_id, door, is_virtual, added_by) values
  ('E201-SIM', 'E201', 'Main door (Unity Virtual Lab)', true, 'System'),
  ('E105-A', 'E105', 'Door 1', false, 'System'),
  ('FL-01', 'FabLab', 'Main door', false, 'System'),
  ('B07-A', 'B07', 'Front door', false, 'System')
on conflict (id) do nothing;

insert into public.staff (id, name, email, role) values
  ('ST-001', 'Dr M. Kandjii', 'm.kandjii@nust.na', 'lecturer'),
  ('ST-002', 'P. Shikongo', 'p.shikongo@nust.na', 'admin'),
  ('ST-003', 'Ms T. Ndeutapo', 't.ndeutapo@nust.na', 'lecturer'),
  ('ST-004', 'EPH tutor', 'tutor.eph@nust.na', 'assistant')
on conflict (id) do nothing;

insert into public.courses (code, title, faculty, lecturer_id) values
  ('EPH810S', 'Emerging Practices in HCI', 'Computing & Informatics', 'ST-001'),
  ('EPH710S', 'Interaction Design Studio', 'Computing & Informatics', 'ST-001'),
  ('EPH620S', 'Design Seminar', 'Computing & Informatics', 'ST-001'),
  ('CSI521S', 'Computer Science Lab', 'Computing & Informatics', 'ST-003')
on conflict (code) do nothing;

-- Fictional names for the mock IDs (MOCK-0187 is the Unity student).
update public.students s set name = v.name from (values
  ('MOCK-0187', 'J. Amupolo'), ('MOCK-0241', 'N. Shipanga'), ('MOCK-0316', 'M. Katjiuongua'),
  ('MOCK-0428', 'T. Haufiku'), ('MOCK-0572', 'L. Nghipandulwa'), ('MOCK-0639', 'S. Iipumbu')) as v(id, name)
 where s.id = v.id and s.name like 'Student %';

insert into public.students (id, name, tag_id, modules) values
  ('MOCK-0701', 'P. Garises', 'MOCK-TAG-0701', '{EPH810S,EPH620S}'),
  ('MOCK-0702', 'A. Nakale', 'MOCK-TAG-0702', '{EPH810S}'),
  ('MOCK-0703', 'K. Uushona', 'MOCK-TAG-0703', '{EPH810S,EPH710S}'),
  ('MOCK-0704', 'R. Mbango', 'MOCK-TAG-0704', '{EPH810S}'),
  ('MOCK-0705', 'H. Nangolo', 'MOCK-TAG-0705', '{EPH810S,EPH620S}'),
  ('MOCK-0706', 'E. Kambonde', 'MOCK-TAG-0706', '{EPH810S}'),
  ('MOCK-0707', 'V. Tjiueza', 'MOCK-TAG-0707', '{EPH810S,EPH710S}'),
  ('MOCK-0708', 'T. Amukoto', 'MOCK-TAG-0708', '{EPH810S}'),
  ('MOCK-0709', 'J. Hamutenya', 'MOCK-TAG-0709', '{EPH810S,EPH620S}'),
  ('MOCK-0710', 'K. Nghidinwa', 'MOCK-TAG-0710', '{EPH710S,EPH620S}'),
  ('MOCK-0711', 'F. Shilongo', 'MOCK-TAG-0711', '{EPH810S}'),
  ('MOCK-0712', 'D. Gawanab', 'MOCK-TAG-0712', '{EPH810S,EPH710S}'),
  ('MOCK-0713', 'M. Hoabeb', 'MOCK-TAG-0713', '{EPH810S}'),
  ('MOCK-0714', 'B. Tjihero', 'MOCK-TAG-0714', '{EPH810S,EPH620S}'),
  ('MOCK-0715', 'L. Kandjeke', 'MOCK-TAG-0715', '{EPH810S}'),
  ('MOCK-0716', 'S. Mwafufya', 'MOCK-TAG-0716', '{EPH710S}'),
  ('MOCK-0717', 'C. Beukes', 'MOCK-TAG-0717', '{EPH810S}'),
  ('MOCK-0718', 'G. Hangula', 'MOCK-TAG-0718', '{EPH810S,EPH710S}')
on conflict (id) do nothing;

-- Six weeks of timetable from this week (Windhoek time). The EPH810S lecture runs every weekday in E201,
-- the room with the Unity door reader, so the lab always has a session to tap into.
insert into public.sessions (id, module, title, type, room, reader_id, time_label, date, starts_at, ends_at, changed_by)
select t.module || '-' || upper(left(t.type, 4)) || '-' || to_char(d, 'YYYYMMDD') || '-' || replace(t.s, ':', ''),
       t.module, c.title, t.type, t.room, t.reader, t.s || ' – ' || t.e, d,
       (d + t.s::time) at time zone 'Africa/Windhoek', (d + t.e::time) at time zone 'Africa/Windhoek', 'System'
  from generate_series(0, 5) w
  cross join (values
    (0, 'EPH810S', 'Tutorial', '08:00', '09:50', 'E105', 'E105-A'),
    (2, 'EPH810S', 'Tutorial', '08:00', '09:50', 'E105', 'E105-A'),
    (0, 'EPH810S', 'Lecture', '10:00', '12:00', 'E201', 'E201-SIM'),
    (1, 'EPH810S', 'Lecture', '10:00', '12:00', 'E201', 'E201-SIM'),
    (2, 'EPH810S', 'Lecture', '10:00', '12:00', 'E201', 'E201-SIM'),
    (3, 'EPH810S', 'Lecture', '10:00', '12:00', 'E201', 'E201-SIM'),
    (4, 'EPH810S', 'Lecture', '10:00', '12:00', 'E201', 'E201-SIM'),
    (1, 'EPH710S', 'Lab', '14:00', '16:00', 'FabLab', 'FL-01'),
    (3, 'EPH710S', 'Lab', '14:00', '16:00', 'FabLab', 'FL-01'),
    (4, 'EPH620S', 'Seminar', '08:00', '09:50', 'B07', 'B07-A')
  ) as t(dow, module, type, s, e, room, reader)
  cross join lateral (select (date_trunc('week', (now() at time zone 'Africa/Windhoek'))::date + w * 7 + t.dow) as d) dd
  join public.courses c on c.code = t.module
on conflict (id) do nothing;

-- Old seed rows (fixed date, no reader schedule) are replaced by the timetable above.
delete from public.sessions where id in ('EPH810S-LECT-01', 'EPH810S-TUT-01', 'EPH710S-LAB-01')
  and not exists (select 1 from public.attendance_events e where e.session_id = sessions.id);

alter table public.sessions enable trigger sessions_audit;
alter table public.staff enable trigger staff_audit;
alter table public.readers enable trigger readers_audit;

insert into public.audit_log (actor, action, detail)
  values ('System', 'Desk set up', 'Rooms, readers, staff, courses and six weeks of timetable added');
