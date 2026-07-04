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

## Current status / immediate TODO
1. **Apply Timeline migration `00000000000006_babaero_timeline.sql` to the hosted DB.**
   Not applied yet. Until then, the Feed tab shows "Feed unavailable" for signed-in
   users (the `posts` table doesn't exist yet) — logged-out/preview shows demo posts.
   Apply via the Management API (see CLAUDE.md → "Applying SQL"); needs a `sbp_…` token
   the **user pastes ad-hoc and revokes after**.
2. **Group chat** is the next feature the user wants (they asked for Timeline + group
   chat; Timeline was built first). Build it as a **SEPARATE `group_*` subsystem** so
   the working 1:1 chat + `demo_autoreply` + translation stay untouched — the user
   explicitly said **do not remove the auto-reply**. Current chat is strictly 2-person
   (`conversations.user_low`/`user_high` + unique constraint), so groups need new tables.

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
