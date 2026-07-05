-- Security hardening (Round 1 launch-blockers).
-- Fixes five real trust/security gaps found in audit:
--   1. Users could self-approve verification (profiles.verified + verifications.status).
--   2. like_profile fabricated reciprocal likes/matches for EVERY user (not just demo).
--   3. demo_autoreply / group_demo_autoreply were callable by any real user.
--   4. No block enforcement on group messages.
--   5. matches/likes were never in the realtime publication → the match pulse was dead.
-- Additive + idempotent. No `alter role authenticator` / `notify pgrst` (hosted-managed).

-- ---------------------------------------------------------------------------
-- 0. Demo-account helper. Mirrors the app-side SupabaseConfig.isDemoAccount
--    (email endsWith '@demo.local'). SECURITY DEFINER so it can read auth.users.
-- ---------------------------------------------------------------------------
create or replace function babaero.is_demo_user()
returns boolean
language sql
security definer
set search_path = babaero
stable
as $$
  select coalesce(
    (select u.email from auth.users u where u.id = auth.uid()) like '%@demo.local',
    false
  );
$$;

grant execute on function babaero.is_demo_user() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1a. Verification requests: insert your own (as 'pending') + read your own.
--     Users must NOT be able to update status to 'approved' themselves.
-- ---------------------------------------------------------------------------
drop policy if exists verif_all    on babaero.verifications;
drop policy if exists verif_insert on babaero.verifications;
drop policy if exists verif_read   on babaero.verifications;

create policy verif_insert on babaero.verifications for insert to authenticated
  with check (auth.uid() = user_id and status = 'pending');
create policy verif_read on babaero.verifications for select to authenticated
  using (auth.uid() = user_id);
-- No UPDATE/DELETE policy: status transitions are a service-role (reviewer) path.

-- 1b. The badge actually reads profiles.verified — profiles_insert/update let a
--     user set it directly. Guard it: only the service role may set verified/
--     verified_at. On insert a normal member is forced to unverified; on update
--     the old values are kept (non-breaking — other profile fields still write).
create or replace function babaero.guard_profile_verified()
returns trigger
language plpgsql
set search_path = babaero
as $$
begin
  if auth.role() is distinct from 'service_role' then
    if tg_op = 'INSERT' then
      new.verified    := false;
      new.verified_at := null;
    elsif tg_op = 'UPDATE'
       and (new.verified    is distinct from old.verified
            or new.verified_at is distinct from old.verified_at)
    then
      new.verified    := old.verified;
      new.verified_at := old.verified_at;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_profile_verified on babaero.profiles;
create trigger trg_guard_profile_verified
  before insert or update on babaero.profiles
  for each row execute function babaero.guard_profile_verified();

-- ---------------------------------------------------------------------------
-- 2. like_profile: the reciprocal "likes you back" is DEMO liveliness only.
--    Gate it to demo accounts so real users never get phantom matches.
-- ---------------------------------------------------------------------------
create or replace function babaero.like_profile(target uuid, is_super boolean default false)
returns boolean
language plpgsql
security definer
set search_path = babaero
as $$
declare
  me uuid := auth.uid();
  lo uuid;
  hi uuid;
begin
  if me is null or me = target then
    return false;
  end if;

  insert into babaero.likes (liker_id, liked_id, is_super)
  values (me, target, coalesce(is_super, false))
  on conflict (liker_id, liked_id) do nothing;

  -- Demo liveliness ONLY: seed profiles have no session to like back, so for a
  -- demo account the target likes back ~65% of the time. Real users get a match
  -- only when the other person genuinely likes them (via on_like_insert).
  if babaero.is_demo_user() and random() < 0.65 then
    insert into babaero.likes (liker_id, liked_id)
    values (target, me)
    on conflict (liker_id, liked_id) do nothing;
  end if;

  lo := least(me, target);
  hi := greatest(me, target);
  return exists (
    select 1 from babaero.matches where user_low = lo and user_high = hi
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. demo_autoreply / group_demo_autoreply: no-op for non-demo accounts, so a
--    real user cannot fabricate incoming messages from a real match.
-- ---------------------------------------------------------------------------
create or replace function babaero.demo_autoreply(conv uuid)
returns void
language plpgsql
security definer
set search_path = babaero
as $$
declare
  me uuid := auth.uid();
  other uuid;
  pick int;
  body_tl text;
  body_en text;
  replies text[][] := array[
    array['Kumusta! Natutuwa akong makilala ka 😊','Hello! Nice to meet you 😊'],
    array['Maganda ang panahon dito ngayon ☀️','The weather is beautiful here today ☀️'],
    array['Ano ang paborito mong pagkain?','What is your favorite food?'],
    array['Gusto ko ring maglakbay balang araw ✈️','I would love to travel someday too ✈️'],
    array['Salamat sa pagme-message sa akin 💕','Thank you for messaging me 💕'],
    array['Baka gusto mong mag-video call mamaya?','Maybe you would like to video call later?'],
    array['Ang bait mo naman, kinikilig ako 🙈','You are so sweet, it makes me blush 🙈']
  ];
begin
  if me is null or not babaero.is_demo_user() then return; end if;
  select case when c.user_low = me then c.user_high else c.user_low end
    into other
  from babaero.conversations c
  where c.id = conv and (c.user_low = me or c.user_high = me);
  if other is null then return; end if;

  pick := 1 + floor(random() * array_length(replies, 1))::int;
  body_tl := replies[pick][1];
  body_en := replies[pick][2];

  insert into babaero.messages
    (conversation_id, sender_id, body, translated_body, source_lang, target_lang)
  values (conv, other, body_tl, body_en, 'tl', 'en');
end;
$$;

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
  if me is null or not babaero.is_demo_user() then return; end if;
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

-- These demo helpers should not be reachable by the anon role.
revoke execute on function babaero.demo_autoreply(uuid)       from anon;
revoke execute on function babaero.group_demo_autoreply(uuid) from anon;
revoke execute on function babaero.like_profile(uuid, boolean) from anon;

-- ---------------------------------------------------------------------------
-- 4. Block enforcement on group messages: a blocked user must not be able to
--    reach the person who blocked them through a shared group either.
-- ---------------------------------------------------------------------------
drop policy if exists group_messages_insert on babaero.group_messages;
create policy group_messages_insert on babaero.group_messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and babaero.is_group_member(group_id)
    and not exists (
      select 1 from babaero.group_members gm
      where gm.group_id = group_messages.group_id
        and gm.user_id <> auth.uid()
        and babaero.is_blocked_between(auth.uid(), gm.user_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 5. Realtime: the match pulse subscribes to matches + likes inserts, but they
--    were never in the publication → it was silently dead. Add them (idempotent).
-- ---------------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table babaero.matches;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table babaero.likes;
exception when duplicate_object then null;
end $$;
