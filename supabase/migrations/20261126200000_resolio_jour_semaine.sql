-- Resolio : plus que des résolutions « jour » et « semaine »
-- Mise à jour de la base existante : rien n'est recréé, seules les données mois / année sont retirées.
-- À coller dans Supabase → SQL Editor → Run (une seule fois ; relancer ne fait rien de plus).

begin;

-- 1. Supprime les résolutions mensuelles et annuelles.
--    Leurs saisies (entries) et les publications liées à ces saisies (posts, likes)
--    partent avec elles (clés étrangères « on delete cascade »).
delete from public.goals where period in ('month', 'year');

-- 2. Supprime les rétrospectives de mois et d'année publiées pour les amis (et leurs likes).
delete from public.period_results where period in ('month', 'year');

-- 3. Nettoie les mémos « bilan vu / rétrospective vue / publiée » du mois et de l'année.
update public.profiles
set recaps          = recaps          - 'month' - 'year',
    retro_seen      = retro_seen      - 'month' - 'year',
    retro_published = retro_published - 'month' - 'year'
where recaps ?| array['month', 'year']
   or retro_seen ?| array['month', 'year']
   or retro_published ?| array['month', 'year'];

-- 4. Empêche d'en recréer : seules les périodes « day » et « week » sont acceptées.
alter table public.goals drop constraint if exists goals_period_check;
alter table public.goals add constraint goals_period_check check (period in ('day', 'week'));

alter table public.period_results drop constraint if exists period_results_period_check;
alter table public.period_results add constraint period_results_period_check check (period = 'week');

commit;
