-- Demo data for local dev. Creates auth users + babaero.profiles so Discover
-- and Matches show real people. Emails end in @demo.local, password 'password123'.
-- Re-runnable: on_conflict do nothing.

-- Helper: create a confirmed email user with a known id.
create or replace function babaero._seed_user(uid uuid, mail text)
returns void language plpgsql as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, is_sso_user, is_anonymous
  ) values (
    '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
    mail, crypt('password123', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}', '{}',
    false, false, false
  ) on conflict (id) do nothing;
end; $$;

select babaero._seed_user('a1111111-1111-1111-1111-111111111101', 'maria@demo.local');
select babaero._seed_user('a1111111-1111-1111-1111-111111111102', 'angel@demo.local');
select babaero._seed_user('a1111111-1111-1111-1111-111111111103', 'jasmine@demo.local');
select babaero._seed_user('a1111111-1111-1111-1111-111111111104', 'camille@demo.local');
select babaero._seed_user('a1111111-1111-1111-1111-111111111105', 'grace@demo.local');
select babaero._seed_user('a1111111-1111-1111-1111-111111111106', 'liza@demo.local');
select babaero._seed_user('a1111111-1111-1111-1111-111111111107', 'nicole@demo.local');
select babaero._seed_user('a1111111-1111-1111-1111-111111111108', 'sofia@demo.local');

insert into babaero.profiles
  (id, name, age, gender, role, country, city, bio, languages, interests, verified, is_online, last_active)
values
  ('a1111111-1111-1111-1111-111111111101','Maria',26,'female','local','Philippines','Cebu City',
   'Coffee, karaoke and long walks by the sea. Looking for someone kind and honest. 🌸',
   'English, Tagalog, Cebuano', array['Karaoke','Beach','Cooking','Travel'], true, true, now()),
  ('a1111111-1111-1111-1111-111111111102','Angel',24,'female','local','Philippines','Davao City',
   'Nurse by day, foodie by night. Teach me your language and I''ll teach you mine. 😊',
   'English, Tagalog', array['Foodie','Movies','Fitness'], true, false, now() - interval '2 hours'),
  ('a1111111-1111-1111-1111-111111111103','Jasmine',29,'female','local','Philippines','Manila',
   'Small business owner. Family-oriented, faith is important to me. Serious connections only.',
   'English, Tagalog', array['Business','Faith','Family','Dogs'], false, true, now()),
  ('a1111111-1111-1111-1111-111111111104','Camille',27,'female','local','Philippines','Iloilo City',
   'Teacher who loves the mountains and the sea equally. Looking for my travel partner. ✈️',
   'English, Tagalog, Hiligaynon', array['Hiking','Books','Photography','Travel'], true, true, now()),
  ('a1111111-1111-1111-1111-111111111105','Grace',31,'female','local','Philippines','Quezon City',
   'Yoga, plants, and Sunday markets. Kindness is my love language. 🌿',
   'English, Tagalog', array['Fitness','Cooking','Music'], true, false, now() - interval '1 day'),
  ('a1111111-1111-1111-1111-111111111106','Liza',23,'female','local','Philippines','Baguio City',
   'Cafe-hopping in the mountains. Show me you can make me laugh. 😄',
   'English, Tagalog, Ilocano', array['Foodie','Photography','Dancing'], false, true, now()),
  ('a1111111-1111-1111-1111-111111111107','Nicole',28,'female','local','Philippines','Bacolod City',
   'Sweet tooth from the City of Smiles. Looking for something real and lasting. 💕',
   'English, Tagalog, Hiligaynon', array['Cooking','Movies','Family'], true, true, now()),
  ('a1111111-1111-1111-1111-111111111108','Sofia',30,'female','local','Philippines','Tagbilaran',
   'Island girl, dive instructor, ocean lover. Let''s explore Bohol together. 🐠',
   'English, Tagalog, Cebuano', array['Beach','Travel','Fitness','Photography'], true, true, now())
on conflict (id) do nothing;

-- Demo profile photos (public sample portraits).
update babaero.profiles set photos=array['https://randomuser.me/api/portraits/women/68.jpg'] where name='Maria';
update babaero.profiles set photos=array['https://randomuser.me/api/portraits/women/44.jpg'] where name='Angel';
update babaero.profiles set photos=array['https://randomuser.me/api/portraits/women/90.jpg'] where name='Jasmine';
update babaero.profiles set photos=array['https://randomuser.me/api/portraits/women/65.jpg'] where name='Camille';
update babaero.profiles set photos=array['https://randomuser.me/api/portraits/women/12.jpg'] where name='Grace';
update babaero.profiles set photos=array['https://randomuser.me/api/portraits/women/79.jpg'] where name='Liza';
update babaero.profiles set photos=array['https://randomuser.me/api/portraits/women/50.jpg'] where name='Nicole';
update babaero.profiles set photos=array['https://randomuser.me/api/portraits/women/33.jpg'] where name='Sofia';
