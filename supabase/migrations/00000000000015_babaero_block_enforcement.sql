-- Enforce blocks at the database layer: a blocked user must not be able to
-- send messages to (or receive them from) the person who blocked them. The
-- client already hides blocked members everywhere, but RLS is the real guard —
-- without this a blocked user could still POST to an existing conversation.

-- Helper: is there a block in EITHER direction between two users?
create or replace function babaero.is_blocked_between(a uuid, b uuid)
returns boolean
language sql
security definer
set search_path = babaero
stable
as $$
  select exists (
    select 1 from babaero.blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

grant execute on function babaero.is_blocked_between(uuid, uuid)
  to authenticated;

-- Rebuild the message-insert policy to also reject sends when a block exists
-- between the sender and the conversation's other participant.
drop policy if exists messages_insert on babaero.messages;
create policy messages_insert on babaero.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from babaero.conversations c
      where c.id = messages.conversation_id
        and (auth.uid() = c.user_low or auth.uid() = c.user_high)
        and not babaero.is_blocked_between(
          c.user_low,
          c.user_high
        )
    )
  );

notify pgrst, 'reload schema';
