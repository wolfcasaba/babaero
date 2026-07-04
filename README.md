# Babaero

A Flutter dating/chat app where **foreigners meet Filipinas** — trust-first
(photo & video verification) with **built-in EN↔Tagalog translation** shown
inline in every chat bubble.

## Stack

- Flutter 3.44 · Dart `^3.12.2`
- Riverpod 3 (hand-written providers, no codegen)
- supabase_flutter 2.15 → **own isolated local Supabase stack**
- google_fonts (Poppins/Inter) · lucide_icons_flutter
- Feature-first architecture, repository-provider pattern

## Brand

Night-luxe: crimson-rose `#E01E5A` → coral `#FF7A59`, gold accent `#F5B54A`,
dark default theme. Tokens in `lib/core/theme/app_colors.dart`.

## Backend (local, isolated)

Babaero runs its **own** Supabase stack (separate from any other local project):

| Service | URL |
|---|---|
| API     | http://127.0.0.1:54331 |
| DB      | postgresql://postgres:postgres@127.0.0.1:54332/postgres |
| Studio  | http://127.0.0.1:54333 |

Tables live in the dedicated **`babaero`** Postgres schema (see
`supabase/migrations/00000000000001_babaero_init.sql`): profiles,
verifications, likes, matches, conversations, messages — with RLS and a
mutual-like → match+conversation trigger.

```bash
cd ~/babaero
supabase start          # boots the stack + applies migrations
supabase status         # URLs + keys
supabase stop           # shut down
```

Query from Dart via the schema-scoped helper:

```dart
final rows = await SupabaseConfig.db.from('profiles').select();
```

## Run

```bash
flutter pub get
flutter run             # uses the local stack by default (127.0.0.1:54331)
# device/emulator → override the host:
flutter run --dart-define=SUPABASE_URL=http://<box-lan-ip>:54331
```

No key / not signed in → **mock mode** (in-memory seed profiles), so previews
render without a backend.

## Demo accounts

8 seeded profiles (`supabase/seed.sql`), all `password123`:
`maria@demo.local`, `angel@demo.local`, `jasmine@demo.local`, `camille@demo.local`,
`grace@demo.local`, `liza@demo.local`, `nicole@demo.local`, `sofia@demo.local`.
Or just create a fresh account in-app.

## Status — functional end-to-end

- **Auth**: email/password sign-up/in, root `AuthGate`, onboarding profile setup.
- **Discover**: real profiles, like / super-like / pass. Liking calls the
  `like_profile` RPC; for a lively local demo the target likes back ~65% of the
  time, forming a match (mutual-like trigger) → **It's a Match** dialog.
- **Matches**: real matches grid + "likes you" count.
- **Chat**: realtime 1:1 messaging (Supabase `.stream()`), send box, and a demo
  auto-reply so conversations feel alive.
- **Translation**: outgoing text is translated (pluggable `TranslationService`,
  offline EN↔Tagalog mock) and shown inline under messages. Swap in a real API
  or edge function via `translationService` in code.
- **Verification**: submit photo/video request → pending → verified badge.
- **Photos**: pick from gallery → uploaded to the public `avatars` storage
  bucket (per-user folder, RLS-protected) → shown on cards, avatars, detail.
- **Translation**: real EN↔Tagalog via **MyMemory** (free, no key) with an
  offline phrase-map fallback.

### Not yet
WebRTC video calling (buttons are stubs) · push notifications · multi-photo
galleries · pass-persistence.

### Backend migrations
`supabase/migrations/`: `..01` schema+RLS+match trigger · `..02` `like_profile` ·
`..03` `get_or_create_conversation` + realtime publication · `..04` `demo_autoreply` ·
`..05` `avatars` storage bucket + RLS.
