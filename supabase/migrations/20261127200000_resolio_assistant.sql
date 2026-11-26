-- Resolio : nouvelles catégories (Musculation, Cardio, Révision, Nombre de pas), Réduire libre,
-- pas synchronisés depuis le téléphone, origine des activités (Strava / Liftoff plus tard).
-- Mise à jour de la base existante : rien n'est supprimé ni recréé.
-- À coller dans Supabase → SQL Editor → Run (relancer ne fait rien de plus).

begin;

-- ---------------------------------------------------------------------
-- 1. Catégories : « Sport » devient « Musculation » ou « Cardio »
--    ('sport' reste accepté pour ne rien casser, mais n'est plus proposé)
-- ---------------------------------------------------------------------
alter table public.goals drop constraint if exists goals_cat_check;
alter table public.goals add constraint goals_cat_check
  check (cat in ('reading', 'sport', 'cardio', 'muscu', 'meditation', 'reduce', 'screen', 'steps', 'revision', 'other'));

alter table public.entries drop constraint if exists entries_cat_check;
alter table public.entries add constraint entries_cat_check
  check (cat in ('reading', 'sport', 'cardio', 'muscu', 'meditation', 'reduce', 'screen', 'steps', 'revision', 'other'));

-- sport « musculation » → muscu ; « cardio » et « peu importe » → cardio
update public.goals
set cat = case when subtype = 'muscu' then 'muscu' else 'cardio' end,
    subtype = null
where cat = 'sport';

update public.entries e
set cat = g.cat
from public.goals g
where g.id = e.goal_id and e.cat = 'sport';

-- ---------------------------------------------------------------------
-- 2. Réduire : plus limité à l'alcool ou la cigarette, l'unité est libre
-- ---------------------------------------------------------------------
update public.goals
set unit = case when subtype = 'cigarette' then 'cigarettes' else 'verres' end
where cat = 'reduce' and coalesce(unit, '') = '';

-- ---------------------------------------------------------------------
-- 3. Fil : publications « Perdu » (Réduire / Temps d'écran dépassés)
--    et publications sans saisie (Nombre de pas, Temps d'écran)
-- ---------------------------------------------------------------------
alter table public.posts drop constraint if exists posts_cat_check;
alter table public.posts add constraint posts_cat_check
  check (cat in ('reading', 'sport', 'cardio', 'muscu', 'meditation', 'reduce', 'screen', 'steps', 'revision', 'other'));

-- ---------------------------------------------------------------------
-- 4. Origine des activités : préparation de l'import Strava / Liftoff
--    (un identifiant externe ne peut être importé qu'une fois)
-- ---------------------------------------------------------------------
alter table public.entries
  add column if not exists source      text not null default 'manual',
  add column if not exists external_id text;

alter table public.entries drop constraint if exists entries_source_check;
alter table public.entries add constraint entries_source_check
  check (source in ('manual', 'strava', 'liftoff', 'health'));
alter table public.entries drop constraint if exists entries_external_id_check;
alter table public.entries add constraint entries_external_id_check
  check (external_id is null or char_length(external_id) <= 120);

create unique index if not exists entries_external_unique
  on public.entries (user_id, source, external_id)
  where external_id is not null;

-- ---------------------------------------------------------------------
-- 5. Nombre de pas par jour, lu sur le téléphone (Health Connect / Apple Santé)
-- ---------------------------------------------------------------------
create table if not exists public.daily_steps (
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  date       date not null,
  steps      integer not null check (steps >= 0 and steps <= 200000),
  updated_at timestamptz not null default now(),
  primary key (user_id, date)
);
alter table public.daily_steps enable row level security;
drop policy if exists "pas : chacun les siens" on public.daily_steps;
create policy "pas : chacun les siens" on public.daily_steps for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
grant select, insert, update, delete on public.daily_steps to authenticated;

-- ---------------------------------------------------------------------
-- 6. Mémo des popups déjà montrées (« Résolution tenue » des pas, « Perdu » du temps d'écran)
--    { "<id résolution>": { "done": "2026-11-23", "lost": "2026-11-23" } }
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists goal_marks jsonb not null default '{}'::jsonb;

commit;
