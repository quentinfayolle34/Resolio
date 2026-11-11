-- =====================================================================
-- ⚠️  REMISE À ZÉRO de la base Resolio : efface TOUTES les données
--     (résolutions, séances, profils) ET tous les comptes utilisateurs.
-- Ensuite, relancer dans l'ordre les fichiers de supabase/migrations/.
-- =====================================================================

-- création automatique du profil à l'inscription
drop trigger if exists on_auth_user_created on auth.users;

-- tables (les règles de sécurité et index partent avec)
drop table if exists public.result_likes cascade;
drop table if exists public.period_results cascade;
drop table if exists public.post_likes cascade;
drop table if exists public.posts cascade;
drop table if exists public.friendships cascade;
drop table if exists public.screen_time cascade;
drop table if exists public.user_sports cascade;
drop table if exists public.sports   cascade;
drop table if exists public.entries  cascade;
drop table if exists public.weeks    cascade;
drop table if exists public.goals    cascade;
drop table if exists public.profiles cascade;

-- fonctions
drop function if exists public.handle_new_user()   cascade;
drop function if exists public.set_updated_at()    cascade;
drop function if exists public.delete_my_account() cascade;
drop function if exists public.is_friend(uuid) cascade;
drop function if exists public.find_user_by_code(text) cascade;
drop function if exists public.my_social_profiles() cascade;
drop function if exists public.gen_friend_code(text) cascade;
drop function if exists public.protect_friend_code() cascade;

-- règles d'accès aux photos (le bucket "avatars" est conservé, il sera réutilisé)
drop policy if exists "avatars : ajout dans mon dossier"        on storage.objects;
drop policy if exists "avatars : modification de mes fichiers" on storage.objects;
drop policy if exists "avatars : suppression de mes fichiers"  on storage.objects;
drop policy if exists "avatars : lecture de mes fichiers"      on storage.objects;

drop policy if exists "photos : ajout dans mon dossier"        on storage.objects;
drop policy if exists "photos : suppression de mes fichiers"   on storage.objects;
drop policy if exists "photos : lecture de mes fichiers"       on storage.objects;

-- comptes utilisateurs (comptes de test)
delete from auth.users;
