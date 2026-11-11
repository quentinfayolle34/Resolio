# Base de données Resolio (Supabase)

Resolio stocke **toutes** ses données dans Supabase (base PostgreSQL + comptes + photos).
L'application ne garde rien sur le téléphone, à part la session de connexion.

- Projet : `https://dtvmkqeohhlwwviphnkz.supabase.co`
- Config de l'app : [`www/config.js`](../www/config.js) (URL + clé *publishable*, publiques)
- Schéma : [`migrations/20261111200000_resolio_init.sql`](migrations/20261111200000_resolio_init.sql)

> 🔒 Ne mets **jamais** la clé `service_role` / `secret` ni le mot de passe de la base dans l'app ou sur GitHub.

---

## 1. Créer les tables (une seule fois)

1. Supabase → ton projet → **SQL Editor** → **New query**.
2. Copie tout le contenu de `migrations/20261111200000_resolio_init.sql`, colle-le, clique sur **Run**.
3. Vérifie dans **Table Editor** : tu dois voir `profiles`, `goals`, `weeks`, `entries` (avec le cadenas *RLS enabled*), et dans **Storage** le bucket `avatars`.

| Table | Contenu |
| --- | --- |
| `profiles` | Prénom, nom, photo, date de naissance, ville, semaine de départ (1 ligne par compte, créée automatiquement) |
| `goals` | Objectifs (nom, emoji, catégorie, type, unité, historique des chiffres, pauses blessure, archivage) |
| `weeks` | Une ligne par semaine : clôturée, bilan, bilan vu |
| `entries` | Chaque séance / lecture / jour coché |

Sécurité (Row Level Security) : chaque utilisateur ne peut lire et modifier **que ses propres lignes** ; les visiteurs non connectés n'ont accès à rien. Les photos sont rangées dans `avatars/<id utilisateur>/`.

---

## 2. Réglages de connexion

**Authentication → URL Configuration**

- **Site URL** : `com.quentinfayolle.resolio://auth-callback`
- **Redirect URLs** → *Add URL* :
  - `com.quentinfayolle.resolio://**` (retour dans l'app : Google, confirmation d'email, mot de passe oublié)
  - `http://localhost:5173/**` (tests dans le navigateur avec `npm run dev`)

**Authentication → Sign In / Providers → Email**

- *Enable Email provider* : activé
- *Confirm email* : activé (recommandé : l'utilisateur doit cliquer sur le lien reçu)
- *Minimum password length* : 8

> 📧 Le service d'email intégré de Supabase est limité à quelques messages par heure : parfait pour tester, pas pour beaucoup d'utilisateurs. Plus tard : *Authentication → Emails → SMTP Settings* avec un service comme Brevo ou Resend (gratuits pour de petits volumes). Tu peux aussi traduire les emails en français dans *Authentication → Emails → Templates*.

---

## 3. Connexion avec Google

### a) Côté Google (Google Cloud Console)

1. Va sur https://console.cloud.google.com → crée un projet **Resolio**.
2. **APIs & Services → OAuth consent screen** (ou *Google Auth Platform → Branding*) :
   - Type : **External**, nom de l'app : **Resolio**, email d'assistance : le tien.
   - Scopes : `openid`, `email`, `profile` (ceux par défaut).
   - Tant que l'app est en mode *Testing*, ajoute ton adresse Gmail dans **Test users** (ou clique sur *Publish app* pour l'ouvrir à tous).
3. **APIs & Services → Credentials → Create credentials → OAuth client ID** :
   - Type : **Web application**, nom : `Resolio Supabase`
   - **Authorized redirect URIs** : `https://dtvmkqeohhlwwviphnkz.supabase.co/auth/v1/callback`
4. Copie le **Client ID** et le **Client secret**.

### b) Côté Supabase

**Authentication → Sign In / Providers → Google** → active-le, colle le *Client ID* et le *Client secret* → **Save**.

> Le *Client secret* Google se colle uniquement dans Supabase, jamais dans l'app ni sur GitHub.

### Comment ça marche dans l'app

« Continuer avec Google » ouvre la page Google dans le navigateur du téléphone ; une fois connecté, Google renvoie vers `com.quentinfayolle.resolio://auth-callback`, qui rouvre Resolio, connecté. Les liens des emails (confirmation, mot de passe oublié) utilisent le même mécanisme : **ouvre-les sur le téléphone où Resolio est installé**.

---

## 4. Tester dans le navigateur

```bash
npm run dev     # http://localhost:5173
```

La connexion Google fonctionne aussi dans le navigateur (retour sur `http://localhost:5173`).

---

## 5. Plus tard : passer sur ton propre serveur

Supabase est open source et s'installe avec Docker (environ 4 Go de RAM conseillés).

1. Installe Supabase sur ton serveur : https://supabase.com/docs/guides/self-hosting/docker
2. Copie la base du cloud vers ton serveur en suivant le guide officiel :
   https://supabase.com/docs/guides/self-hosting/restore-from-platform
   (il te faudra le **mot de passe de la base** choisi à la création du projet)
3. Re-télécharge les photos du bucket `avatars` (ou repars sans : elles se remettent depuis le profil).
4. Mets la nouvelle adresse (en **https**) et la nouvelle clé dans `www/config.js`, publie une nouvelle version de l'app.
5. Refais les réglages des sections 2 et 3 sur ton serveur (URL de redirection Google : `https://ton-domaine/auth/v1/callback`).

---

## Faire évoluer le schéma

Ajoute un **nouveau** fichier dans `migrations/` (ex. `20261201000000_ajout_xxx.sql`) plutôt que de modifier l'ancien, exécute-le dans le SQL Editor, et commit-le. Mets aussi à jour les fonctions de conversion dans `www/index.html` (`goalToRow` / `goalFromRow`, `entryToRow` / `entryFromRow`, `profileToRow` / `profileFromRow`).
