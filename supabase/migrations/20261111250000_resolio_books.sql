-- =====================================================================
-- Resolio : « livre terminé » (badge Bibliophile, total des livres lus)
-- À exécuter APRÈS 20261111240000_resolio_screen_time.sql
-- =====================================================================
alter table public.entries
  add column if not exists book_finished boolean not null default false;
