-- like_profile: records the current user's like on `target`. For a lively
-- local demo (seed profiles have no session to like back), the target likes
-- back ~65% of the time, which lets the mutual-like trigger form a match +
-- conversation. Returns true when a match now exists.
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

  -- Demo liveliness only.
  if random() < 0.65 then
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

grant execute on function babaero.like_profile(uuid, boolean) to authenticated, anon, service_role;

notify pgrst, 'reload schema';
