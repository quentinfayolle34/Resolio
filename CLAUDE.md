# Resolio — notes pour Claude

Application mobile d'objectifs hebdomadaires, en **français**. Projet **Capacitor 8** (Android aujourd'hui, iOS prévu).

## Architecture
- Toute l'app est dans `www/index.html` : HTML + CSS + JavaScript vanilla, **sans bundler ni framework**. Garder ce choix sauf demande explicite.
- Les plugins Capacitor sont appelés sans import : `plugin('Preferences')`, `plugin('App')`, `plugin('Share')`, `plugin('Filesystem')` (helper défini en haut du script, basé sur `window.Capacitor`). Un plugin ajouté doit aussi être installé avec npm puis `npx cap sync`.
- `IS_APP` est vrai dans l'app native ; dans le navigateur (`npm run dev`), le stockage bascule sur `localStorage` : l'app doit toujours fonctionner dans les deux cas.
- Stockage : un seul objet JSON `{ profile, goals: { items }, weeks: { 'YYYY-MM-DD': { week, entries, closed, result, recapSeen } } }` sous la clé `resolio-v1`. Toute évolution du format doit rester compatible avec les données existantes et les sauvegardes exportées.
- Les semaines commencent le **lundi** (clé = date du lundi, heure locale). `maintenance()` clôture les semaines passées et calcule `result`.
- Un changement d'objectif chiffré s'ajoute à `targetHistory` à partir de la semaine en cours ; les semaines clôturées gardent leur snapshot.

## Synchronisation (serveur PocketBase, dossier `server/`)
- Le téléphone reste la source de vérité au quotidien ; la synchro est un bonus (l'app doit toujours marcher hors ligne / sans compte).
- État dans `state.sync` (persisté sous `blob.sync`) : url, token, `dirty` (profil / objectifs / clés de semaines à envoyer), `srv` (id local -> id serveur), `lastPull`.
- Toute écriture passe par `saveGoals` / `saveWeek` / `saveProfile` (ou `store.save` + `markDirty` dans `maintenance()`), qui marquent les données à envoyer. Les données reçues du serveur sont écrites avec `store.save` SANS `markDirty`.
- `runSync()` : rafraîchit le token, `pushAll()` puis `pullAll()` (enregistrements `updated >= lastPull`). Les séances retirées sont marquées `deleted = true` côté serveur, jamais supprimées.
- Schéma : `server/pb_migrations/*.js` (tables `goals`, `weeks`, `entries` + champ `users.start_week`), règles "chaque utilisateur ne voit que ses données". Un nouveau champ = une nouvelle migration + mise à jour de `goalToRec`/`recToGoal`/`entryToRec`/`recToEntry`.
- Tester : lancer PocketBase (`cd server && docker compose up -d --build`, ou le binaire avec `--migrationsDir=server/pb_migrations`) puis `npm run dev`.

## Style
- Thème sombre, jaune `#f5c518` utilisé avec parcimonie (accent seulement). Polices Archivo (titres) + Inter (texte), embarquées dans `www/fonts`.
- Mobile d'abord (≈ 390 px de large), zones tactiles ≥ 44 px, safe areas via `--safe-area-inset-*` (injectées par Capacitor SystemBars) avec repli `env()`.
- Textes d'interface en français, ton direct et motivant, tutoiement.

## Commandes
- `npm run dev` : tester dans le navigateur (http://localhost:5173)
- `npx cap sync android` : copier `www/` dans le projet Android après une modification
- `npm run android` : ouvrir dans Android Studio
- Icônes : `python3 scripts/generate-icons.py`

## Publication
- Version dans `package.json`, puis tag `vX.Y.Z` → GitHub Actions publie l'APK signé dans Releases.
- Ne jamais committer de keystore (`*.keystore`, `*.jks`) ni de mot de passe.
