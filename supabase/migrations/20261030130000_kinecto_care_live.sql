-- Kinecto Care (the jacket app): wearer sign-in, jacket history for the charts, and the notification feed.
-- Everything the app shows comes from these tables, filled live by the Unity Virtual Lab jacket.

-- ---------- 1. Wearers: which NUST email signs in, which jacket is theirs ----------
alter table public.students add column if not exists email text;
alter table public.students add column if not exists jacket_id text;

-- "J. Amupolo" -> j.amupolo@nust.na (mock students only)
update public.students
set email = lower(regexp_replace(regexp_replace(name, '\s+', '', 'g'), '[^A-Za-z.]', '', 'g')) || '@nust.na'
where email is null;

create index if not exists students_email on public.students (lower(email));

-- The Unity avatar wears the Virtual Lab jacket.
update public.students set jacket_id = 'KC-SIM-0001' where id = 'MOCK-0187' and jacket_id is null;

-- ---------- 2. Jacket history: one sample every 10 s while the jacket reports ----------
create table if not exists public.jacket_samples (
  id bigint generated always as identity primary key,
  jacket_id text not null,
  ts timestamptz not null default now(),
  body_c real,
  ambient_c real,
  mode text,
  heater_on boolean,
  blower_on boolean,
  buffer_pct real,
  buffer_v real,
  harvested_mj real,
  battery_pct real,
  battery_temp_c real,
  cuff_tag_ok boolean,
  activity text
);
create index if not exists jacket_samples_jacket_ts on public.jacket_samples (jacket_id, ts desc);

create or replace function public.sample_jacket_status() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.jacket_samples
                 where jacket_id = new.jacket_id and ts > now() - interval '10 seconds') then
    insert into public.jacket_samples (jacket_id, body_c, ambient_c, mode, heater_on, blower_on, buffer_pct, buffer_v,
                                       harvested_mj, battery_pct, battery_temp_c, cuff_tag_ok, activity)
    values (new.jacket_id, new.body_c, new.ambient_c, new.mode, new.heater_on, new.blower_on, new.buffer_pct, new.buffer_v,
            new.harvested_mj, new.battery_pct, new.battery_temp_c, new.cuff_tag_ok, new.activity);
    -- keep about a month
    if random() < 0.002 then
      delete from public.jacket_samples where ts < now() - interval '35 days';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists jacket_status_sample on public.jacket_status;
create trigger jacket_status_sample after insert or update on public.jacket_status
  for each row execute function public.sample_jacket_status();

-- Hourly or daily totals for the Energy and Comfort charts (Windhoek time).
-- Each sample counts until the next one, at most 30 s, so gaps while Unity is stopped add nothing.
-- harvested_mj is a running total in the lab; when Unity restarts it starts again from 0.
create or replace function public.jacket_buckets(p_jacket text, p_from timestamptz, p_bucket text default 'hour')
returns table (bucket timestamptz, harvest_mj real, walk_min real, heater_min real, blower_min real,
               inside_c real, outside_c real, battery_pct real, samples int)
language sql stable security definer set search_path = public as $$
  with s as (
    select ts, body_c, ambient_c, heater_on, blower_on, battery_pct, activity, harvested_mj,
           least(coalesce(extract(epoch from (lead(ts) over w - ts)), 0), 30) as dt,
           harvested_mj - lag(harvested_mj) over w as dh
    from public.jacket_samples
    where jacket_id = p_jacket and ts >= p_from - interval '1 minute'
    window w as (order by ts)
  )
  select date_trunc(case when p_bucket = 'day' then 'day' else 'hour' end, ts at time zone 'Africa/Windhoek')
           at time zone 'Africa/Windhoek' as bucket,
         sum(greatest(case when dh < 0 then coalesce(harvested_mj, 0) else coalesce(dh, 0) end, 0))::real,
         (sum(case when activity in ('walk', 'run', 'brisk') then dt else 0 end) / 60)::real,
         (sum(case when heater_on then dt else 0 end) / 60)::real,
         (sum(case when blower_on then dt else 0 end) / 60)::real,
         avg(body_c)::real, avg(ambient_c)::real, avg(battery_pct)::real, count(*)::int
  from s
  where ts >= p_from
  group by 1
  order by 1;
$$;
grant execute on function public.jacket_buckets(text, timestamptz, text) to anon, authenticated;

-- ---------- 3. Notifications: what happened to the jacket, newest first in the app ----------
create table if not exists public.jacket_events (
  id bigint generated always as identity primary key,
  jacket_id text not null,
  ts timestamptz not null default now(),
  kind text not null check (kind in ('fault_opened', 'fault_fixed', 'comfort_synced', 'tap')),
  code text,          -- fault code, comfort mode, or tap direction
  detail text
);
create index if not exists jacket_events_jacket_ts on public.jacket_events (jacket_id, ts desc);

create or replace function public.events_from_faults() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.jacket_events (jacket_id, kind, code, detail) values (new.jacket_id, 'fault_opened', new.code, new.source);
  elsif new.status = 'fixed' and old.status <> 'fixed' then
    insert into public.jacket_events (jacket_id, kind, code, detail) values (new.jacket_id, 'fault_fixed', new.code, null);
  end if;
  return new;
end $$;
drop trigger if exists faults_events on public.faults;
create trigger faults_events after insert or update on public.faults
  for each row execute function public.events_from_faults();

create or replace function public.events_from_comfort() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.mode is distinct from old.mode or new.warm_below_c is distinct from old.warm_below_c
     or new.cool_above_c is distinct from old.cool_above_c then
    insert into public.jacket_events (jacket_id, kind, code, detail)
    values (new.jacket_id, 'comfort_synced', new.mode,
            format('%s–%s °C · changed on the %s', new.warm_below_c, new.cool_above_c,
                   case when new.updated_by = 'jacket' then 'jacket' else 'app' end));
  end if;
  return new;
end $$;
drop trigger if exists comfort_events on public.comfort_settings;
create trigger comfort_events after update on public.comfort_settings
  for each row execute function public.events_from_comfort();

create or replace function public.events_from_taps() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_jacket text; v_module text; v_room text;
begin
  select jacket_id into v_jacket from public.students where id = new.student_id;
  if v_jacket is null then return new; end if;
  select module, room into v_module, v_room from public.sessions where id = new.session_id;
  insert into public.jacket_events (jacket_id, kind, code, detail)
  values (v_jacket, 'tap', new.direction, concat_ws(' · ', v_module, 'Room ' || v_room));
  return new;
end $$;
drop trigger if exists attendance_events_feed on public.attendance_events;
create trigger attendance_events_feed after insert on public.attendance_events
  for each row execute function public.events_from_taps();

-- ---------- 4. Access (demo policies, mock data only) and Realtime ----------
alter table public.jacket_samples enable row level security;
alter table public.jacket_events enable row level security;
drop policy if exists "demo read" on public.jacket_samples;
create policy "demo read" on public.jacket_samples for select to anon, authenticated using (true);
drop policy if exists "demo read" on public.jacket_events;
create policy "demo read" on public.jacket_events for select to anon, authenticated using (true);
grant select on public.jacket_samples, public.jacket_events to anon, authenticated;

do $$
begin
  begin alter publication supabase_realtime add table public.jacket_samples; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.jacket_events; exception when duplicate_object then null; end;
end $$;
