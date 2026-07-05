-- Group chat: a SEPARATE `group_*` subsystem. Additive — it does not touch the
-- existing 1:1 chat (conversations/messages), its trigger, or demo_autoreply.
-- A group has a title, an owner (admin), and N members drawn from the owner's
-- matches. Messages stream in realtime and carry the same inline translation.

-- ---------------------------------------------------------------------------
-- group_conversations: one row per group.
-- ---------------------------------------------------------------------------
create table if not exists babaero.group_conversations (
  id              uuid primary key default gen_random_uuid(),
  title           text not null check (title <> ''),
  created_by      uuid not null references auth.users (id) on delete cascade,
  image_url       text,
  last_message_at timestamptz default now(),
  created_at      timestamptz default now()
);

create index if not exists idx_group_conv_activity
  on babaero.group_conversations (last_message_at desc);

-- ---------------------------------------------------------------------------
-- group_members: (group, user) membership. PK prevents duplicates.
-- ---------------------------------------------------------------------------
create table if not exists babaero.group_members (
  group_id  uuid not null references babaero.group_conversations (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  role      text not null default 'member',  -- 'admin' | 'member'
  joined_at timestamptz default now(),
  primary key (group_id, user_id)
);

create index if not exists idx_group_members_user on babaero.group_members (user_id);

-- ---------------------------------------------------------------------------
-- group_messages: chat lines. translated_body holds the auto-translation,
-- mirroring babaero.messages so the same bubble UI works.
-- ---------------------------------------------------------------------------
create table if not exists babaero.group_messages (
  id              uuid primary key default gen_random_uuid(),
  group_id        uuid not null references babaero.group_conversations (id) on delete cascade,
  sender_id       uuid not null references auth.users (id) on delete cascade,
  body            text not null,
  translated_body text,
  source_lang     text,
  target_lang     text,
  created_at      timestamptz default now()
);

create index if not exists idx_group_messages_group
  on babaero.group_messages (group_id, created_at);

-- ---------------------------------------------------------------------------
-- Membership check as a SECURITY DEFINER function. RLS policies on the three
-- group tables all gate on membership; calling this function (which runs as
-- the definer and bypasses RLS) avoids the infinite policy recursion you'd get
-- from a policy on group_members that itself queries group_members.
-- ---------------------------------------------------------------------------
create or replace function babaero.is_group_member(grp uuid)
returns boolean
language sql
security definer
set search_path = babaero
as $$
  select exists (
    select 1 from babaero.group_members
    where group_id = grp and user_id = auth.uid()
  );
$$;

grant execute on function babaero.is_group_member(uuid)
  to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- create_group_conversation: make a group, add the caller as admin, then add
-- the given members. Security definer so it can seed group_members despite RLS.
-- ---------------------------------------------------------------------------
create or replace function babaero.create_group_conversation(title text, members uuid[])
returns uuid
language plpgsql
security definer
set search_path = babaero
as $$
declare
  me  uuid := auth.uid();
  grp uuid;
  m   uuid;
begin
  if me is null then return null; end if;

  insert into babaero.group_conversations (title, created_by)
  values (coalesce(nullif(trim(title), ''), 'Group'), me)
  returning id into grp;

  insert into babaero.group_members (group_id, user_id, role)
  values (grp, me, 'admin');

  if members is not null then
    foreach m in array members loop
      if m is not null and m <> me then
        insert into babaero.group_members (group_id, user_id, role)
        values (grp, m, 'member')
        on conflict (group_id, user_id) do nothing;
      end if;
    end loop;
  end if;

  return grp;
end;
$$;

grant execute on function babaero.create_group_conversation(text, uuid[])
  to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- Bump group_conversations.last_message_at on every new group message, so the
-- Messages list can order groups by recent activity (mirrors on_message_insert).
-- ---------------------------------------------------------------------------
create or replace function babaero.on_group_message_insert()
returns trigger
language plpgsql
security definer
set search_path = babaero
as $$
begin
  update babaero.group_conversations
  set last_message_at = new.created_at
  where id = new.group_id;
  return new;
end;
$$;

drop trigger if exists trg_on_group_message_insert on babaero.group_messages;
create trigger trg_on_group_message_insert
  after insert on babaero.group_messages
  for each row execute function babaero.on_group_message_insert();

-- ---------------------------------------------------------------------------
-- Demo-only: keep a group feeling alive. Picks a random OTHER member and posts
-- a canned Tagalog reply + its English translation, so the inline-translation
-- UX is demonstrable without a second live user. Mirrors demo_autoreply.
-- ---------------------------------------------------------------------------
create or replace function babaero.group_demo_autoreply(grp uuid)
returns void
language plpgsql
security definer
set search_path = babaero
as $$
declare
  me      uuid := auth.uid();
  other   uuid;
  pick    int;
  body_tl text;
  body_en text;
  replies text[][] := array[
    array['Hello sa inyong lahat! 😊','Hello everyone! 😊'],
    array['Kumusta na kayo mga kaibigan?','How are you all, friends?'],
    array['Sino ang gutom na? Kumain na tayo 🍚','Who is hungry? Let us eat 🍚'],
    array['Ang saya-saya dito sa group na ito 💕','This group is so much fun 💕'],
    array['May balak ba kayong mag-video call?','Do you all plan to video call?'],
    array['Salamat sa pag-add sa akin dito 🙏','Thanks for adding me here 🙏'],
    array['Magandang araw sa lahat! ☀️','Good day to everyone! ☀️']
  ];
begin
  if me is null then return; end if;
  if not exists (
    select 1 from babaero.group_members where group_id = grp and user_id = me
  ) then
    return;
  end if;

  select user_id into other
  from babaero.group_members
  where group_id = grp and user_id <> me
  order by random()
  limit 1;
  if other is null then return; end if;

  pick := 1 + floor(random() * array_length(replies, 1))::int;
  body_tl := replies[pick][1];
  body_en := replies[pick][2];

  insert into babaero.group_messages
    (group_id, sender_id, body, translated_body, source_lang, target_lang)
  values (grp, other, body_tl, body_en, 'tl', 'en');
end;
$$;

grant execute on function babaero.group_demo_autoreply(uuid)
  to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- Row Level Security. Every gate is membership, checked via the security
-- definer is_group_member() to avoid recursive policy evaluation.
-- ---------------------------------------------------------------------------
alter table babaero.group_conversations enable row level security;
alter table babaero.group_members       enable row level security;
alter table babaero.group_messages      enable row level security;

-- group_conversations: members read. Creation is via create_group_conversation.
create policy group_conv_read on babaero.group_conversations for select to authenticated
  using (babaero.is_group_member(id));

-- group_members: members of the group can see its roster; you can leave (delete
-- your own row). Inserts go through the security-definer RPC.
create policy group_members_read on babaero.group_members for select to authenticated
  using (babaero.is_group_member(group_id));
create policy group_members_leave on babaero.group_members for delete to authenticated
  using (user_id = auth.uid());

-- group_messages: members read; members send as themselves.
create policy group_messages_read on babaero.group_messages for select to authenticated
  using (babaero.is_group_member(group_id));
create policy group_messages_insert on babaero.group_messages for insert to authenticated
  with check (sender_id = auth.uid() and babaero.is_group_member(group_id));

-- ---------------------------------------------------------------------------
-- Realtime + grants. New tables need explicit grants (the schema-wide grant in
-- the init migration only covered tables existing then).
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table babaero.group_messages;
alter publication supabase_realtime add table babaero.group_conversations;

grant all on all tables in schema babaero to anon, authenticated, service_role;
grant all on all sequences in schema babaero to anon, authenticated, service_role;

notify pgrst, 'reload schema';
