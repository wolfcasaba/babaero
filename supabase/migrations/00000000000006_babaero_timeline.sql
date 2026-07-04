-- Timeline / social feed: posts + likes + comments (Facebook-style feed).
-- Additive — does not touch the existing chat/match tables.

-- ---------------------------------------------------------------------------
-- posts: one row per timeline post. A post is text, an image, or both.
-- ---------------------------------------------------------------------------
create table if not exists babaero.posts (
  id            uuid primary key default gen_random_uuid(),
  author_id     uuid not null references auth.users (id) on delete cascade,
  content       text not null default '',
  image_url     text,
  like_count    int  not null default 0,
  comment_count int  not null default 0,
  created_at    timestamptz default now(),
  check (content <> '' or image_url is not null)
);

create index if not exists idx_posts_created on babaero.posts (created_at desc);
create index if not exists idx_posts_author  on babaero.posts (author_id);

-- ---------------------------------------------------------------------------
-- post_likes: one row per (post, user). PK prevents double-likes.
-- ---------------------------------------------------------------------------
create table if not exists babaero.post_likes (
  post_id    uuid not null references babaero.posts (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz default now(),
  primary key (post_id, user_id)
);

-- ---------------------------------------------------------------------------
-- post_comments: threaded-flat comments under a post.
-- ---------------------------------------------------------------------------
create table if not exists babaero.post_comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references babaero.posts (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  content    text not null,
  created_at timestamptz default now()
);

create index if not exists idx_post_comments_post
  on babaero.post_comments (post_id, created_at);

-- ---------------------------------------------------------------------------
-- Denormalized counters: keep posts.like_count / comment_count in sync so the
-- feed reads one row per post (no aggregate per card). Security definer so the
-- counter update bypasses RLS (a liker is not the post author).
-- ---------------------------------------------------------------------------
create or replace function babaero.on_post_like_change()
returns trigger
language plpgsql
security definer
set search_path = babaero
as $$
begin
  if (tg_op = 'INSERT') then
    update babaero.posts set like_count = like_count + 1 where id = new.post_id;
  elsif (tg_op = 'DELETE') then
    update babaero.posts set like_count = greatest(like_count - 1, 0)
      where id = old.post_id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_post_like_change on babaero.post_likes;
create trigger trg_post_like_change
  after insert or delete on babaero.post_likes
  for each row execute function babaero.on_post_like_change();

create or replace function babaero.on_post_comment_change()
returns trigger
language plpgsql
security definer
set search_path = babaero
as $$
begin
  if (tg_op = 'INSERT') then
    update babaero.posts set comment_count = comment_count + 1
      where id = new.post_id;
  elsif (tg_op = 'DELETE') then
    update babaero.posts set comment_count = greatest(comment_count - 1, 0)
      where id = old.post_id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_post_comment_change on babaero.post_comments;
create trigger trg_post_comment_change
  after insert or delete on babaero.post_comments
  for each row execute function babaero.on_post_comment_change();

-- ---------------------------------------------------------------------------
-- Row Level Security: the feed is public to signed-in members; you only
-- create/edit your own posts, likes and comments.
-- ---------------------------------------------------------------------------
alter table babaero.posts         enable row level security;
alter table babaero.post_likes    enable row level security;
alter table babaero.post_comments enable row level security;

create policy posts_read   on babaero.posts for select to authenticated using (true);
create policy posts_insert on babaero.posts for insert to authenticated
  with check (author_id = auth.uid());
create policy posts_update on babaero.posts for update to authenticated
  using (author_id = auth.uid());
create policy posts_delete on babaero.posts for delete to authenticated
  using (author_id = auth.uid());

create policy post_likes_read   on babaero.post_likes for select to authenticated using (true);
create policy post_likes_insert on babaero.post_likes for insert to authenticated
  with check (user_id = auth.uid());
create policy post_likes_delete on babaero.post_likes for delete to authenticated
  using (user_id = auth.uid());

create policy post_comments_read   on babaero.post_comments for select to authenticated using (true);
create policy post_comments_insert on babaero.post_comments for insert to authenticated
  with check (user_id = auth.uid());
create policy post_comments_delete on babaero.post_comments for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Storage: a public `posts` bucket for feed images. Files under a per-user
-- folder (`<uid>/<file>`), readable by anyone, writable only by their owner.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('posts', 'posts', true)
on conflict (id) do nothing;

drop policy if exists posts_public_read on storage.objects;
create policy posts_public_read on storage.objects
  for select using (bucket_id = 'posts');

drop policy if exists posts_owner_insert on storage.objects;
create policy posts_owner_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists posts_owner_delete on storage.objects;
create policy posts_owner_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- Realtime + grants. New tables need explicit grants (the schema-wide grant in
-- the init migration only covered tables existing then).
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table babaero.posts;
alter publication supabase_realtime add table babaero.post_comments;

grant all on all tables in schema babaero to anon, authenticated, service_role;
grant all on all sequences in schema babaero to anon, authenticated, service_role;

notify pgrst, 'reload schema';
