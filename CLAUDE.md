# Babaero

**Flutter dating/chat app — foreigners ↔ Filipinas.** Trust-first (photo/video
verification) + built-in **EN↔Tagalog translation** (the killer feature, shown
inline in chat bubbles and on timeline posts). Greenfield app, **separate** from
recipewiser-mobile; mirrors its Flutter/Riverpod/Supabase conventions.

- Code: `~/babaero` (Flutter, package `babaero`, appId `com.babaero.babaero`, git branch `main`)
- GitHub: https://github.com/wolfcasaba/babaero
- Android APK (public tap-to-install): https://github.com/wolfcasaba/babaero/releases/latest/download/app-release.apk

---

## Tech Stack

Flutter 3.44 (Dart `^3.9`) · **Riverpod 3** (`flutter_riverpod`, hand-written providers, NO codegen) · `supabase_flutter ^2.15` · `dio` (translation HTTP) · `google_fonts` (Poppins headings + Inter body) · `lucide_icons_flutter` · `cached_network_image` · `image_picker` · `flutter_animate` · `shared_preferences` (backend override).

- Navigation is imperative `Navigator.push(MaterialPageRoute(...))` — match it, don't introduce go_router.
- Root shell = `HomeShell` bottom nav with `IndexedStack` (keeps tab state): **Discover / Feed / Matches / Messages / Profile**.

---

## Architecture — feature-first

```
lib/
├── core/
│   ├── supabase/supabase_config.dart   # hosted URL + anon key + `babaero` schema; runtime override
│   ├── theme/                          # app_colors, app_theme, theme_mode_provider
│   └── widgets/brand_widgets.dart      # BrandWordmark, GradientButton, ProfileAvatar, VerifiedBadge, OnlineDot
└── features/<feature>/                 # auth, onboarding, discover, matches, chat, timeline, profile, home
    ├── <name>_screen.dart
    ├── widgets/
    └── data/
        ├── <name>_models.dart      # plain Dart, parse at the boundary (Model.fromMap)
        ├── <name>_repository.dart  # abstract + Supabase impl + Preview (mock) impl
        └── <name>_provider.dart    # hand-written Riverpod providers
```

**Implementation order:** models → repository → provider → screen/widgets.

---

## Riverpod 3 conventions (IMPORTANT)

- **Hand-written providers, no `@riverpod` codegen.**
- `StateProvider` is removed in Riverpod 3 — use `Notifier<T>` + `NotifierProvider`, or `AsyncNotifier` for async. Plain DI/derived = `Provider<T>`.
- **Repository-provider pattern** (used everywhere): the provider returns the real Supabase repo when `SupabaseConfig.isConfigured && SupabaseConfig.isSignedIn`, otherwise a `Preview…Repository` (in-memory seed) so mock-mode / logged-out previews render. Watch `currentUserIdProvider` in the repo provider so it re-picks on auth changes.
- Never capture a stale `DateTime.now()` in provider state.

---

## Backend — HOSTED Supabase (shared from any device)

- Project **"Babaero"**, ref `wlcrqlfqpxgtcftqllcp`, URL `https://wlcrqlfqpxgtcftqllcp.supabase.co`. Anon key baked in `supabase_config.dart` (public by design).
- Tables live in a **dedicated `babaero` Postgres schema** (NOT `public`). Query via `SupabaseConfig.db.from('<table>')` (schema-scoped) — never `client.from(...)`.
- **Tables:** `profiles`, `verifications`, `likes`, `matches`, `conversations`, `messages`, `posts`, `post_likes`, `post_comments`. **RPCs:** `like_profile(target, is_super)`, `get_or_create_conversation(other)`, `demo_autoreply(conv)`. Migrations in `supabase/migrations/` (numbered `000000000000NN_babaero_*.sql`) — the authoritative schema source.
- Runtime backend-URL override: gear on WelcomeScreen → `BackendPrefs` (shared_preferences) → `SupabaseConfig.init` prefers it. `X-Babaero-Access` header support exists for gated tunnels.

