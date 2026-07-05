-- Call log for 1:1 WebRTC calls. The live call runs entirely over ephemeral
-- Realtime broadcast signaling; this table is the DURABLE record (history +,
-- in R3, "missed call" chat entries). Client writes are best-effort — a call
-- still connects if this table is absent.
--
-- id is a client-generated text token ("<callerUid>|<micros>"), not a uuid.

create table if not exists babaero.calls (
  id              text primary key,
  conversation_id uuid references babaero.conversations (id) on delete set null,
  caller_id       uuid not null references auth.users (id) on delete cascade,
  callee_id       uuid not null references auth.users (id) on delete cascade,
  media           text not null default 'video',
  status          text not null default 'ringing',
  created_at      timestamptz default now(),
  ended_at        timestamptz
);

create index if not exists idx_calls_conversation
  on babaero.calls (conversation_id, created_at);
create index if not exists idx_calls_participants
  on babaero.calls (caller_id, callee_id, created_at);

alter table babaero.calls enable row level security;

-- Either participant may read their own calls.
drop policy if exists calls_select on babaero.calls;
create policy calls_select on babaero.calls
  for select to authenticated
  using (auth.uid() = caller_id or auth.uid() = callee_id);

-- Only the caller creates the call row (they initiate it).
drop policy if exists calls_insert on babaero.calls;
create policy calls_insert on babaero.calls
  for insert to authenticated
  with check (auth.uid() = caller_id);

-- Either participant may update the status (accept / reject / end).
drop policy if exists calls_update on babaero.calls;
create policy calls_update on babaero.calls
  for update to authenticated
  using (auth.uid() = caller_id or auth.uid() = callee_id)
  with check (auth.uid() = caller_id or auth.uid() = callee_id);

notify pgrst, 'reload schema';
