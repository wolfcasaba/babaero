-- Voice notes on direct messages: a public URL to the audio clip (stored in
-- the existing `chat` bucket) plus its duration for the player UI. Existing
-- messages RLS already governs inserts — no policy change needed.

alter table babaero.messages
  add column if not exists voice_url text;
alter table babaero.messages
  add column if not exists voice_dur_ms int;
