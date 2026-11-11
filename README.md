# Resolio

**Tes objectifs de la semaine. Pas d'excuses.**

Resolio est une application mobile de résolutions **par jour, semaine, mois ou année** : boire 2 L d'eau par jour, lire 100 pages et faire 3 séances de sport par semaine, lire 400 pages par mois… À la fin de chaque période (minuit, dimanche minuit, fin du mois, 31 décembre), un bilan indique si elle est validée.

- **Résolutions** : onglets Jour / Semaine / Mois / Année (seuls ceux qui ont des résolutions s'affichent), progression, journal des séances et lectures (livre, activité, durée, distance).
- **Objectifs** : nouvelle résolution (période, catégorie, type : nombre de fois, quantité, chaque jour, une fois), modifier les chiffres, pause blessure, archivage.
- **Historique** : chaque jour / semaine / mois / année passé, validé ou non, séries et records.
- **Profil** : nom, prénom, photo, email, date de naissance et ville (facultatifs), séries, totaux, badges.
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

Le même dossier `www/` servira pour iPhone : il suffira d'ajouter la plateforme iOS (voir plus bas).

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

## Plus tard : iPhone

```bash
npm install @capacitor/ios
npx cap add ios
npx cap open ios   # nécessite un Mac avec Xcode
```

Il faudra aussi un compte **Apple Developer** (≈ 99 €/an) pour installer l'app durablement et la partager via **TestFlight**. La fabrication peut aussi se faire sur GitHub Actions (machines macOS).

Pour la connexion Google et les liens des emails, il faudra déclarer le schéma `com.quentinfayolle.resolio` dans Xcode (*URL Types*).
