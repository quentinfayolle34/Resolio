# Resolio

**Tes objectifs de la semaine. Pas d'excuses.**

Resolio est une application mobile de résolutions **par jour ou par semaine** : boire 2 L d'eau par jour, lire 100 pages et faire 3 séances de sport par semaine… À la fin de chaque période (minuit, dimanche minuit), un bilan indique si elle est validée.

- **Résolutions** : onglets Jour / Semaine / Mois / Année (seuls ceux qui ont des résolutions s'affichent), progression, journal des séances et lectures (livre, activité, durée, distance).
- **Objectifs** : nouvelle résolution (période ; catégorie Lecture, Sport, Méditation, Réduire ou Autre ; une ou plusieurs mesures : nombre de fois, temps, distance, pages ; maximum à ne pas dépasser pour Réduire ; **Temps d'écran** relevé automatiquement sur Android : tout le téléphone, catégories ou applications), modifier les chiffres, pause blessure, archivage.
- **Historique** : calendrier du mois (✓ les jours avec au moins une activité, hors « Réduire » ; un appui sur un jour affiche le détail), puis chaque jour / semaine passé, validé ou non, séries et records.
- **Profil** : nom, prénom, photo, email, date de naissance et ville (facultatifs), séries, totaux, 12 badges à 5 niveaux (Bronze → Diamant).
- **Amis** (onglet ouvert au démarrage) : ajout par **code ami** unique avec demande à accepter, fil d'activité (une publication quand une résolution est **tenue** : popup « Résolution tenue ! » avec photo prise ou importée et un mot, ou « Ne pas publier » ; likes, tout l'historique), profil d'ami (photo, séries, badges). À la fin de chaque semaine : **rétrospective** en carrousel plein écran (toi d'abord, puis ceux qui ont réussi en jaune, puis les autres en rouge, avec likes) ; chaque résolution peut être **Public** ou **Privé** pour la rétrospective.
- **Compte** : connexion par email + mot de passe ou avec Google, mot de passe oublié, suppression du compte.

Toutes les données sont dans une base **Supabase** (une seule base pour tous les comptes, chacun ne voit que ses données) : l'app a besoin d'internet et tu retrouves tout sur n'importe quel téléphone → voir **[supabase/README.md](supabase/README.md)**.

---

## Télécharger l'application (Android)

1. Ouvre l'onglet **[Releases](../../releases)** du dépôt et télécharge le fichier `Resolio-x.y.z.apk` de la dernière version.
2. Sur un Samsung, désactive temporairement le **Bloqueur automatique** : *Paramètres → Sécurité et confidentialité → Bloqueur automatique*.
3. Ouvre l'APK, autorise l'installation depuis cette source, puis **Installer**.

---

## Structure du projet

```
www/                      Code de l'application (HTML / CSS / JavaScript, sans framework)
  index.html              Toute l'application : écrans, logique, stockage
  fonts/                  Polices Archivo + Inter embarquées (fonctionne hors ligne)
android/                  Projet Android natif généré par Capacitor
  config.js               Adresse + clé publique de la base Supabase
  vendor/supabase.js      Bibliothèque Supabase (copiée depuis node_modules : npm run vendor)
supabase/                 Base de données : schéma SQL + guide de configuration (Google, emails…)
capacitor.config.json     Configuration Capacitor (nom, identifiant, barres système)
scripts/generate-icons.py Génère l'icône (cible jaune) et l'écran de démarrage
resources/icon.png        Icône source 1024×1024
.github/workflows/        Fabrication automatique de l'APK sur GitHub
```

Le même dossier `www/` sert aussi à l'app iPhone (voir plus bas).

---

## Développer sur ton ordinateur (VS Code + Claude Code)

### À installer une fois

