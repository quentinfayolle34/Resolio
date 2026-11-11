-- =====================================================================
-- Resolio : schéma de la base (Supabase / PostgreSQL)
-- À exécuter une fois : Supabase → SQL Editor → coller → Run
-- (ou `npx supabase db push` avec la CLI Supabase)
--
-- Sécurité : Row Level Security sur toutes les tables.
-- Chaque utilisateur ne peut lire / écrire QUE ses propres lignes.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Profils (1 ligne par compte, créée automatiquement à l'inscription)
-- ---------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  first_name  text not null default '' check (char_length(first_name) <= 60),
  last_name   text not null default '' check (char_length(last_name) <= 60),
  avatar_url  text check (char_length(avatar_url) <= 1000),
  birth_date  date check (birth_date is null or (birth_date > '1900-01-01' and birth_date <= current_date)),
  city        text check (char_length(city) <= 100),
  start_week  date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Objectifs
-- ---------------------------------------------------------------------
create table public.goals (
  id              text primary key check (char_length(id) between 1 and 64),
  user_id         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name            text not null check (char_length(name) between 1 and 80),
  emoji           text not null default '🎯' check (char_length(emoji) <= 16),
  cat             text not null default 'other' check (cat in ('reading', 'sport', 'other')),
  type            text not null default 'count' check (type in ('count', 'quantity', 'daily', 'once')),
  unit            text not null default '' check (char_length(unit) <= 40),
  activities      jsonb not null default '[]'::jsonb,
  distance        boolean not null default false,
  created_week    date not null,
  archived_week   date,
  position        integer not null default 0,
  target_history  jsonb not null default '[]'::jsonb,   -- [{ "from": "2026-11-09", "target": 100 }, ...]
  injuries        jsonb not null default '[]'::jsonb,   -- [{ "from": "2026-11-09", "to": null }, ...]
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index goals_user_idx on public.goals (user_id, position);

-- ---------------------------------------------------------------------
-- Semaines (clôture du lundi 00:00 + bilan)
-- ---------------------------------------------------------------------
create table public.weeks (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  week        date not null check (extract(isodow from week) = 1),   -- toujours un lundi
  closed      boolean not null default false,
  result      jsonb,
  recap_seen  boolean not null default false,
  updated_at  timestamptz not null default now(),
  primary key (user_id, week)
);

-- ---------------------------------------------------------------------
-- Enregistrements : une séance, une lecture, un jour coché…
-- ---------------------------------------------------------------------
create table public.entries (
  id          text primary key check (char_length(id) between 1 and 64),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  goal_id     text not null references public.goals (id) on delete cascade,
  week        date not null check (extract(isodow from week) = 1),
  date        date not null check (date >= week and date < week + 7),
  cat         text not null default 'other' check (cat in ('reading', 'sport', 'other')),
  amount      numeric not null default 1 check (amount >= 0),
  book        text check (char_length(book) <= 200),
  activity    text check (char_length(activity) <= 80),
  duration    numeric check (duration >= 0),
  distance    numeric check (distance >= 0),
  note        text check (char_length(note) <= 500),
  at          bigint not null default 0,     -- horodatage (ms) côté app, pour l'ordre d'affichage
  created_at  timestamptz not null default now()
);
create index entries_user_week_idx on public.entries (user_id, week);
create index entries_goal_idx on public.entries (goal_id);

-- ---------------------------------------------------------------------
-- updated_at automatique
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger goals_updated_at    before update on public.goals    for each row execute function public.set_updated_at();
create trigger weeks_updated_at    before update on public.weeks    for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Création automatique du profil à l'inscription
-- (email + mot de passe : prénom/nom envoyés par l'app ; Google : nom complet + photo)
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  meta  jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  full_name text := coalesce(meta ->> 'full_name', meta ->> 'name', '');
  first text := coalesce(nullif(meta ->> 'first_name', ''), nullif(meta ->> 'given_name', ''), split_part(full_name, ' ', 1), '');
  last  text := coalesce(nullif(meta ->> 'last_name', ''), nullif(meta ->> 'family_name', ''),
                         nullif(trim(substr(full_name, char_length(split_part(full_name, ' ', 1)) + 1)), ''), '');
begin
  insert into public.profiles (id, first_name, last_name, avatar_url)
  values (new.id, left(first, 60), left(last, 60), nullif(coalesce(meta ->> 'avatar_url', meta ->> 'picture'), ''))
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- Row Level Security : chacun ses données
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.goals    enable row level security;
alter table public.weeks    enable row level security;
alter table public.entries  enable row level security;

create policy "profil : lecture"      on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "profil : modification" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy "profil : création"     on public.profiles for insert to authenticated with check ((select auth.uid()) = id);

create policy "objectifs : tout (les miens)" on public.goals for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "semaines : tout (les miennes)" on public.weeks for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- un enregistrement ne peut viser qu'un de MES objectifs
create policy "enregistrements : tout (les miens)" on public.entries for all to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.goals g where g.id = goal_id and g.user_id = (select auth.uid()))
  );

-- les visiteurs non connectés n'ont accès à rien
revoke all on public.profiles, public.goals, public.weeks, public.entries from anon;
grant select, insert, update, delete on public.profiles, public.goals, public.weeks, public.entries to authenticated;

-- ---------------------------------------------------------------------
-- Suppression de compte (bouton dans l'app) : efface le compte et toutes ses données
-- (l'app supprime d'abord la photo via l'API Storage : Supabase interdit d'effacer les fichiers en SQL)
-- ---------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'non connecté'; end if;
  delete from auth.users where id = uid;   -- cascade : profil, objectifs, semaines, enregistrements
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------
-- Photos de profil : bucket "avatars" (lecture publique, écriture dans MON dossier uniquement)
-- Chemin des fichiers : <id utilisateur>/<nom>.jpg
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "avatars : ajout dans mon dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatars : modification de mes fichiers" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatars : suppression de mes fichiers" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatars : lecture de mes fichiers" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
