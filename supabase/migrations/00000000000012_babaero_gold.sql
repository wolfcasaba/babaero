-- Babaero Gold entitlement flag. Everything is FREE during launch, so this is
-- false for everyone now; when membership launches, flipping is_gold (or wiring
-- a billing webhook to set it) turns the premium gates on without a code change.

alter table babaero.profiles
  add column if not exists is_gold boolean not null default false;

notify pgrst, 'reload schema';