- [Node.js](https://nodejs.org) (version 22 ou plus récente)
- [Git](https://git-scm.com)
- [VS Code](https://code.visualstudio.com) + l'extension **Claude Code** (éditeur : Anthropic)
- *(facultatif)* [Android Studio](https://developer.android.com/studio), pour tester directement sur ton téléphone branché en USB

### Récupérer le projet

```bash
git clone https://github.com/quentinfayolle34/Resolio.git
cd Resolio
npm install
```

### Tester dans le navigateur (le plus rapide)

```bash
npm run dev
```

Puis ouvre http://localhost:5173. Dans Chrome, active la vue mobile (F12 → icône téléphone). Recharge la page après chaque modification de `www/index.html`.

### Tester sur ton téléphone Android (avec Android Studio)

1. Sur le téléphone : active les *Options de développement* et le *Débogage USB*, puis branche-le.
2. Lance :
   ```bash
   npm run android
   ```
3. Android Studio s'ouvre : clique sur ▶ (Run).

Après chaque modification dans `www/`, relance `npx cap sync android` avant de relancer l'app.

---

## Publier une nouvelle version

1. Modifie le numéro dans `package.json` (`"version": "1.1.0"`).
2. Commit, puis crée et envoie un tag :
   ```bash
   git commit -am "Version 1.1.0"
   git tag v1.1.0
   git push && git push --tags
   ```
3. GitHub Actions fabrique l'APK signé et le publie dans **Releases** (≈ 5 minutes).

Chaque push sur `main` fabrique aussi un APK de test, téléchargeable dans l'onglet **Actions** → la dernière exécution → *Artifacts*.

### Clé de signature (indispensable)

Android n'accepte une mise à jour que si elle est signée avec **la même clé** que la version installée. La clé est stockée dans les **secrets** du dépôt (*Settings → Secrets and variables → Actions*) :

| Secret | Contenu |
| --- | --- |
| `RESOLIO_KEYSTORE_BASE64` | le fichier de clé encodé en base64 |
| `RESOLIO_KEYSTORE_PASSWORD` | mot de passe du fichier de clé |
| `RESOLIO_KEY_ALIAS` | `resolio` |
| `RESOLIO_KEY_PASSWORD` | mot de passe de la clé (le même) |

⚠️ Garde une copie du fichier `resolio-release.keystore` et de son mot de passe en lieu sûr (gestionnaire de mots de passe, Drive privé). **Ne l'ajoute jamais au dépôt.** Sans les secrets, la CI produit un APK de *debug* qui ne peut pas mettre à jour une version signée.

---

## iPhone (App Store / TestFlight)

Le projet iOS est dans `ios/` (même code `www/` que l'APK). **Pas besoin de Mac** : GitHub Actions construit l'app sur ses Mac (workflow `.github/workflows/ios.yml`).

- À chaque push sur `main` / pull request : vérification que l'app compile.
- À chaque **release `vX.Y.Z`** (ou *Actions → iOS → Run workflow*) : l'app est signée et envoyée sur **App Store Connect → TestFlight**.

Différences avec Android : pas de **Temps d'écran** (Apple ne donne pas accès à ces chiffres) ; bouton **« Continuer avec Apple »** en plus (obligatoire sur iPhone dès qu'il y a la connexion Google).

### À faire une seule fois (côté Apple)

1. **Compte Apple Developer** (99 $/an, ≈ 99 €) : https://developer.apple.com/programs/enroll/ — inscription en tant que *personne physique*, validation sous 1 à 2 jours.
2. **Identifiant de l'app** : developer.apple.com → *Certificates, Identifiers & Profiles → Identifiers → +* → *App IDs* → Bundle ID `com.quentinfayolle.resolio`, coche **Sign in with Apple**.
3. **Fiche de l'app** : https://appstoreconnect.apple.com → *Apps → + → Nouvelle app* : iOS, nom *Resolio*, langue *Français*, bundle ID `com.quentinfayolle.resolio`, SKU `resolio`.
4. **Clé API pour GitHub** : App Store Connect → *Utilisateurs et accès → Intégrations → App Store Connect API → Clés d'équipe → +*, rôle **Admin** (nécessaire pour que GitHub crée lui-même le certificat de signature). Télécharge le fichier `AuthKey_XXXX.p8` (une seule fois possible) et note l'**Issuer ID** affiché en haut.
5. **Secrets GitHub** (*Settings → Secrets and variables → Actions*) :

   | Secret | Valeur |
   |---|---|
   | `APPLE_TEAM_ID` | developer.apple.com → *Membership* → Team ID (10 caractères) |
   | `ASC_KEY_ID` | l'ID de la clé (ex. `2X9R4HXF34`) |
   | `ASC_ISSUER_ID` | l'Issuer ID |
   | `ASC_KEY_P8_BASE64` | le fichier `.p8` en base64 : sur Windows, PowerShell → `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8")) \| Set-Clipboard` |

   ⚠️ Le fichier `.p8` ne va **jamais** dans le dépôt : uniquement dans ces secrets.
6. **Connexion avec Apple** : voir [supabase/README.md](supabase/README.md), section 3 bis.

### Installer sur ton iPhone (TestFlight)

Crée une release `vX.Y.Z` comme pour Android → après ~15 min, la build apparaît dans App Store Connect → *TestFlight*. Ajoute-toi (et tes amis, jusqu'à 100 testeurs internes ou 10 000 externes) comme testeurs, puis installe l'app **TestFlight** sur l'iPhone et accepte l'invitation.

### Publier sur l'App Store

Dans la fiche de l'app : captures d'écran iPhone, description, **URL de politique de confidentialité** (obligatoire), questionnaire de confidentialité et classification d'âge, puis *Soumettre pour vérification* (en général 1 à 3 jours).
