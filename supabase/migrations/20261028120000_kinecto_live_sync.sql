-- Kinecto shared backend: one Supabase project links the Unity Virtual Lab, Kinecto Care and the Attendance website.
-- Unity writes through the Edge Functions (device keys). The two apps read and write here and get live updates
-- through Supabase Realtime.
--
-- MOCK DATA ONLY. The open "demo" policies let the browser and the phone app work with the publishable key and
-- no sign-in. Replace them with Supabase Auth roles before any real student or wearer data goes in.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ---------- Devices: the virtual jacket and the door readers ----------
-- Keys are stored only as sha256 hex. The Edge Functions hash the x-device-key / x-reader-key header and compare.
create table public.devices (
  id text primary key,
  kind text not null check (kind in ('jacket', 'reader')),
  key_hash text not null,
  label text
);

-- ---------- Jacket: latest telemetry, comfort settings, faults ----------
create table public.jacket_status (
  jacket_id text primary key,
  ts timestamptz,
  is_virtual boolean not null default true,
  body_c real,                       -- inside microclimate; null while the inside sensor is silent
  ambient_c real,
  mode text not null default 'auto' check (mode in ('auto', 'cool', 'warm', 'off')),
  heater_on boolean not null default false,
  blower_on boolean not null default false,
  blower_ma real,
  buffer_v real,
  buffer_pct real,
  harvested_mj real,
  battery_pct real,
  battery_temp_c real,
  cuff_tag_ok boolean not null default true,
  activity text,
  fault_flags text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table public.comfort_settings (
  jacket_id text primary key,
  mode text not null default 'auto' check (mode in ('auto', 'cool', 'warm', 'off')),
  warm_below_c integer not null default 19,
  cool_above_c integer not null default 26,
  prewarm_enabled boolean not null default false,
  prewarm_at time not null default '07:30',
  updated_by text not null default 'app' check (updated_by in ('app', 'jacket')),
  updated_at timestamptz not null default now(),
  -- same bounds as app/lib/features/comfort/domain/comfort_limits.dart
  constraint comfort_range check (warm_below_c >= 18 and cool_above_c <= 28 and cool_above_c - warm_below_c >= 2)
);

create trigger comfort_settings_touch before update on public.comfort_settings
  for each row execute function public.touch_updated_at();

create sequence public.fault_seq;

create table public.faults (
  id text primary key default 'F-' || lpad(nextval('public.fault_seq')::text, 4, '0'),
  jacket_id text not null,
  -- same IDs as the jacket fault_flags, FaultCode in the app and the fault engine
  code text not null check (code in ('body_sensor_offline', 'heater_over_limit', 'blower_current_spike',
                                     'buffer_not_charging', 'battery_hot', 'cuff_tag_unreadable')),
  status text not null default 'open' check (status in ('open', 'watch', 'fixed')),
  source text not null default 'jacket' check (source in ('jacket', 'kinecto_check')),
  detected_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index faults_jacket_detected on public.faults (jacket_id, detected_at desc);

-- ---------- Attendance ----------
create table public.students (
  id text primary key,
  name text not null,
  tag_id text not null unique,
  modules text[] not null default '{}'
);

create table public.sessions (
  id text primary key,
  module text not null,
  title text,
  type text,
  room text,
  reader_id text,
  time_label text,
  date date,
  status text not null default 'scheduled' check (status in ('scheduled', 'open', 'closed')),
  opened_at timestamptz,
  closed_at timestamptz,
  updated_at timestamptz not null default now()
);

create trigger sessions_touch before update on public.sessions
  for each row execute function public.touch_updated_at();

create table public.attendance_events (
  id bigint generated always as identity primary key,
  session_id text not null references public.sessions (id) on delete cascade,
  student_id text not null references public.students (id),
  direction text not null check (direction in ('IN', 'OUT')),
  reader_id text,
  source text not null default 'browser',
  ts timestamptz not null default now(),
  unique (session_id, student_id, direction)
);

-- Every tap (Unity reader, browser Tap Station) goes through this one rule set, so all screens agree.
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
begin
  if v_dir not in ('IN', 'OUT') then
    return jsonb_build_object('ok', false, 'message', 'Direction must be IN or OUT.');
  end if;

  select * into v_student from public.students where tag_id = p_tag or id = p_tag limit 1;
  if v_student.id is null then
    return jsonb_build_object('ok', false, 'message', 'Unknown tag.');
  end if;

  if coalesce(p_session_id, '') <> '' then
    select * into v_session from public.sessions where id = p_session_id;
  else
    -- No session given (door reader): the reader's one open session for this student's modules.
    select count(*) into v_matches from public.sessions
      where reader_id = p_reader_id and status = 'open' and module = any (v_student.modules);
    if v_matches <> 1 then
      return jsonb_build_object('ok', false, 'message', case when v_matches = 0
        then 'No open session at this reader for this student.'
        else 'More than one open session at this reader.' end);
    end if;
    select * into v_session from public.sessions
      where reader_id = p_reader_id and status = 'open' and module = any (v_student.modules);
  end if;

  if v_session.id is null then
    return jsonb_build_object('ok', false, 'message', 'Session not found.');
  end if;
  if not (v_session.module = any (v_student.modules)) then
    return jsonb_build_object('ok', false, 'message', 'This student is not registered for the selected module.');
  end if;
  if v_session.status <> 'open' then
    return jsonb_build_object('ok', false, 'message', 'This session is not open. Tap rejected. No attendance recorded.');
  end if;

  perform pg_advisory_xact_lock(hashtext(v_session.id || '|' || v_student.id));

  if v_dir = 'OUT' and not exists (select 1 from public.attendance_events
      where session_id = v_session.id and student_id = v_student.id and direction = 'IN') then
    return jsonb_build_object('ok', false, 'message', 'Tap OUT rejected. No earlier Tap IN exists.');
  end if;

  insert into public.attendance_events (session_id, student_id, direction, reader_id, source)
    values (v_session.id, v_student.id, v_dir, coalesce(nullif(p_reader_id, ''), v_session.reader_id),
            left(coalesce(nullif(p_source, ''), 'browser'), 40))
    on conflict (session_id, student_id, direction) do nothing
    returning id into v_event_id;

  if v_event_id is null then
    return jsonb_build_object('ok', false, 'message', format('Tap %s already recorded for this session.', v_dir));
  end if;

  return jsonb_build_object(
    'ok', true,
    'message', format('%s: Tap %s recorded for %s.', v_student.name, v_dir, v_session.module),
    'event_id', v_event_id,
    'session_id', v_session.id,
    'student_id', v_student.id);
end $$;

revoke execute on function public.record_tap(text, text, text, text, text) from public;
grant execute on function public.record_tap(text, text, text, text, text) to anon, authenticated, service_role;

-- ---------- Row level security (demo policies, see note at the top) ----------
alter table public.devices enable row level security;           -- no policies: Edge Functions only
alter table public.jacket_status enable row level security;
alter table public.comfort_settings enable row level security;
alter table public.faults enable row level security;
alter table public.students enable row level security;
alter table public.sessions enable row level security;
alter table public.attendance_events enable row level security;

revoke all on public.devices from anon, authenticated;

create policy "demo read" on public.jacket_status for select to anon, authenticated using (true);

create policy "demo read" on public.comfort_settings for select to anon, authenticated using (true);
create policy "demo update" on public.comfort_settings for update to anon, authenticated using (true) with check (true);
revoke insert, update, delete on public.comfort_settings from anon, authenticated;
grant update (mode, warm_below_c, cool_above_c, prewarm_enabled, prewarm_at, updated_by)
  on public.comfort_settings to anon, authenticated;

create policy "demo read" on public.faults for select to anon, authenticated using (true);
create policy "demo update" on public.faults for update to anon, authenticated using (true) with check (true);
revoke insert, update, delete on public.faults from anon, authenticated;
grant update (status, resolved_at) on public.faults to anon, authenticated;

create policy "demo read" on public.students for select to anon, authenticated using (true);

create policy "demo read" on public.sessions for select to anon, authenticated using (true);
create policy "demo insert" on public.sessions for insert to anon, authenticated with check (true);
create policy "demo update" on public.sessions for update to anon, authenticated using (true) with check (true);

-- Taps are written only through record_tap.
create policy "demo read" on public.attendance_events for select to anon, authenticated using (true);

-- ---------- Realtime: these tables push changes to every open app ----------
alter publication supabase_realtime add table
  public.jacket_status, public.comfort_settings, public.faults, public.sessions, public.attendance_events;

-- ---------- Mock seed data (same IDs as the Unity lab, the app mocks and attendance/app.js) ----------
insert into public.jacket_status (jacket_id, is_virtual, body_c, ambient_c, battery_pct, buffer_pct, cuff_tag_ok)
  values ('KC-SIM-0001', true, 24.0, 22.0, 92, 64, true);

insert into public.comfort_settings (jacket_id) values ('KC-SIM-0001');

insert into public.students (id, name, tag_id, modules) values
  ('MOCK-0187', 'Student MOCK-0187', 'MOCK-TAG-0187', '{EPH810S,EPH710S}'),
  ('MOCK-0241', 'Student MOCK-0241', 'MOCK-TAG-0241', '{EPH810S}'),
  ('MOCK-0316', 'Student MOCK-0316', 'MOCK-TAG-0316', '{EPH810S}'),
  ('MOCK-0428', 'Student MOCK-0428', 'MOCK-TAG-0428', '{EPH710S}'),
  ('MOCK-0572', 'Student MOCK-0572', 'MOCK-TAG-0572', '{EPH810S}'),
  ('MOCK-0639', 'Student MOCK-0639', 'MOCK-TAG-0639', '{EPH810S}');

insert into public.sessions (id, module, title, type, room, reader_id, time_label, date) values
  ('EPH810S-LECT-01', 'EPH810S', 'Emerging Practices in HCI', 'Lecture', 'E201', 'E201-SIM', '10:00 – 12:00', current_date),
  ('EPH810S-TUT-01', 'EPH810S', 'Emerging Practices in HCI', 'Tutorial', 'E105', 'E105-A', '08:00 – 09:50', current_date),
  ('EPH710S-LAB-01', 'EPH710S', 'Interaction Design Studio', 'Lab', 'FabLab', 'FL-01', '14:00 – 16:00', null);
