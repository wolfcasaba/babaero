# Babaero — continue development (handoff)

Continue building **Babaero**, a Flutter dating/chat app (foreigners ↔ Filipinas).
**Talk to the user in Hungarian; code/comments in English.**

> **Read `CLAUDE.md` first** (auto-loaded in this repo) — it is the source of truth for
> stack, conventions, backend, build/deploy, and gotchas. This file is the running
> status + next-steps on top of it.

## Where things live
- **Code:** `~/babaero` (Flutter, package `babaero`, appId `com.babaero.babaero`, git branch `main`)
- **GitHub:** https://github.com/wolfcasaba/babaero
- **Android APK (public tap-to-install):** https://github.com/wolfcasaba/babaero/releases/latest/download/app-release.apk
- **Backend:** HOSTED Supabase project "Babaero", ref `wlcrqlfqpxgtcftqllcp`,
  URL `https://wlcrqlfqpxgtcftqllcp.supabase.co`. Anon key baked in
  `lib/core/supabase/supabase_config.dart`. Tables live in the **`babaero`** Postgres
  schema — query via `SupabaseConfig.db.from('<table>')`.

## Stack (see CLAUDE.md for detail)
Flutter 3.44 · Riverpod 3 (hand-written providers, NO codegen) · supabase_flutter 2.15 ·
feature-first · repository-provider pattern · dark "night-luxe" theme
(crimson-rose `#E01E5A` → coral `#FF7A59`, gold `#F5B54A`).

