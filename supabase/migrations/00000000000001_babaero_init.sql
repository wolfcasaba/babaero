-- Babaero initial schema.
-- Lives in a dedicated `babaero` Postgres schema so it never collides with
-- the recipewiser `public` tables sharing this local Supabase instance.
-- Auth users are shared (auth.users) — that's fine for local dev.

create schema if not exists babaero;

-- ---------------------------------------------------------------------------
-- profiles: one row per member, keyed to the auth user.
-- ---------------------------------------------------------------------------
create table if not exists babaero.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  name         text not null,
  age          int  check (age between 18 and 120),
  gender       text,                      -- 'male' | 'female' | 'other'
  role         text default 'foreigner',  -- 'foreigner' | 'local'
  country      text,
  city         text,
  bio          text,
  languages    text,                      -- e.g. 'English, Tagalog'
  interests    text[] default '{}',
  photos       text[] default '{}',       -- storage paths / urls
  verified     boolean default false,
  verified_at  timestamptz,
  is_online    boolean default false,
  last_active  timestamptz default now(),
  created_at   timestamptz default now()
);

-- ---------------------------------------------------------------------------
-- verifications: photo/video/id verification requests.
-- ---------------------------------------------------------------------------
create table if not exists babaero.verifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  type        text not null,             -- 'photo' | 'video' | 'id'
  status      text not null default 'pending', -- 'pending'|'approved'|'rejected'
  evidence    text,                      -- storage path
  created_at  timestamptz default now()
);

-- ---------------------------------------------------------------------------
-- likes: directional. A mutual pair becomes a match (see trigger).
-- ---------------------------------------------------------------------------
create table if not exists babaero.likes (
  id          uuid primary key default gen_random_uuid(),
  liker_id    uuid not null references auth.users (id) on delete cascade,
  liked_id    uuid not null references auth.users (id) on delete cascade,
  is_super    boolean default false,
  created_at  timestamptz default now(),
  unique (liker_id, liked_id),
  check (liker_id <> liked_id)
);

-- ---------------------------------------------------------------------------
-- matches: unordered pair (user_low < user_high enforced by trigger).
-- ---------------------------------------------------------------------------
create table if not exists babaero.matches (
  id          uuid primary key default gen_random_uuid(),
  user_low    uuid not null references auth.users (id) on delete cascade,
  user_high   uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz default now(),
  unique (user_low, user_high),
  check (user_low < user_high)
);

-- ---------------------------------------------------------------------------
-- conversations: one per match.
-- ---------------------------------------------------------------------------
create table if not exists babaero.conversations (
  id              uuid primary key default gen_random_uuid(),
  user_low        uuid not null references auth.users (id) on delete cascade,
  user_high       uuid not null references auth.users (id) on delete cascade,
  last_message_at timestamptz default now(),
  created_at      timestamptz default now(),
  unique (user_low, user_high),
  check (user_low < user_high)
);

-- ---------------------------------------------------------------------------
-- messages: chat lines. translated_body holds the auto-translation.
-- ---------------------------------------------------------------------------
create table if not exists babaero.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references babaero.conversations (id) on delete cascade,
  sender_id       uuid not null references auth.users (id) on delete cascade,
  body            text not null,
  translated_body text,
  source_lang     text,
  target_lang     text,
  read_at         timestamptz,
  created_at      timestamptz default now()
);

create index if not exists idx_messages_conversation
  on babaero.messages (conversation_id, created_at);
create index if not exists idx_likes_liked on babaero.likes (liked_id);

-- ---------------------------------------------------------------------------
-- Mutual-like → match + conversation. Runs on every like insert.
-- ---------------------------------------------------------------------------
create or replace function babaero.on_like_insert()
returns trigger
language plpgsql
security definer
set search_path = babaero
as $$
declare
  lo uuid;
  hi uuid;
begin
  -- reciprocal like present?
  if exists (
    select 1 from babaero.likes
    where liker_id = new.liked_id and liked_id = new.liker_id
  ) then
    lo := least(new.liker_id, new.liked_id);
    hi := greatest(new.liker_id, new.liked_id);

    insert into babaero.matches (user_low, user_high)
    values (lo, hi)
    on conflict (user_low, user_high) do nothing;

    insert into babaero.conversations (user_low, user_high)
    values (lo, hi)
    on conflict (user_low, user_high) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_on_like_insert on babaero.likes;
create trigger trg_on_like_insert
  after insert on babaero.likes
  for each row execute function babaero.on_like_insert();

-- ---------------------------------------------------------------------------
-- Bump conversation.last_message_at on new message.
-- ---------------------------------------------------------------------------
create or replace function babaero.on_message_insert()
returns trigger
language plpgsql
security definer
set search_path = babaero
as $$
begin
  update babaero.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists trg_on_message_insert on babaero.messages;
create trigger trg_on_message_insert
  after insert on babaero.messages
  for each row execute function babaero.on_message_insert();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table babaero.profiles      enable row level security;
alter table babaero.verifications enable row level security;
alter table babaero.likes         enable row level security;
alter table babaero.matches       enable row level security;
alter table babaero.conversations enable row level security;
alter table babaero.messages      enable row level security;

-- profiles: anyone signed in can browse; you edit only your own.
create policy profiles_read   on babaero.profiles for select to authenticated using (true);
create policy profiles_insert on babaero.profiles for insert to authenticated with check (auth.uid() = id);
create policy profiles_update on babaero.profiles for update to authenticated using (auth.uid() = id);

-- verifications: only your own.
create policy verif_all on babaero.verifications for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- likes: see likes you sent or received; create only as yourself.
create policy likes_read   on babaero.likes for select to authenticated
  using (auth.uid() = liker_id or auth.uid() = liked_id);
create policy likes_insert on babaero.likes for insert to authenticated
  with check (auth.uid() = liker_id);

-- matches: only pairs you belong to.
create policy matches_read on babaero.matches for select to authenticated
  using (auth.uid() = user_low or auth.uid() = user_high);

-- conversations: only yours.
create policy conv_read on babaero.conversations for select to authenticated
  using (auth.uid() = user_low or auth.uid() = user_high);

-- messages: read/send only in conversations you belong to.
create policy messages_read on babaero.messages for select to authenticated
  using (exists (
    select 1 from babaero.conversations c
    where c.id = messages.conversation_id
      and (auth.uid() = c.user_low or auth.uid() = c.user_high)
  ));
create policy messages_insert on babaero.messages for insert to authenticated
  with check (
    sender_id = auth.uid() and exists (
      select 1 from babaero.conversations c
      where c.id = messages.conversation_id
        and (auth.uid() = c.user_low or auth.uid() = c.user_high)
    )
  );

-- ---------------------------------------------------------------------------
-- Grants (PostgREST roles) + expose the schema to the API.
-- ---------------------------------------------------------------------------
grant usage on schema babaero to anon, authenticated, service_role;
grant all on all tables in schema babaero to anon, authenticated, service_role;
grant all on all routines in schema babaero to anon, authenticated, service_role;
grant all on all sequences in schema babaero to anon, authenticated, service_role;
alter default privileges in schema babaero
  grant all on tables to anon, authenticated, service_role;

-- Expose `babaero` to PostgREST without restarting the stack.
alter role authenticator set pgrst.db_schemas = 'public, graphql_public, babaero';
notify pgrst, 'reload config';
notify pgrst, 'reload schema';
