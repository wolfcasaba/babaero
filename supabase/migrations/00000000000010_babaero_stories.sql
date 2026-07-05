-- Stories: 24h ephemeral photo updates (Instagram/FB-style). A big daily-open
-- and retention driver. The 24h window is enforced at read time (created_at >
-- now() - 24h), so nothing needs a scheduled cleaner. Additive.

create table if not exists babaero.stories (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid not null references auth.users (id) on delete cascade,
  image_url  text not null,
  caption    text,
  created_at timestamptz default now()
);

create index if not exists idx_stories_created
  on babaero.stories (created_at desc);
create index if not exists idx_stories_author
  on babaero.stories (author_id, created_at desc);

-- Optional "seen" tracking so the ring can go grey once viewed.
create table if not exists babaero.story_views (
  story_id   uuid not null references babaero.stories (id) on delete cascade,
  viewer_id  uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz default now(),
  primary key (story_id, viewer_id)
);

-- ---------------------------------------------------------------------------
-- RLS: stories are visible to all signed-in members; you post/delete your own.
-- Views are private to the viewer.
-- ---------------------------------------------------------------------------
alter table babaero.stories     enable row level security;
alter table babaero.story_views enable row level security;

create policy stories_read on babaero.stories for select to authenticated using (true);
create policy stories_insert on babaero.stories for insert to authenticated
  with check (author_id = auth.uid());
create policy stories_delete on babaero.stories for delete to authenticated
  using (author_id = auth.uid());

create policy story_views_read on babaero.story_views for select to authenticated
  using (viewer_id = auth.uid());
create policy story_views_insert on babaero.story_views for insert to authenticated
  with check (viewer_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Storage: a public `stories` bucket, per-user folder (mirrors avatars/posts).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('stories', 'stories', true)
on conflict (id) do nothing;

drop policy if exists stories_public_read on storage.objects;
create policy stories_public_read on storage.objects
  for select using (bucket_id = 'stories');

drop policy if exists stories_owner_insert on storage.objects;
create policy stories_owner_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'stories'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists stories_owner_delete on storage.objects;
create policy stories_owner_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'stories'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- Grants (new tables need explicit grants beyond the init schema-wide grant).
-- ---------------------------------------------------------------------------
grant all on all tables in schema babaero to anon, authenticated, service_role;
grant all on all sequences in schema babaero to anon, authenticated, service_role;

notify pgrst, 'reload schema';