## What already works (deployed + verified end-to-end)
Auth (email/password) · onboarding profile setup · photo upload (Supabase Storage
`avatars` bucket) · Discover with real photos · like / super-like → match ("It's a
Match" dialog) · Matches + "likes you" · **realtime 1:1 chat** with **EN↔Tagalog
translation** (MyMemory API + offline fallback) + `demo_autoreply` liveliness · verification flow.
- **NEW — Timeline / social feed (Facebook-style), shipped 2026-07-04, commit `434e125`:**
  new 5th bottom-nav tab (Discover / **Feed** / Matches / Messages / Profile). Posts
  (text and/or one image), like (optimistic), comments (modal sheet), on-demand
  "See translation" on post text. Code in `lib/features/timeline/`. ⚠️ **Its DB
  migration is NOT yet applied** (see Current status).

Backend schema `babaero`: profiles, verifications, likes, matches, conversations,
messages, **posts, post_likes, post_comments** + RPCs `like_profile`,
`get_or_create_conversation`, `demo_autoreply`. Migrations 1–6 in `supabase/migrations/`.

## Autonomous polish rounds (2026-07-04, NOT committed — perfect-the-app pass)
User directive: no commit/migration/APK until the whole app is polished round-by-round;
then migration + commit + APK in one go. Each round is `flutter analyze lib/`-clean +
golden-verified. Done so far:
- **Round 1 — Profile management.** `edit_profile_screen.dart` (edit name/age/gender/role/
  city/country/bio/languages/interests → ProfileRepository.upsert) + `photo_gallery_screen.dart`
  (add/delete/set-primary over the `avatars` bucket). ProfileRepository got non-destructive
  `addPhoto`/`removePhoto`/`setPrimaryPhoto` (uploadAvatar now prepends, keeps gallery).
  Profile model gained `gender`/`role`. Wired the "Edit profile"/"My photos" rows; removed
  the dead settings-gear; other setting rows now show a "Coming soon" snackbar (no dead taps).
- **Round 2 — Profile-detail actions + safety.** profile_detail_screen → ConsumerStatefulWidget:
  heart now LIKES (match dialog / snackbar), the flag button opens a report/block sheet (was a
  bug — it used to just pop). New `lib/features/safety/` (SafetyRepository: block/unblock/report/
  blockedIds) + migration `…08_babaero_safety.sql` (blocks + reports tables + RLS). Discover now
  filters out blocked users (`blockedIdsProvider`).
- **Round 3 — Real Discover filters.** `discover_filters.dart` (DiscoverFilters + Notifier:
  verified/online/gender/age-range) applied in discoverProfilesProvider; `discover_filter_sheet.dart`
  (gender segmented + age RangeSlider + switches). Filter chips are now live toggles + a filter-count
  badge on the app-bar icon; the "Discovery preferences" profile row opens the same sheet.
- **Round 4 — Real settings screens.** `lib/features/settings/` : `app_settings.dart`
  (AsyncNotifier over shared_preferences — autoTranslate + 3 notify toggles),
  `notifications_screen.dart`, `translation_settings_screen.dart`, `help_screen.dart` (FAQ).
  `lib/features/safety/blocked_users_screen.dart` (Safety & privacy = blocked list + unblock,
  via new `blockedProfilesProvider`). Wired all the profile rows → NO "Coming soon" left except
  none. Auto-translate toggle is honored by BOTH chat and group send flows now.
- **Round 5 — Wire chat/timeline buttons + photo messages.** (5A) post-card overflow menu →
  delete own post / report others (new `TimelineRepository.deletePost`) + Share = copy-to-clipboard;
  removed the redundant timeline bell; chat/group video/phone → graceful "coming soon"; chat-list
  search → a `SearchDelegate` over DMs + groups. (5B) **Photo messages**: migration
  `…09_babaero_chat_images.sql` (image_url on messages + group_messages, public `chat` bucket).
  Message/GroupMessage models + repos gained imageUrl + `uploadImage`; both composers got a
  working "+" (imagePlus) photo button; both bubbles render the image (empty body = image-only).
- **Round 6 — Code quality.** Extracted `lib/features/chat/widgets/message_widgets.dart`
  (shared `TranslationBanner`, `MessageComposer`, `MessageBubble`) used by BOTH the 1:1 and group
  threads — deleted the duplicated private `_Bubble`/`_Composer`/`_TranslationBanner` from each
  (MessageBubble takes `inGroup`/`sender`/`showSender` to cover both layouts). Added
  `AppColors.scrim` / `scrimStrong` tokens and replaced the hardcoded photo-scrim hexes in
  discover/profile_detail/matches. Verified: shared bubble renders identically in both modes.
- **DONE:** all 6 polish rounds + group chat complete; `flutter analyze lib/` clean; ZERO dead
  `onPressed:(){}`/`onTap:(){}`/`onSelected:(_){}` handlers remain anywhere in lib/.

## Ready to ship (when the user says go)
Apply migrations **6→9** to the hosted DB via the Management API (user's `sbp_` token):
`…06_timeline`, `…07_group_chat`, `…08_safety`, `…09_chat_images`. Then bump `version:` in
pubspec, commit everything, `git push origin main` → CI builds the APK.

## Viral / growth features (2026-07-04, NOT committed) — user picked: Stories, Profile prompts+icebreakers, Compatibility%+Passport, Premium structure (free), Push prep
- **Round 7 — Stories (24h) DONE.** `lib/features/stories/` (models, repository real+Preview,
  provider, `story_viewer_screen.dart` with auto-advancing progress bars + tap nav,
  `add_story_screen.dart`, `widgets/stories_bar.dart`). Migration `…10_babaero_stories.sql`
  (stories + story_views tables, 24h enforced at read via `created_at > now()-24h`, public
  `stories` bucket, RLS). StoriesBar sits atop the Feed (shows even when the post list is empty);
  gradient ring = unseen, grey = seen, "Your story" tile has a + to add. analyze clean, golden-verified.
- **Round 8 — Profile prompts + icebreakers DONE.** Migration `…11` (profiles.prompts jsonb).
  Profile model gained `prompts` (List<ProfilePrompt>) + `kPromptQuestions`. Edit screen has a
  prompt editor (pick question → answer, up to 3); profile detail shows them. Empty chat thread
  now offers 3 tap-to-fill icebreakers built from the other person's interests/city.
- **Round 9 — Compatibility % + Passport DONE.** `discover/data/compatibility.dart` (shared
  interests + language overlap → stable %). CompatBadge on discover cards; a gradient compat card
  on profile detail. Passport = a `city` filter (DiscoverFilters.city) with a text field in the
  filter sheet + a 📍 chip in the row.
- **Round 10 — Premium structure (FREE) DONE.** Migration `…12` (profiles.is_gold flag, false for
  all). `lib/features/premium/`: `gold_screen.dart` (perks + Boost-me + waitlist CTA; boost bumps
  last_active via new ProfileRepository.boost) and `who_liked_you_screen.dart` (grid of likers via
  new MatchesRepository.whoLikedMe + whoLikedMeProvider). Wired: profile Gold card → Gold screen;
  matches "likes you" teaser → who-liked-you (copy now "free during launch"). Everything is live for
  everyone; flip is_gold + swap CTAs to monetize later.
- **Round 11 — Push prep DONE (Dart only).** Migration `…13` (device_tokens table + RLS).
  `lib/features/notifications/data/push_repository.dart` (registerToken/removeToken) + provider.
  **NATIVE FCM = user's step:** add `firebase_messaging`, `google-services.json` (Android) / APNs,
  request permission, then call `pushRepository.registerToken(fcmToken)` after sign-in and
  `removeToken` on sign-out; a server/edge function reads device_tokens to send on match/message.

## All migrations to apply when shipping (user's sbp_ token)
`…06_timeline`, `…07_group_chat`, `…08_safety`, `…09_chat_images`, `…10_stories`, `…11_prompts`,
`…12_gold`, `…13_device_tokens`. Then bump pubspec version, commit, push → CI APK.

## Group chat (round 0)
- **NEW — Group chat, CODE DONE 2026-07-04 (not committed, migration not applied).**
  Built as a SEPARATE `group_*` subsystem — the 1:1 chat + `demo_autoreply` +
  translation are untouched. New dir `lib/features/groups/` (models, repository,
  provider, `create_group_screen.dart`, `group_thread_screen.dart`). New migration
  `00000000000007_babaero_group_chat.sql`: tables `group_conversations` /
  `group_members` / `group_messages`, RPCs `create_group_conversation(title, members[])`
  + `group_demo_autoreply(grp)` + `is_group_member(grp)` (SECURITY DEFINER helper to
  avoid recursive RLS), a last_message_at bump trigger, RLS gated on membership, and
  realtime on group_messages/group_conversations. `ChatListScreen` got ADDITIVE edits: a
  "New group" action (usersRound) in the AppBar + a "GROUPS" section above the DMs. You
  build a group from your matches; incoming bubbles show sender name/avatar; outgoing
  text is translated on send (same pipeline); `group_demo_autoreply` keeps it lively.
  `flutter analyze lib/` clean; layout golden-verified (create-group, thread, list).
  **TODO:** apply migration 7 to hosted DB (user's sbp_ token) → until then the Groups
  section is empty and creating a group silently no-ops. Then bump version + commit + push.

1. **Apply migrations `…06_babaero_timeline.sql` + `…07_babaero_group_chat.sql` to the
   hosted DB.** Neither applied yet. Timeline → Feed tab shows "Feed unavailable" for
   signed-in users; Group chat → Groups section empty + create no-ops. Apply via the
   Management API (see CLAUDE.md → "Applying SQL"); needs a `sbp_…` token the **user
   pastes ad-hoc and revokes after**.
2. After migrations: **bump `version:` in pubspec + commit + push → CI APK** so both
   Timeline and Group chat ship in the installable build.

## Dev tooling (ported from recipewiser-mobile 2026-07-04, babaero-optimized)
- **`CLAUDE.md`** (committed) — babaero project instructions, auto-loaded.
- **`tools/flutter-rag.mjs`** (committed) — semantic code search over `lib/`:
  `node tools/flutter-rag.mjs "<query>"` (`--reindex` to refresh). Its own index
  (`dev-tools/flutter-code-index.json`, gitignored) — **separate from recipewiser's**.
- **`.claude/agents/babaero-*`** (local, untracked) — 6 babaero-aware agents
  (reviewer, debugger, devil-advocate, performance, test-writer, analyze-fixer).
- **`.claude/skills/`** (local, untracked) — 23 skills (the 9 recipe-flavored ones were
  content-adapted to babaero; verify-before-done, review-loop, systematic-debugging, …).
- **`.mcp.json`** (local, untracked) — dart + context7 + viking MCP.
- **⚠️ STRICT SEPARATION RULE (user directive):** babaero and recipewiser-mobile tooling
  must stay separate and each domain-optimized — per-repo RAG index, babaero-optimized
  (not verbatim-copied) skills/agents, and **never edit `~/recipewiser-mobile/` when
  working on babaero** (only read/copy from it). babaero is NOT a recipe app.
- `.claude/` + `.mcp.json` load on a **fresh session** (restart to pick them up).

## CRITICAL build/deploy facts (read before building)
- **The APK CANNOT be built on this Linux/ARM64 box** (no arm64 `gen_snapshot`,
  x86-only `aapt2`, no amd64 qemu). Builds go through **GitHub Actions CI**
  (`.github/workflows/build-apk.yml`) → publishes the APK as a **Release asset**
  (tag `v1.0.<run_number>`, `make_latest`) → the link above.
- **To ship a new APK:** bump `version:` in `pubspec.yaml` (Android versionCode) →
  commit → `git push origin main` → CI builds. Currently at **`1.0.4+5`**. Tell the
  user to **uninstall + reinstall** (and **reboot** for the launcher icon cache).
- **Keep** `<uses-permission android:name="android.permission.INTERNET"/>` in
  `android/app/src/main/AndroidManifest.xml` (main manifest) — else the release APK
  can't network ("Can't reach the server").
- **This box's GitHub token lacks `workflow` scope** → you CANNOT push/edit
  `.github/workflows/*`. The user edits workflow files in the GitHub web UI.
- **flutter is NOT on PATH** on this box — prefix commands:
  `export PATH="$PATH:$HOME/flutter/bin"`.

## Gotchas
- **Run `flutter analyze lib/` and `flutter test` as SEPARATE Bash calls** (chaining
  OOMs this box → exit 143), each with a generous timeout.
- **google_fonts 8.1.0 can't render text in offline `flutter test` goldens** (renders
  boxes; layout still verifiable). For readable screenshots use the web-build method
  (`flutter create . --platforms web` → `flutter build web` → serve + headless Chromium
  → Read PNG → delete `web/ build/`). Running web app boots to the auth screen (baked
  anon key ⇒ signed-out), so goldens are the only way to render an in-app screen alone.
- The safety classifier blocks the agent from: starting tunnels (cloudflared/ngrok),
  editing settings.json, disabling Supabase email confirmation, and scanning config for
  the `sbp_` token. **The user does those.**
- Backend calls are wrapped in `try/catch(_){}` → a wrong table/column **silently
  no-ops** (optimistic UI hides it). Prove writes persisted on real data.
- Seed users have no `auth.identities` row → they can't sign in (browse targets only).
- **Apply SQL to the hosted backend** via Management API
  `POST https://api.supabase.com/v1/projects/wlcrqlfqpxgtcftqllcp/database/query`
  with `{"query":"…"}` — **send a browser `User-Agent`** (python-urllib gets Cloudflare
  `1010`; curl's UA passes). Needs a `sbp_…` token the USER provides + revokes.

## Feature candidates (after group chat)
Profile editor · multiple photos / gallery · push notifications · verification
admin-approval · WebRTC video call (buttons are stubs) · iOS/TestFlight (needs Apple
Developer account $99/yr).

Start by reading `CLAUDE.md`, then this file, then ask the user which feature to build next.
