-- Safety: block + report. Trust-first is core to the product, so members can
-- block someone (hides them from Discover) and report abuse. Additive.

-- ---------------------------------------------------------------------------
-- blocks: directional. blocker no longer sees blocked in Discover.
-- ---------------------------------------------------------------------------
create table if not exists babaero.blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists idx_blocks_blocker on babaero.blocks (blocker_id);

-- ---------------------------------------------------------------------------
-- reports: abuse reports, reviewed out-of-band (no admin UI yet).
-- ---------------------------------------------------------------------------
create table if not exists babaero.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reported_id uuid not null references auth.users (id) on delete cascade,
  reason      text not null,
  details     text,
  created_at  timestamptz default now()
);

-- ---------------------------------------------------------------------------
-- Row Level Security: you manage only your own blocks; you file your own
-- reports (and can read them back). No one reads others' rows.
-- ---------------------------------------------------------------------------
alter table babaero.blocks  enable row level security;
alter table babaero.reports enable row level security;

create policy blocks_read on babaero.blocks for select to authenticated
  using (blocker_id = auth.uid());
create policy blocks_insert on babaero.blocks for insert to authenticated
  with check (blocker_id = auth.uid());
create policy blocks_delete on babaero.blocks for delete to authenticated
  using (blocker_id = auth.uid());

create policy reports_read on babaero.reports for select to authenticated
  using (reporter_id = auth.uid());
create policy reports_insert on babaero.reports for insert to authenticated
  with check (reporter_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Grants (new tables need explicit grants beyond the init schema-wide grant).
-- ---------------------------------------------------------------------------
grant all on all tables in schema babaero to anon, authenticated, service_role;
grant all on all sequences in schema babaero to anon, authenticated, service_role;

notify pgrst, 'reload schema';
