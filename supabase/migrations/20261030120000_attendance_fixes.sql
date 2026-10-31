-- Kinecto Attendance fixes after the first live test (30 Oct).

-- The seeded teaching assistant had no courses, so their Today, Sessions and
-- Register pages were empty. Admins can change this on Roles & access.
update public.staff
set settings = coalesce(settings, '{}'::jsonb) || jsonb_build_object('courses', jsonb_build_array('EPH810S', 'EPH710S'))
where id = 'ST-004' and not (coalesce(settings, '{}'::jsonb) ? 'courses');
