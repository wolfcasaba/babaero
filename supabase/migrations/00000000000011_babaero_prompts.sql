-- Profile prompts: Hinge-style question/answer cards on a profile. They make
-- profiles feel human and give matches something to open with (better first
-- messages → more conversations). Stored as a jsonb array of {q, a}. Additive.

alter table babaero.profiles
  add column if not exists prompts jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';
