-- Demo-only: makes a conversation feel alive. Inserts a canned Tagalog reply
-- (with its English translation) from the OTHER participant, so the inline
-- translation UX is demonstrable without a second live user. Security definer
-- so it can post as the other member. Remove for production.
create or replace function babaero.demo_autoreply(conv uuid)
returns void
language plpgsql
security definer
set search_path = babaero
as $$
declare
  me uuid := auth.uid();
  other uuid;
  pick int;
  body_tl text;
  body_en text;
  replies text[][] := array[
    array['Kumusta! Natutuwa akong makilala ka 😊','Hello! Nice to meet you 😊'],
    array['Maganda ang panahon dito ngayon ☀️','The weather is beautiful here today ☀️'],
    array['Ano ang paborito mong pagkain?','What is your favorite food?'],
    array['Gusto ko ring maglakbay balang araw ✈️','I would love to travel someday too ✈️'],
    array['Salamat sa pagme-message sa akin 💕','Thank you for messaging me 💕'],
    array['Baka gusto mong mag-video call mamaya?','Maybe you would like to video call later?'],
    array['Ang bait mo naman, kinikilig ako 🙈','You are so sweet, it makes me blush 🙈']
  ];
begin
  if me is null then return; end if;
  select case when c.user_low = me then c.user_high else c.user_low end
    into other
  from babaero.conversations c
  where c.id = conv and (c.user_low = me or c.user_high = me);
  if other is null then return; end if;

  pick := 1 + floor(random() * array_length(replies, 1))::int;
  body_tl := replies[pick][1];
  body_en := replies[pick][2];

  insert into babaero.messages
    (conversation_id, sender_id, body, translated_body, source_lang, target_lang)
  values (conv, other, body_tl, body_en, 'tl', 'en');
end;
$$;

grant execute on function babaero.demo_autoreply(uuid)
  to authenticated, anon, service_role;

notify pgrst, 'reload schema';