### Applying SQL to the hosted DB
No Supabase MCP for babaero (the session's supabase MCP points at recipewiser). Apply migrations via the **Management API**:
`POST https://api.supabase.com/v1/projects/wlcrqlfqpxgtcftqllcp/database/query` with `{"query":"…"}` — **send a browser `User-Agent`** (python-urllib gets Cloudflare `1010`; curl's UA passes). Needs a Management token (`sbp_…`) the **USER provides ad-hoc and revokes after**. Strip `alter role authenticator …` / `notify pgrst …` lines (hosted manages PostgREST). To expose a new schema: `PATCH /config/postgrest {db_schema}`.

### ⚠️ Silent no-op trap
Backend calls are wrapped in `try { … } catch (_) {}` → a wrong table/column name **silently no-ops** (optimistic UI hides it). When wiring a write, **prove it persisted** (real-data check), don't trust the UI. Verify exact table/column names against the migration SQL, not memory.

---

## Translation (the killer feature)

`TranslationService` (`features/chat/data/translation_service.dart`) — pluggable. Global `translationService = HttpTranslationService()` calls **MyMemory** (free, no key, EN↔Tagalog) with an offline `MockTranslationService` phrase-map fallback + cache. Outgoing chat text is translated on send (stored in `messages.translated_body`, shown inline under Tagalog bubbles). Timeline posts get an on-demand "See translation" toggle via `translationService.toCounterpart`. **Do NOT remove the `demo_autoreply` liveliness reply** (user directive).

---

## Brand Design

Dark-default "night-luxe". Tokens in `core/theme/app_colors.dart` — use them, never hardcode hex: **primary `#E01E5A`** (crimson-rose), **secondary `#FF7A59`** (coral), **accent `#F5B54A`** (gold), `brandGradient [primary, secondary]` top-left→bottom-right, `verified #2ECC9B`, `online #43D67C`. Poppins for headings/wordmark, Inter for body.

---

## Build / deploy (CRITICAL)

- **The APK CANNOT be built on this Linux/ARM64 box** (no arm64 `gen_snapshot`, `aapt2` is x86-only, no amd64 qemu). Builds go through **GitHub Actions CI** (`.github/workflows/build-apk.yml`, ubuntu-latest) → publishes a **GitHub Release** asset (tag `v1.0.<run_number>`, `make_latest`) → the APK link above.
- **To ship:** bump `version:` in `pubspec.yaml` (Android versionCode, so it installs as an update) → commit → `git push origin main` → CI builds. Tell the user to **uninstall + reinstall** (and reboot for the launcher icon cache).
- **Keep `<uses-permission android:name="android.permission.INTERNET"/>`** in `android/app/src/main/AndroidManifest.xml` — the main manifest, not just debug/profile overlays. Without it the release APK can't network ("Can't reach the server").
- **This box's GitHub token lacks `workflow` scope** → you CANNOT push/edit `.github/workflows/*`. The user edits workflow files in the GitHub web UI.

---

## Commands (this Oracle ARM box)

**Flutter is NOT on PATH** — prefix commands:
```bash
export PATH="$PATH:$HOME/flutter/bin"
flutter pub get
flutter analyze lib/        # run ALONE
flutter test                # run ALONE, SEPARATE Bash call
```
- **NEVER chain `flutter analyze && flutter test`** — combined memory → OOM (exit 143). Two separate calls, generous timeouts (≥240s). `free -m` before heavy runs is cheap insurance.
- Foreground `sleep` is blocked (exit 144 — background + poll, or the Monitor tool).

### Local VISUAL verification
- **google_fonts 8.1.0 CANNOT render text in offline `flutter test` goldens** — it looks up exact weight families (`Poppins-SemiBold`) in its own private set, ignores Flutter `FontLoader`, and throws (or async-throws on the blocked gstatic fetch); text renders as boxes. Layout is still verifiable via a golden (`matchesGoldenFile` + `--update-goldens`, then `Read` the PNG); for readable text use the **web build** method: `flutter create . --platforms web` → `flutter build web` → serve local + headless Chromium (cached at `~/.cache/ms-playwright/chromium-1217/…`, swiftshader flags) → Read the PNG, then delete `web/ build/`. NOTE the running web app boots to the auth screen (baked anon key ⇒ signed-out), so goldens are the only way to render an in-app screen in isolation.

### Classifier gotchas (the USER does these, not the agent)
Starting tunnels (cloudflared/ngrok), editing settings.json, disabling Supabase email confirmation, and scanning config for the `sbp_` token are all blocked for the agent. Ask the user.

---

## Tooling — code intelligence

- **Code RAG:** `node tools/flutter-rag.mjs "<query>"` (semantic search over `lib/`; `--reindex` to refresh). Use for conceptual questions ("where do we translate messages") before grep. Embedding keys come from `~/Recipewiser/.env.local`.
- **Dart MCP** (`mcp__dart__*`, wired in `.mcp.json`): analyze/hot-reload/pub/lsp etc. — prefer over raw `flutter` shell where it fits.
- **context7 MCP** — current library/API docs.
- **Viking** shared "second brain" (`mcp__viking__*`, same `claude-code` lane as the web + recipewiser-mobile): `viking_search` at task start, `viking_remember` on novelty, `viking_session_commit` at feature end. Cross-project lessons flow both ways.
- **Project agents** (`.claude/agents/babaero-*`): reviewer, debugger, devil-advocate, performance, test-writer, analyze-fixer — all babaero-aware (hosted Supabase, `babaero` schema, silent-no-op trap, OOM rule). **Skills** (`.claude/skills/`): verify-before-done (the gate), review-loop, systematic-debugging, tdd, session-learning, etc.

---

## Known gotchas

1. **Auth gate:** most features require sign-in; logged-out → Preview repos / mock data.
2. **Seed users can't sign in** — they have no `auth.identities` row (browse targets only). Real users sign up normally.
3. **Email confirmation is toggled in the dashboard by the user** (agent can't change it). `AuthScreen` handles the no-session "confirm your email" case.
4. `try/catch(_){}` around backend calls hides failures — prove persistence on real data.

---

## IMPORTANT RULES

- **Communicate with the user in HUNGARIAN.** All code, comments, UI strings, identifiers in **ENGLISH**.
- **Verify before "done":** `flutter analyze lib/` clean + `flutter test` green (SEPARATE calls). For UI, a visual check.
- Match existing patterns (Navigator nav, hand-written Riverpod, repository-provider, feature-first) — don't introduce new conventions ad hoc.

> Schema source of truth: `supabase/migrations/*.sql` · Handoff notes: `HANDOFF.md`
