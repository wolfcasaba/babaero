-- Read receipts: let a conversation member mark the OTHER side's messages read.
-- messages.read_at exists since the init migration, but messages has no UPDATE
-- policy — so the client can't set it directly. A security-definer RPC keeps the
-- write path narrow: members only, incoming messages only, read_at only.

create or replace function babaero.mark_conversation_read(conv uuid)
returns void
language plpgsql
security definer
set search_path = babaero
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  -- Only members of the conversation may mark it read.
  if not exists (
    select 1 from babaero.conversations c
    where c.id = conv
      and (auth.uid() = c.user_low or auth.uid() = c.user_high)
  ) then
    return;
  end if;

  update babaero.messages
  set read_at = now()
  where conversation_id = conv
    and sender_id <> auth.uid()
    and read_at is null;
end;
$$;

grant execute on function babaero.mark_conversation_read(uuid) to authenticated;

notify pgrst, 'reload schema';
