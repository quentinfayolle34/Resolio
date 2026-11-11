# Resolio — notes pour Claude

Application mobile de résolutions par jour / semaine / mois / année, en **français**. Projet **Capacitor 8** (Android aujourd'hui, iOS prévu).

## Architecture
- Toute l'app est dans `www/index.html` : HTML + CSS + JavaScript vanilla, **sans bundler ni framework**. Garder ce choix sauf demande explicite.
- Les plugins Capacitor sont appelés sans import : `plugin('Preferences')`, `plugin('App')`, `plugin('Browser')`, `plugin('Share')`, `plugin('Filesystem')` (helper basé sur `window.Capacitor`). Un plugin ajouté doit aussi être installé avec npm puis `npx cap sync`.
- `IS_APP` est vrai dans l'app native ; dans le navigateur (`npm run dev`) tout doit aussi fonctionner.

## Données : Supabase uniquement (dossier `supabase/`)
- L'app est **100 % en ligne** : aucune donnée métier stockée sur le téléphone (seule la session Supabase, via Preferences). Ne pas réintroduire de stockage local des données.
- Config publique dans `www/config.js` (URL + clé publishable). Jamais de clé `service_role`/`secret` dans le dépôt.
- Bibliothèque : `www/vendor/supabase.js` (UMD, `window.supabase`), mise à jour par `npm run vendor`.
- Tout l'accès serveur passe par l'objet `backend` (`createSupabaseBackend()`), interface : auth (`signIn`, `signUp`, `signInGoogle`, `handleDeepLink`, `resetPassword`, `updatePassword`, `signOut`, `deleteAccount`) + données (`loadAll`, `saveProfile`, `uploadAvatar`, `upsertGoals`, `upsertWeeks`, `insertEntries`, `deleteEntries`, `replaceAllData`). Les tests remplacent cet objet par `window.__RESOLIO_TEST_BACKEND__`.
- État en mémoire (`state.profile`, `state.goals`, `state.weeks`) chargé par `loadData()`. Écritures : `saveGoals` / `saveWeek` / `saveProfile` mettent à jour l'écran puis envoient via `write()` (file d'attente ; en cas d'échec : message + rechargement depuis la base). `saveWeek` calcule les enregistrements ajoutés/supprimés.
- `state.phase` : `loading` | `config` | `auth` | `offline` | `setup` (compte sans objectifs) | `app`.
- **Périodes** : `g.period` = `day` | `week` | `month` | `year` (défaut `week`), fixée à la création. Une période = sa date de début (jour, lundi, 1er du mois, 1er janvier) : `periodStart` / `periodNext` / `periodPrev`. `createdWeek`, `archivedWeek`, `targetHistory[].from`, `injuries[]` contiennent des débuts de période de l'objectif (noms hérités).
- Les enregistrements restent rangés par semaine (`state.weeks[lundi].entries`, colonne `entries.week`) ; `entriesBetween(a, b)` les récupère pour n'importe quelle période ; `computePeriod(p, start, entries)` calcule le bilan.
- Type `daily` (« chaque jour ») : seulement pour les périodes semaine (max 7) et mois (max 31).
- `maintenance()` : clôture les semaines passées (`weeks.result` = résolutions hebdo seulement) puis affiche les **bilans de fin de période** (jour, semaine, mois, année) non encore vus, mémorisés dans `profile.recaps[p]` (colonne `profiles.recaps`).
- Un changement d'objectif chiffré s'ajoute à `targetHistory` à partir de la période en cours ; les périodes passées gardent leur chiffre.
- Schéma : `supabase/migrations/*.sql` (tables `profiles`, `goals`, `weeks`, `entries`, bucket `avatars`, RLS « chacun ses lignes », fonction `delete_my_account`). Nouveau champ = nouvelle migration + conversions `xxxToRow` / `xxxFromRow`.
- Connexion Google / liens email : PKCE, retour par le lien `com.quentinfayolle.resolio://auth-callback` (ou `://reset-password`) déclaré dans `AndroidManifest.xml`.
- Les données de l'ancienne version locale (clé Preferences `resolio-v1`) sont proposées à l'import au premier lancement d'un compte vide.

## Style
- Thème sombre, jaune `#f5c518` utilisé avec parcimonie (accent seulement). Polices Archivo (titres) + Inter (texte), embarquées dans `www/fonts`.
- Mobile d'abord (≈ 390 px de large), zones tactiles ≥ 44 px, safe areas via `--safe-area-inset-*` (injectées par Capacitor SystemBars) avec repli `env()`.
- Textes d'interface en français, ton direct et motivant, tutoiement.

## Commandes
- `npm run dev` : tester dans le navigateur (http://localhost:5173) — URL à autoriser dans Supabase
- `npx cap sync android` : copier `www/` dans le projet Android après une modification
- `npm run android` : ouvrir dans Android Studio
- Icônes : `python3 scripts/generate-icons.py`

## Publication
- Version dans `package.json`, puis tag `vX.Y.Z` → GitHub Actions publie l'APK signé dans Releases.
- Ne jamais committer de keystore (`*.keystore`, `*.jks`) ni de mot de passe.
