-- =====================================================================
-- Resolio : résolutions par jour / semaine / mois / année
-- À exécuter APRÈS 20261111200000_resolio_init.sql (SQL Editor → coller → Run)
-- =====================================================================

-- Période de chaque objectif ('week' pour les objectifs existants)
alter table public.goals
  add column if not exists period text not null default 'week'
  check (period in ('day', 'week', 'month', 'year'));

-- created_week / archived_week / target_history / injuries contiennent désormais
-- la date de début de période de l'objectif (le jour, le lundi, le 1er du mois ou le 1er janvier).
comment on column public.goals.created_week is 'Début de la période de création (jour, lundi, 1er du mois ou 1er janvier selon period)';
comment on column public.goals.archived_week is 'Début de la première période où l''objectif est archivé';
comment on column public.weeks.result is 'Bilan de la semaine (résolutions hebdomadaires uniquement)';

-- Bilans de fin de période déjà affichés : { "day": "2026-11-10", "week": "2026-11-02", "month": "2026-10-01", "year": "2025-01-01" }
alter table public.profiles
  add column if not exists recaps jsonb not null default '{}'::jsonb;
