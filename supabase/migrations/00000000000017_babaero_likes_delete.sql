-- Allow a member to delete their OWN likes — needed for "rewind / undo last
-- swipe": undoing a like removes the like row. Without this policy the delete
-- silently no-ops under RLS (likes only had read + insert policies).

create policy likes_delete on babaero.likes for delete to authenticated
  using (auth.uid() = liker_id);

notify pgrst, 'reload schema';
