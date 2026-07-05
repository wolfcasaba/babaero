-- Let a story's AUTHOR read who viewed it (the "seen by" list). The base
-- policy only exposes a member's own views (viewer_id = auth.uid()); this adds
-- read access to the views of stories you own.

create policy story_views_author_read on babaero.story_views
  for select to authenticated
  using (
    exists (
      select 1 from babaero.stories s
      where s.id = story_views.story_id
        and s.author_id = auth.uid()
    )
  );

notify pgrst, 'reload schema';
