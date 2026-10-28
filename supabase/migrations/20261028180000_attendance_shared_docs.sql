-- Attendance website: everything that used to live in one browser's localStorage is shared here, so every
-- lecturer, student and admin device sees the same data live (Realtime).
--   whole documents (key '*'): rooms, readers, users, courses, courseTitles, settings
--   one row per item:          queries (student messages + replies), corrections, audit, lateTapReviews
-- Sessions and taps keep their own tables and the record_tap rules.
-- MOCK DATA ONLY: same open demo policies as the rest of the prototype.

create table public.attendance_docs (
  collection text not null check (collection in ('rooms', 'readers', 'users', 'courses', 'courseTitles', 'settings',
                                                 'queries', 'corrections', 'audit', 'lateTapReviews')),
  key text not null,
  doc jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (collection, key)
);

create trigger attendance_docs_touch before update on public.attendance_docs
  for each row execute function public.touch_updated_at();

alter table public.attendance_docs enable row level security;
create policy "demo read" on public.attendance_docs for select to anon, authenticated using (true);
create policy "demo insert" on public.attendance_docs for insert to anon, authenticated with check (true);
create policy "demo update" on public.attendance_docs for update to anon, authenticated using (true) with check (true);

-- students too, so a roster change reaches open pages without a reload.
alter publication supabase_realtime add table public.attendance_docs, public.students;
