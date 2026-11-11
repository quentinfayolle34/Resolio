# Serveur Resolio (PocketBase dans Docker)

Le serveur garde une copie de tes données en ligne (comptes, objectifs, semaines, séances) pour les retrouver sur tous tes appareils.
Il tourne avec [PocketBase](https://pocketbase.io) dans un conteneur **Docker** : la même installation marche sur ton PC Windows aujourd'hui et sur un serveur allumé 24h/24 plus tard.

L'application continue de fonctionner sans le serveur : elle se synchronise dès qu'il est joignable.

```
server/
  Dockerfile               Image Docker : PocketBase 0.40.6 + le schéma de la base
  docker-compose.yml       Lancement (port 8090, données dans ./pb_data)
  pb_migrations/           Schéma de la base (tables + règles de sécurité), versionné dans Git
  pb_data/                 ⚠️ Tes données (créé au 1er lancement, jamais envoyé sur GitHub)
```

---

## 1. Installer Docker Desktop sur Windows (une seule fois)

1. Télécharge **Docker Desktop** : https://www.docker.com/products/docker-desktop/
2. Lance l'installation en gardant l'option **« Use WSL 2 »** cochée.
3. Redémarre le PC si on te le demande.
4. Ouvre **Docker Desktop** et attends que l'indicateur en bas à gauche soit vert (*Engine running*).
5. Vérifie dans un terminal (**PowerShell**) :
   ```powershell
   docker --version
   docker compose version
   ```

> Si Docker te demande d'installer ou mettre à jour WSL, lance dans PowerShell **en administrateur** : `wsl --install` (ou `wsl --update`), puis redémarre.

Pour que le serveur démarre tout seul avec Windows : Docker Desktop → ⚙️ *Settings* → *General* → coche **Start Docker Desktop when you sign in**.

---

## 2. Lancer le serveur

Dans PowerShell, depuis le dossier du projet :

```powershell
cd server
docker compose up -d --build
```

Vérifie qu'il répond : ouvre http://localhost:8090/api/health dans ton navigateur (tu dois voir `API is healthy`).

### Créer ton compte administrateur (une seule fois)

```powershell
docker compose exec pocketbase /pb/pocketbase superuser upsert ton-email@exemple.fr UnMotDePasseSolide --dir=/pb/pb_data
```

L'interface d'administration est sur **http://localhost:8090/_/** : tu y vois toutes les tables (`users`, `goals`, `weeks`, `entries`).

> Ce compte administrateur sert uniquement à gérer la base. Ton compte **Resolio** (celui de l'application) se crée depuis l'app : *Profil → Compte → Se connecter ou créer un compte*.

### Commandes utiles

| Action | Commande (dans `server/`) |
| --- | --- |
| Démarrer | `docker compose up -d` |
| Arrêter | `docker compose down` |
| Voir les journaux | `docker compose logs -f` |
| Redémarrer après une mise à jour du schéma | `docker compose up -d --build` |

---

## 3. Connecter ton téléphone (même Wi-Fi que le PC)

1. **Trouve l'adresse IP du PC** : dans PowerShell, tape `ipconfig` et repère *Adresse IPv4* de ta carte Wi-Fi ou Ethernet (par ex. `192.168.1.20`).
2. **Autorise le port 8090 dans le pare-feu Windows** (PowerShell **en administrateur**, une seule fois) :
   ```powershell
   New-NetFirewallRule -DisplayName "Resolio (PocketBase)" -Direction Inbound -Protocol TCP -LocalPort 8090 -Action Allow -Profile Private
   ```
   Ton Wi-Fi doit être un **réseau privé** : *Paramètres → Réseau et Internet → Wi-Fi → (ton réseau) → Type de profil réseau : Privé*.
3. Teste depuis le navigateur du téléphone : `http://192.168.1.20:8090/api/health`.
4. Dans Resolio : **Profil → Compte → Se connecter ou créer un compte**
   - Serveur : `http://192.168.1.20:8090`
   - Choisis *Créer un compte* la première fois, puis *Se connecter* sur tes autres appareils.

> Si l'IP du PC change (redémarrage de la box), il faudra la remettre dans l'app. Pour l'éviter : réserve une IP fixe pour ton PC dans l'interface de ta box.

---

## 4. Accéder au serveur hors de chez toi (facultatif)

Le plus simple et le plus sûr : **[Tailscale](https://tailscale.com)** (gratuit pour un usage perso).
Installe-le sur le PC et sur le téléphone avec le même compte : le téléphone peut alors joindre le PC via son adresse Tailscale (`http://100.x.y.z:8090`), où que tu sois, sans ouvrir ta box à Internet.

> Évite d'ouvrir le port 8090 de ta box directement vers Internet : les données passeraient en clair (http).

---

## 5. Sauvegardes

Toutes les données sont dans le dossier **`server/pb_data`**.

- **Sauvegarde manuelle** : arrête le serveur (`docker compose down`), copie le dossier `pb_data` ailleurs (disque externe, Drive…), relance.
- **Sauvegardes automatiques** : dans l'admin (http://localhost:8090/_/) → *Settings → Backups* → active les sauvegardes planifiées (par ex. chaque nuit). Elles sont rangées dans `pb_data/backups`.

---

## 6. Plus tard : déménager sur un serveur 24h/24

1. Sur le serveur (Linux avec Docker) : `git clone` du projet, puis copie ton dossier `pb_data` dans `server/`.
2. `cd server && docker compose up -d --build`
3. Ajoute un nom de domaine et le **https** (obligatoire pour l'iPhone, conseillé partout). Le plus simple : un reverse proxy **Caddy** devant PocketBase, qui obtient le certificat tout seul.
4. Dans l'app : *Profil → Compte → Se déconnecter*, puis reconnecte-toi avec la nouvelle adresse (`https://resolio.ton-domaine.fr`).

L'image Docker fonctionne aussi sur les serveurs ARM (Raspberry Pi, certains VPS).

---

## Le schéma de la base

| Table | Contenu |
| --- | --- |
| `users` | Comptes (email, mot de passe, prénom, photo, semaine de départ) |
| `goals` | Objectifs : nom, emoji, catégorie, type, unité, historique des chiffres, pauses blessure |
| `weeks` | Une ligne par semaine : clôturée ou non, bilan (`result`), bilan vu |
| `entries` | Chaque séance / lecture / jour coché (`deleted = true` si retiré) |

Règle de sécurité sur toutes les tables : **chaque utilisateur ne peut lire et modifier que ses propres données.**

Pour faire évoluer le schéma : modifie les collections dans l'admin. PocketBase écrit automatiquement un nouveau fichier dans `pb_migrations/`. Commit ce fichier : le serveur de production l'appliquera au prochain `docker compose up -d --build`.
