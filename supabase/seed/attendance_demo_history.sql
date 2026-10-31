-- Kinecto Attendance: optional demo history (mock students only).
--
-- The timetable from 20261030100000_attendance_desk.sql starts this week, so the
-- Reports, Student detail and Campus report charts have almost nothing to show yet.
-- This script adds the five teaching weeks before it and fills them, plus this
-- week's sessions that already ended without being opened, with taps worked out
-- per student. Everything goes into the normal tables, so every chart on the site
-- is calculated from it the same way as from live Unity taps.
--
-- Run it once in the Supabase SQL Editor. Run it again to start over: it first
-- removes everything it made before (source = 'Demo history').
-- It never touches sessions that are open now, or taps from Unity.

begin;

alter table public.sessions disable trigger sessions_audit;
alter table public.attendance_corrections disable trigger corrections_audit;

-- 1. remove an earlier run
delete from public.audit_log where actor = 'Demo history';
delete from public.tap_attempts where source = 'Demo history';
delete from public.attendance_corrections where marked_by = 'Demo history';
delete from public.attendance_events where source = 'Demo history';
delete from public.sessions where changed_by = 'Demo history';
update public.sessions set status = 'scheduled', opened_at = null, closed_at = null
  where changed_by = 'Demo history closed';
update public.sessions set changed_by = null where changed_by = 'Demo history closed';

-- 2. five earlier weeks, copied from this week's timetable
insert into public.sessions (id, module, title, type, room, reader_id, time_label, date, status,
                             starts_at, ends_at, late_after_min, open_before_min, auto_open, changed_by)
select regexp_replace(s.id, '\d{8}', to_char((s.starts_at - make_interval(weeks => w)) at time zone 'Africa/Windhoek', 'YYYYMMDD')),
       s.module, s.title, s.type, s.room, s.reader_id, s.time_label,
       ((s.starts_at - make_interval(weeks => w)) at time zone 'Africa/Windhoek')::date,
       'scheduled', s.starts_at - make_interval(weeks => w), s.ends_at - make_interval(weeks => w),
       s.late_after_min, s.open_before_min, s.auto_open, 'Demo history'
from public.sessions s
cross join generate_series(1, 5) as w
where s.starts_at >= date_trunc('week', now() at time zone 'Africa/Windhoek') at time zone 'Africa/Windhoek'
  and s.starts_at <  (date_trunc('week', now() at time zone 'Africa/Windhoek') + interval '7 days') at time zone 'Africa/Windhoek'
on conflict (id) do nothing;

-- this week's sessions that ended before anybody opened them
update public.sessions set changed_by = 'Demo history closed'
where status = 'scheduled' and ends_at < now() and changed_by is distinct from 'Demo history'
  and opened_at is null;

-- 3. every student gets a steady habit, so a few end up below 75%
create temporary table demo_habit on commit drop as
select id as student_id,
       0.97 - (abs(hashtext(id || 'kinecto')) % 45) / 100.0 as p_attend,   -- 0.53 .. 0.97
       (abs(hashtext(id || 'late')) % 25) / 100.0              as p_late,   -- 0 .. 0.24
       tag_id
from public.students;

create temporary table demo_sessions on commit drop as
select * from public.sessions
where changed_by in ('Demo history', 'Demo history closed');

-- 4. taps IN (on time or late) and most taps OUT
create temporary table demo_taps on commit drop as
select ds.id as session_id, ds.reader_id, h.student_id, h.tag_id,
       case when random() < h.p_late
            then ds.starts_at + make_interval(mins => ds.late_after_min + 1 + floor(random() * 25)::int)
            else ds.starts_at - make_interval(mins => floor(random() * ds.open_before_min)::int) + make_interval(secs => floor(random() * (ds.late_after_min * 60))::int)
       end as t_in,
       ds.ends_at - make_interval(mins => floor(random() * 8)::int) as t_out,
       random() < 0.75 as taps_out
from demo_sessions ds
join public.students st on ds.module = any (st.modules)
join demo_habit h on h.student_id = st.id
where random() + 0 * extract(epoch from ds.starts_at) < h.p_attend;   -- per student AND per session

insert into public.attendance_events (session_id, student_id, direction, reader_id, source, ts)
select session_id, student_id, 'IN', reader_id, 'Demo history', t_in from demo_taps
union all
select session_id, student_id, 'OUT', reader_id, 'Demo history', t_out from demo_taps where taps_out;

insert into public.tap_attempts (ts, reader_id, tag, student_id, session_id, direction, ok, message, source)
select t_in, reader_id, tag_id, student_id, session_id, 'IN', true, 'Tap IN recorded.', 'Demo history' from demo_taps
union all
select t_out, reader_id, tag_id, student_id, session_id, 'OUT', true, 'Tap OUT recorded.', 'Demo history' from demo_taps where taps_out
union all  -- a second tap at the door now and then
select t_in + interval '20 seconds', reader_id, tag_id, student_id, session_id, 'IN', false, 'Tap IN already recorded for this session.', 'Demo history'
from demo_taps where random() < 0.06
union all  -- a cuff that could not be read
select ds.starts_at + make_interval(mins => floor(random() * 10)::int), ds.reader_id, 'UNREADABLE', null, null, 'IN', false, 'Unknown tag.', 'Demo history'
from demo_sessions ds where random() < 0.35;

-- 5. a lecturer marked a few missed taps by hand
insert into public.attendance_corrections (session_id, student_id, reason, note, marked_by, created_at)
select ds.id, st.id,
       (array['Cuff not read at the door', 'Showed the app alert', 'Came in with the lecturer'])[1 + floor(random() * 3)::int],
       null, 'Demo history', ds.starts_at + interval '15 minutes'
from demo_sessions ds
join public.students st on ds.module = any (st.modules)
where random() + 0 * extract(epoch from ds.starts_at) + 0 * length(st.id) < 0.03
  and not exists (select 1 from demo_taps t where t.session_id = ds.id and t.student_id = st.id);

-- 6. close them
update public.sessions s set status = 'closed',
       opened_at = s.starts_at - make_interval(mins => s.open_before_min),
       closed_at = s.ends_at
where s.changed_by in ('Demo history', 'Demo history closed');

alter table public.sessions enable trigger sessions_audit;
alter table public.attendance_corrections enable trigger corrections_audit;

insert into public.audit_log (actor, action, detail)
values ('Demo history', 'Demo history loaded',
        (select count(*) || ' closed sessions with mock taps' from public.sessions where changed_by in ('Demo history', 'Demo history closed')));

commit;
