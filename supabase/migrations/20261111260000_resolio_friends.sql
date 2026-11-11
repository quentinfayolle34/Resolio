-- =====================================================================
-- Resolio : amis, fil d'activité (publications + photos + likes), rétrospectives
-- À exécuter APRÈS 20261111250000_resolio_books.sql
--
-- Confidentialité :
--   - un ami ne voit JAMAIS directement tes résolutions ni tes saisies ;
--   - il voit uniquement ce que tu publies (posts) et tes bilans de fin de période (period_results),
--     qui ne contiennent que tes résolutions « Public » ;
--   - de ton profil, il ne voit que prénom, nom, photo, code ami et badges (fonction my_social_profiles).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Profil : code ami unique, badges visibles par les amis, rétrospectives vues / publiées
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists friend_code     text unique,
  add column if not exists public_stats    jsonb not null default '{}'::jsonb,   -- { streak, best, badges: [niveaux] }
  add column if not exists retro_seen      jsonb not null default '{}'::jsonb,   -- { week: '2026-11-02', month: ..., year: ... }
  add column if not exists retro_published jsonb not null default '{}'::jsonb;

create or replace function public.gen_friend_code(first text)
returns text language plpgsql set search_path = '' as $$
declare base text; code text;
begin
  base := upper(left(regexp_replace(translate(coalesce(first, ''),
            'àâäáãéèêëíìîïóòôöõúùûüçñÀÂÄÁÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÇÑ', 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'),
            '[^A-Za-z]', '', 'g'), 4));
  if char_length(base) < 3 then base := 'RESO'; end if;
  loop
    code := base || '-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 4));
    exit when not exists (select 1 from public.profiles where friend_code = code);
  end loop;
  return code;
end $$;

-- code attribué à la création du profil, et jamais modifiable ensuite
create or replace function public.protect_friend_code()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.friend_code is null then new.friend_code := public.gen_friend_code(new.first_name); end if;
  else
    new.friend_code := old.friend_code;
  end if;
  return new;
end $$;
drop trigger if exists profiles_friend_code on public.profiles;
create trigger profiles_friend_code before insert or update on public.profiles
  for each row execute function public.protect_friend_code();

-- comptes existants : on leur donne un code
alter table public.profiles disable trigger profiles_friend_code;
update public.profiles set friend_code = public.gen_friend_code(first_name) where friend_code is null;
alter table public.profiles enable trigger profiles_friend_code;

-- ---------------------------------------------------------------------
-- Résolutions : visibles ou non dans la rétrospective des amis
-- ---------------------------------------------------------------------
alter table public.goals add column if not exists shared boolean not null default true;
update public.goals set shared = false where cat in ('reduce', 'screen');

-- ---------------------------------------------------------------------
-- Amitiés : demande (pending) puis acceptation (accepted)
-- ---------------------------------------------------------------------
create table if not exists public.friendships (
  id         uuid primary key default gen_random_uuid(),
  requester  uuid not null default auth.uid() references auth.users (id) on delete cascade,
  addressee  uuid not null references auth.users (id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  check (requester <> addressee)
);
create unique index if not exists friendships_pair_idx on public.friendships (least(requester, addressee), greatest(requester, addressee));

alter table public.friendships enable row level security;
drop policy if exists "amitiés : voir les miennes" on public.friendships;
drop policy if exists "amitiés : demander" on public.friendships;
drop policy if exists "amitiés : accepter" on public.friendships;
drop policy if exists "amitiés : supprimer" on public.friendships;
create policy "amitiés : voir les miennes" on public.friendships for select to authenticated
  using ((select auth.uid()) in (requester, addressee));
create policy "amitiés : demander" on public.friendships for insert to authenticated
  with check (requester = (select auth.uid()) and status = 'pending');
create policy "amitiés : accepter" on public.friendships for update to authenticated
  using (addressee = (select auth.uid())) with check (addressee = (select auth.uid()) and status = 'accepted');
create policy "amitiés : supprimer" on public.friendships for delete to authenticated
  using ((select auth.uid()) in (requester, addressee));
revoke all on public.friendships from anon;
grant select, insert, update, delete on public.friendships to authenticated;

-- « other » est-il mon ami (accepté) ?
create or replace function public.is_friend(other uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester = auth.uid() and f.addressee = other) or (f.addressee = auth.uid() and f.requester = other))
  );
$$;
revoke all on function public.is_friend(uuid) from public, anon;
grant execute on function public.is_friend(uuid) to authenticated;

-- trouver quelqu'un par son code ami (renvoie seulement prénom, nom, photo)
create or replace function public.find_user_by_code(code text)
returns table (id uuid, first_name text, last_name text, avatar_url text)
language sql stable security definer set search_path = '' as $$
  select p.id, p.first_name, p.last_name, p.avatar_url
  from public.profiles p
  where auth.uid() is not null and p.friend_code = upper(trim(code)) and p.id <> auth.uid();
$$;
revoke all on function public.find_user_by_code(text) from public, anon;
grant execute on function public.find_user_by_code(text) to authenticated;

