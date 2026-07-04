-- Chat support: on-demand conversation creation + realtime.

-- Returns the conversation id between the current user and `other`,
-- creating it if it doesn't exist yet. Security definer so it can insert
-- despite the (read-only) RLS on conversations.
create or replace function babaero.get_or_create_conversation(other uuid)
returns uuid
language plpgsql
security definer
set search_path = babaero
as $$
declare
  me uuid := auth.uid();
  lo uuid;
  hi uuid;
  conv uuid;
begin
  if me is null or other is null or me = other then
    return null;
  end if;
  lo := least(me, other);
  hi := greatest(me, other);

  insert into babaero.conversations (user_low, user_high)
  values (lo, hi)
  on conflict (user_low, user_high) do nothing;

  select id into conv from babaero.conversations
  where user_low = lo and user_high = hi;
  return conv;
end;
$$;

grant execute on function babaero.get_or_create_conversation(uuid)
  to authenticated, anon, service_role;

-- Realtime: broadcast inserts/updates on chat tables (RLS still applies).
alter publication supabase_realtime add table babaero.messages;
alter publication supabase_realtime add table babaero.conversations;

notify pgrst, 'reload schema';
