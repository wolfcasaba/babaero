-- Push notifications (prep). Stores each member's FCM device token(s) so a
-- server/edge function can push on new matches/messages. The native FCM wiring
-- (firebase_messaging + google-services.json) is added separately; this is the
-- storage + client contract it will call into.

create table if not exists babaero.device_tokens (
  user_id    uuid not null references auth.users (id) on delete cascade,
  token      text not null,
  platform   text,                      -- 'android' | 'ios'
  updated_at timestamptz default now(),
  primary key (user_id, token)
);

create index if not exists idx_device_tokens_user
  on babaero.device_tokens (user_id);

alter table babaero.device_tokens enable row level security;

create policy device_tokens_all on babaero.device_tokens for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant all on all tables in schema babaero to anon, authenticated, service_role;
grant all on all sequences in schema babaero to anon, authenticated, service_role;

notify pgrst, 'reload schema';