-- profils (limités) des personnes avec qui j'ai une amitié ou une demande en cours
create or replace function public.my_social_profiles()
returns table (id uuid, first_name text, last_name text, avatar_url text, friend_code text, public_stats jsonb)
language sql stable security definer set search_path = '' as $$
  select p.id, p.first_name, p.last_name, p.avatar_url, p.friend_code,
         case when f.status = 'accepted' then p.public_stats else '{}'::jsonb end
  from public.friendships f
  join public.profiles p on p.id = case when f.requester = auth.uid() then f.addressee else f.requester end
  where auth.uid() in (f.requester, f.addressee);
$$;
revoke all on function public.my_social_profiles() from public, anon;
grant execute on function public.my_social_profiles() to authenticated;

-- ---------------------------------------------------------------------
-- Publications (fil d'activité) : une saisie partagée
-- ---------------------------------------------------------------------
create table if not exists public.posts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  entry_id    text references public.entries (id) on delete cascade,   -- saisie retirée = publication retirée
  goal_name   text check (char_length(goal_name) <= 80),
  goal_emoji  text check (char_length(goal_emoji) <= 16),
  cat         text check (cat in ('reading', 'sport', 'meditation', 'screen', 'other')),   -- jamais 'reduce'
  body        text check (char_length(body) <= 300),
  note        text check (char_length(note) <= 500),
  photo_url   text check (char_length(photo_url) <= 1000),
  created_at  timestamptz not null default now()
);
create index if not exists posts_user_created_idx on public.posts (user_id, created_at desc);

alter table public.posts enable row level security;
drop policy if exists "posts : moi et mes amis" on public.posts;
drop policy if exists "posts : publier" on public.posts;
drop policy if exists "posts : supprimer les miens" on public.posts;
create policy "posts : moi et mes amis" on public.posts for select to authenticated
  using (user_id = (select auth.uid()) or public.is_friend(user_id));
create policy "posts : publier" on public.posts for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and (entry_id is null or exists (select 1 from public.entries e where e.id = entry_id and e.user_id = (select auth.uid())))
  );
create policy "posts : supprimer les miens" on public.posts for delete to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.posts from anon;
grant select, insert, delete on public.posts to authenticated;

create table if not exists public.post_likes (
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table public.post_likes enable row level security;
drop policy if exists "likes posts : voir" on public.post_likes;
drop policy if exists "likes posts : aimer" on public.post_likes;
drop policy if exists "likes posts : retirer" on public.post_likes;
create policy "likes posts : voir" on public.post_likes for select to authenticated
  using (exists (select 1 from public.posts p where p.id = post_id));          -- si je peux voir la publication
create policy "likes posts : aimer" on public.post_likes for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.posts p where p.id = post_id));
create policy "likes posts : retirer" on public.post_likes for delete to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.post_likes from anon;
grant select, insert, delete on public.post_likes to authenticated;

-- ---------------------------------------------------------------------
-- Rétrospectives : bilan de fin de semaine / mois / année (résolutions « Public » seulement)
-- ---------------------------------------------------------------------
create table if not exists public.period_results (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  period      text not null check (period in ('week', 'month', 'year')),
  start       date not null,
  validated   boolean not null,
  goals       jsonb not null default '[]'::jsonb,   -- [{ name, emoji, status: ok|ko|injured, text }]
  created_at  timestamptz not null default now(),
  unique (user_id, period, start)
);
alter table public.period_results enable row level security;
drop policy if exists "bilans : moi et mes amis" on public.period_results;
drop policy if exists "bilans : les miens" on public.period_results;
create policy "bilans : moi et mes amis" on public.period_results for select to authenticated
  using (user_id = (select auth.uid()) or public.is_friend(user_id));
create policy "bilans : les miens" on public.period_results for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke all on public.period_results from anon;
grant select, insert, update, delete on public.period_results to authenticated;

create table if not exists public.result_likes (
  result_id  uuid not null references public.period_results (id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (result_id, user_id)
);
alter table public.result_likes enable row level security;
drop policy if exists "likes bilans : voir" on public.result_likes;
drop policy if exists "likes bilans : aimer" on public.result_likes;
drop policy if exists "likes bilans : retirer" on public.result_likes;
create policy "likes bilans : voir" on public.result_likes for select to authenticated
  using (exists (select 1 from public.period_results r where r.id = result_id));
create policy "likes bilans : aimer" on public.result_likes for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.period_results r where r.id = result_id));
create policy "likes bilans : retirer" on public.result_likes for delete to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.result_likes from anon;
grant select, insert, delete on public.result_likes to authenticated;

-- ---------------------------------------------------------------------
-- Photos des publications : bucket "posts" (lecture publique par lien, écriture dans MON dossier)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('posts', 'posts', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "photos : ajout dans mon dossier" on storage.objects;
drop policy if exists "photos : suppression de mes fichiers" on storage.objects;
drop policy if exists "photos : lecture de mes fichiers" on storage.objects;
create policy "photos : ajout dans mon dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'posts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "photos : suppression de mes fichiers" on storage.objects for delete to authenticated
  using (bucket_id = 'posts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "photos : lecture de mes fichiers" on storage.objects for select to authenticated
  using (bucket_id = 'posts' and (storage.foldername(name))[1] = (select auth.uid())::text);
