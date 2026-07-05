-- Private storage bucket for verification selfies. Evidence is sensitive, so
-- the bucket is NOT public: a member may upload only into their own <uid>/
-- folder, and nobody (except the service role used by reviewers) can read it.

insert into storage.buckets (id, name, public)
values ('verifications', 'verifications', false)
on conflict (id) do nothing;

-- Upload / overwrite only within your own folder.
create policy verif_evidence_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'verifications'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy verif_evidence_update on storage.objects for update to authenticated
  using (
    bucket_id = 'verifications'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Deliberately NO select policy for `authenticated` — evidence is read only by
-- the service role (reviewer tooling), never by other members.
