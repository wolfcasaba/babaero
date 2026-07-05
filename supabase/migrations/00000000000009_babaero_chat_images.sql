-- Photo messages: an optional image on a chat / group message. Additive — the
-- column is nullable so every existing message and the demo replies are fine.

alter table babaero.messages
  add column if not exists image_url text;

alter table babaero.group_messages
  add column if not exists image_url text;

-- ---------------------------------------------------------------------------
-- Storage: a public `chat` bucket for message images. Files under a per-user
-- folder (`<uid>/<file>`), readable by anyone, writable only by their owner —
-- same shape as the avatars/posts buckets.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('chat', 'chat', true)
on conflict (id) do nothing;

drop policy if exists chat_public_read on storage.objects;
create policy chat_public_read on storage.objects
  for select using (bucket_id = 'chat');

drop policy if exists chat_owner_insert on storage.objects;
create policy chat_owner_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists chat_owner_delete on storage.objects;
create policy chat_owner_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'chat'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

notify pgrst, 'reload schema';
