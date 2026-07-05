-- Robustness (Round 2): hot-path indexes, content-length guards, storage size
-- limits. All additive + idempotent. CHECK constraints are added NOT VALID so
-- they enforce on new writes without validating (or failing on) existing rows.

-- ---------------------------------------------------------------------------
-- 1. Indexes on FK / hot filter columns not already covered by a PK/unique.
-- ---------------------------------------------------------------------------
create index if not exists idx_likes_liker        on babaero.likes (liker_id);
create index if not exists idx_matches_high        on babaero.matches (user_high);
create index if not exists idx_conv_high           on babaero.conversations (user_high);
create index if not exists idx_post_comments_post  on babaero.post_comments (post_id);
create index if not exists idx_story_views_viewer  on babaero.story_views (viewer_id);
create index if not exists idx_reports_reported    on babaero.reports (reported_id);
create index if not exists idx_blocks_blocked      on babaero.blocks (blocked_id);

-- ---------------------------------------------------------------------------
-- 2. Content-length guards — stop a client inserting megabyte-sized bodies
--    (also caps what the translation API is asked to translate). NOT VALID so
--    existing rows are untouched; new/updated rows are checked.
-- ---------------------------------------------------------------------------
do $$
begin
  alter table babaero.messages
    add constraint messages_body_len check (char_length(body) <= 4000) not valid;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table babaero.group_messages
    add constraint group_messages_body_len check (char_length(body) <= 4000) not valid;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table babaero.posts
    add constraint posts_content_len check (char_length(content) <= 5000) not valid;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table babaero.post_comments
    add constraint post_comments_content_len check (char_length(content) <= 2000) not valid;
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Enum-like value guards (NOT VALID; NULLs always pass so this never breaks
--    reads that leave the column empty).
-- ---------------------------------------------------------------------------
do $$
begin
  alter table babaero.profiles
    add constraint profiles_gender_chk
    check (gender is null or gender in ('male','female','other')) not valid;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table babaero.profiles
    add constraint profiles_role_chk
    check (role is null or role in ('foreigner','local')) not valid;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table babaero.verifications
    add constraint verifications_status_chk
    check (status in ('pending','approved','rejected')) not valid;
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Storage size limits (bytes). Prevents arbitrarily large uploads to the
--    public buckets. MIME allow-lists are intentionally left unset to avoid
--    silently rejecting a legitimate upload (image_picker output varies).
--      images: 8 MB · chat (images + voice notes): 25 MB.
-- ---------------------------------------------------------------------------
update storage.buckets set file_size_limit = 8388608
  where id in ('avatars', 'posts', 'stories', 'verifications');
update storage.buckets set file_size_limit = 26214400
  where id = 'chat';
