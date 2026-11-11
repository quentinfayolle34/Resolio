-- =====================================================================
-- Resolio : nouvelles catégories (Méditation, Réduire), mesures multiples,
-- liste des sports (commune) + sports perso (privés)
-- À exécuter APRÈS 20261111220000_resolio_periods.sql
-- =====================================================================

-- ---------- catégories ----------
alter table public.goals   drop constraint if exists goals_cat_check;
alter table public.goals   add  constraint goals_cat_check   check (cat in ('reading', 'sport', 'meditation', 'reduce', 'other'));
alter table public.entries drop constraint if exists entries_cat_check;
alter table public.entries add  constraint entries_cat_check check (cat in ('reading', 'sport', 'meditation', 'reduce', 'other'));

-- ---------- mesures suivies, sous-type, limite ----------
-- metrics  : ce que la résolution mesure, ex. ["count","time","distance"] (séances + minutes + km)
--            valeurs : count, time, distance, pages, quantity, days, once, limit
-- subtype  : sport → 'any' | 'cardio' | 'muscu' ; réduire → 'alcohol' | 'cigarette'
-- is_limit : true = maximum à ne pas dépasser (catégorie Réduire)
-- target_history[].targets : objectif de chaque mesure, ex. {"count":3,"time":120,"distance":20}
alter table public.goals
  add column if not exists metrics  jsonb   not null default '[]'::jsonb,
  add column if not exists subtype  text    check (subtype in ('any', 'cardio', 'muscu', 'alcohol', 'cigarette')),
  add column if not exists is_limit boolean not null default false;

-- ---------- liste commune des sports (lecture seule pour les utilisateurs) ----------
create table if not exists public.sports (
  id    serial primary key,
  name  text not null unique check (char_length(name) between 1 and 60),
  kind  text not null check (kind in ('cardio', 'muscu', 'autre'))
);
alter table public.sports enable row level security;
drop policy if exists "sports : lecture" on public.sports;
create policy "sports : lecture" on public.sports for select to authenticated using (true);
revoke all on public.sports from anon;
grant select on public.sports to authenticated;

insert into public.sports (name, kind) values
  ('Course à pied', 'cardio'), ('Marche', 'cardio'), ('Randonnée', 'cardio'), ('Trail', 'cardio'),
  ('Natation', 'cardio'), ('Vélo', 'cardio'), ('VTT', 'cardio'), ('Vélo d''appartement', 'cardio'),
  ('Rameur', 'cardio'), ('Elliptique', 'cardio'), ('Corde à sauter', 'cardio'), ('HIIT', 'cardio'),
  ('Boxe', 'cardio'), ('Danse', 'cardio'), ('Ski de fond', 'cardio'), ('Aquagym', 'cardio'),
  ('Football', 'cardio'), ('Basketball', 'cardio'), ('Handball', 'cardio'), ('Rugby', 'cardio'),
  ('Volley-ball', 'cardio'), ('Tennis', 'cardio'), ('Badminton', 'cardio'), ('Padel', 'cardio'), ('Squash', 'cardio'),
  ('Musculation (salle)', 'muscu'), ('Poids du corps', 'muscu'), ('CrossFit', 'muscu'), ('Haltérophilie', 'muscu'),
  ('Street workout', 'muscu'), ('Kettlebell', 'muscu'), ('Gainage', 'muscu'), ('Renforcement musculaire', 'muscu'),
  ('Pilates', 'muscu'), ('Escalade', 'muscu'),
  ('Yoga', 'autre'), ('Stretching', 'autre'), ('Arts martiaux', 'autre'), ('Ski', 'autre'), ('Snowboard', 'autre'),
  ('Surf', 'autre'), ('Golf', 'autre'), ('Équitation', 'autre'), ('Patinage', 'autre')
on conflict (name) do nothing;

-- ---------- sports ajoutés par un utilisateur (visibles par lui seul) ----------
create table if not exists public.user_sports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 60),
  kind        text not null default 'autre' check (kind in ('cardio', 'muscu', 'autre')),
  created_at  timestamptz not null default now(),
  unique (user_id, name)
);
alter table public.user_sports enable row level security;
drop policy if exists "sports perso : tout (les miens)" on public.user_sports;
create policy "sports perso : tout (les miens)" on public.user_sports for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
revoke all on public.user_sports from anon;
grant select, insert, update, delete on public.user_sports to authenticated;
