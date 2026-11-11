-- =====================================================================
-- Resolio : catégorie « Temps d'écran » (lu automatiquement sur le téléphone Android)
-- À exécuter APRÈS 20261111230000_resolio_categories.sql
-- =====================================================================

-- nouvelle catégorie + sous-types : tout le téléphone, des catégories d'applis, des applis précises
alter table public.goals drop constraint if exists goals_cat_check;
alter table public.goals add  constraint goals_cat_check check (cat in ('reading', 'sport', 'meditation', 'reduce', 'screen', 'other'));
alter table public.goals drop constraint if exists goals_subtype_check;
alter table public.goals add  constraint goals_subtype_check
  check (subtype in ('any', 'cardio', 'muscu', 'alcohol', 'cigarette', 'total', 'categories', 'apps'));

-- temps passé par application et par jour (minutes), envoyé par l'app Android
create table if not exists public.screen_time (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  date        date not null,
  package     text not null check (char_length(package) between 1 and 200),   -- ex. com.instagram.android
  app_name    text check (char_length(app_name) <= 200),
  category    text check (char_length(category) <= 30),                          -- social, video, game, audio, news, image, productivity, maps, accessibility, other
  minutes     numeric not null check (minutes >= 0 and minutes <= 1440),
  updated_at  timestamptz not null default now(),
  primary key (user_id, date, package)
);
create index if not exists screen_time_user_date_idx on public.screen_time (user_id, date);

alter table public.screen_time enable row level security;
drop policy if exists "temps d'écran : tout (le mien)" on public.screen_time;
create policy "temps d'écran : tout (le mien)" on public.screen_time for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
revoke all on public.screen_time from anon;
grant select, insert, update, delete on public.screen_time to authenticated;
