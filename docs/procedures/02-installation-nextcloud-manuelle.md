# Procédure manuelle — Installation de Nextcloud sur Debian 13 avec Docker Compose

## Objectif

Installer Nextcloud manuellement sur une machine Debian 13 avec :

```text
- Docker
- Docker Compose
- MariaDB
- Redis
- Nextcloud
```

Cette procédure reprend l’installation prévue dans le script `01-install-nextcloud.sh`, mais sous forme manuelle.

---

## 1. Architecture utilisée

```text
Serveur Nextcloud : Debian 13
Service           : Nextcloud
Base de données   : MariaDB
Cache             : Redis
Déploiement       : Docker Compose
Dossier install   : /opt/nextcloud
Port HTTP         : 80 ou port défini dans l’environnement
```

Exemple utilisé :

```text
Nom DNS Nextcloud : nextcloud.technova.local
IP Nextcloud      : 192.168.192.20
URL DNS           : http://nextcloud.technova.local
URL IP            : http://192.168.192.20:80
```

---

## 2. Vérifier les prérequis avant installation

Avant de lancer l’installation, vérifier que le serveur Debian est joignable et que sa configuration réseau correspond à l’architecture prévue.

Vérifier l’adresse IP du serveur :

```bash
ip -br a
```

Vérifier l’accès Internet :

```bash
ping -c 4 deb.debian.org
```

Vérifier le nom DNS si l’enregistrement existe déjà :

```bash
getent hosts nextcloud.technova.local
```

Si le DNS n’est pas encore créé, ce n’est pas bloquant pour installer Nextcloud. L’accès pourra être testé directement avec l’adresse IP :

```text
http://192.168.192.20
```

---

## 3. Mettre à jour Debian et installer les dépendances de base

Mettre Debian à jour :

```bash
sudo apt update
sudo apt upgrade -y
```

Installer les dépendances de base en une fois :

```bash
sudo apt install -y ca-certificates curl gnupg lsb-release nano
```

Remarque :

```text
Les paquets Docker ne sont pas installés à cette étape.
Ils seront installés après l’ajout de la clé officielle Docker et du dépôt Docker.
```

---

## 4. Installer Docker et Docker Compose

Créer le dossier des clés APT :

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

Ajouter la clé officielle Docker :

```bash
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

Ajouter le dépôt Docker :

```bash
. /etc/os-release

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
```

Installer Docker :

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Activer Docker :

```bash
sudo systemctl enable --now docker
```

Vérifier :

```bash
docker --version
docker compose version
```

---

## 5. Ajouter l’utilisateur au groupe Docker

Remplacer `yoann` par le nom de l’utilisateur si besoin :

```bash
sudo usermod -aG docker yoann
```

Appliquer les droits :

```bash
sudo reboot
```

Après redémarrage, vérifier :

```bash
docker ps
```

Si la commande fonctionne sans `sudo`, l’utilisateur peut piloter Docker.

---

## 6. Préparer le dossier d’installation

Créer le dossier Nextcloud :

```bash
sudo mkdir -p /opt/nextcloud
```

### Cas recommandé : exploitation avec un utilisateur Linux standard

Si Docker Compose sera lancé avec un compte standard, donner les droits à ce compte.

Exemple avec l’utilisateur `yoann` :

```bash
sudo chown -R yoann:yoann /opt/nextcloud
cd /opt/nextcloud
```

### Cas possible : exploitation depuis un shell root

Si vous êtes déjà dans un shell root et que l’exploitation sera faite en root, le dossier peut appartenir à `root:root`.

Ce n’est pas forcément bloquant dans ce cas précis, car les fichiers `compose.yml` et `.env` sont lus par Docker Compose. Le propriétaire devient surtout important si un autre utilisateur doit modifier ces fichiers ou relancer l’application.

Commandes possibles en root :

```bash
mkdir -p /opt/nextcloud
cd /opt/nextcloud
```

Si vous êtes déjà dans un shell root mais que le dossier doit être géré par un autre compte, remplacer `tonuser` par le vrai compte Linux ou domaine qui doit gérer les fichiers :

```bash
mkdir -p /opt/nextcloud
chown -R tonuser:tonuser /opt/nextcloud
cd /opt/nextcloud
```

### Variante avec UID/GID du compte courant

Donner les droits au compte Linux actuellement connecté :

```bash
sudo chown -R $(id -u):$(id -g) /opt/nextcloud
cd /opt/nextcloud
```

Pourquoi utiliser `$(id -u):$(id -g)` plutôt que `$USER:$USER` :

```text
- $USER peut ne pas valoir root selon la manière dont la session sudo ou root a été ouverte.
- avec un compte administrateur de domaine, le nom peut être différent du nom local attendu par Linux.
- certains comptes de domaine contiennent des caractères moins pratiques à utiliser avec chown.
- l’UID et le GID numériques retournés par id sont ceux réellement utilisés par Linux pour les droits fichiers.
```

Attention :

```text
Si la session courante est root, $(id -u):$(id -g) donnera 0:0.
Le dossier appartiendra donc à root:root.
Ce n’est pas automatiquement un problème, mais il faut que ce soit volontaire.
```

Vérifier le compte et le groupe utilisés :

```bash
id
ls -ld /opt/nextcloud
```

Résultat attendu :

```text
/opt/nextcloud appartient au compte qui doit administrer les fichiers Docker Compose.
Ce compte peut être un utilisateur standard ou root si l’exploitation est volontairement faite en root.
```

Résultat attendu si vous avez choisi un utilisateur standard :

```text
/opt/nextcloud appartient à l’utilisateur courant, pas à root.
```

---

## 7. Créer le fichier `.env`

Créer le fichier :

```bash
nano .env
```

Exemple de contenu :

```env
INSTALL_DIR="/opt/nextcloud"

NEXTCLOUD_TRUSTED_DOMAIN="nextcloud.technova.local"
NEXTCLOUD_IP="192.168.192.20"
NEXTCLOUD_PORT="80"

NEXTCLOUD_ADMIN_USER="admin"
NEXTCLOUD_ADMIN_PASSWORD="CHANGE_ME_NEXTCLOUD_ADMIN_PASSWORD"

MYSQL_DATABASE="nextcloud"
MYSQL_USER="nextcloud"
MYSQL_PASSWORD="CHANGE_ME_NEXTCLOUD_DB_PASSWORD"
MYSQL_ROOT_PASSWORD="CHANGE_ME_NEXTCLOUD_DB_ROOT_PASSWORD"

NEXTCLOUD_IMAGE="nextcloud:latest"
MARIADB_IMAGE="mariadb:latest"
REDIS_IMAGE="redis:alpine"
```

Enregistrer :

```text
CTRL + O
Entrée
CTRL + X
```

---

## 8. Créer le fichier `compose.yml`

Dans `/opt/nextcloud` :

```bash
nano compose.yml
```

Contenu :

```yaml
services:
  db:
    image: ${MARIADB_IMAGE}
    container_name: nextcloud-db
    restart: unless-stopped
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 10

  redis:
    image: ${REDIS_IMAGE}
    container_name: nextcloud-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data

  app:
    image: ${NEXTCLOUD_IMAGE}
    container_name: nextcloud
    restart: unless-stopped
    ports:
      - "${NEXTCLOUD_PORT}:80"
    depends_on:
      - db
      - redis
    environment:
      MYSQL_HOST: db
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      NEXTCLOUD_ADMIN_USER: ${NEXTCLOUD_ADMIN_USER}
      NEXTCLOUD_ADMIN_PASSWORD: ${NEXTCLOUD_ADMIN_PASSWORD}
      NEXTCLOUD_TRUSTED_DOMAINS: ${NEXTCLOUD_TRUSTED_DOMAIN} ${NEXTCLOUD_IP}
      REDIS_HOST: redis
    volumes:
      - nextcloud_data:/var/www/html

volumes:
  db_data:
  redis_data:
  nextcloud_data:
```

---

## 9. Démarrer Nextcloud

Depuis `/opt/nextcloud` :

```bash
docker compose pull
docker compose up -d
```

Vérifier les conteneurs :

```bash
docker compose ps
```

Résultat attendu :

```text
nextcloud
nextcloud-db
nextcloud-redis
```

---

## 10. Vérifier l’initialisation Nextcloud

Vérifier que les fichiers Nextcloud sont présents :

```bash
docker exec nextcloud test -f /var/www/html/version.php && echo "Nextcloud initialisé"
```

Vérifier l’état de Nextcloud :

```bash
docker exec -u www-data nextcloud php occ status
```

Résultat attendu :

```text
installed: true
```

Si `occ` ne répond pas immédiatement, attendre quelques minutes :

```bash
docker compose logs -f app
```

---

## 11. Accéder à Nextcloud

Depuis un navigateur :

```text
http://nextcloud.technova.local
```

ou :

```text
http://192.168.192.20
```

Compte administrateur local :

```text
Utilisateur : admin
Mot de passe : CHANGE_ME_NEXTCLOUD_ADMIN_PASSWORD
```

Si le nom DNS ne répond pas, tester d’abord l’accès par IP. Si l’accès par IP fonctionne mais pas par nom DNS, le problème vient probablement de la résolution DNS et non de Nextcloud.

---

## 12. Commandes utiles

Voir les conteneurs :

```bash
cd /opt/nextcloud
docker compose ps
```

Voir les logs Nextcloud :

```bash
cd /opt/nextcloud
docker compose logs -f app
```

Voir les logs MariaDB :

```bash
cd /opt/nextcloud
docker compose logs -f db
```

Redémarrer Nextcloud :

```bash
cd /opt/nextcloud
docker compose restart
```

Arrêter Nextcloud :

```bash
cd /opt/nextcloud
docker compose down
```

Relancer Nextcloud :

```bash
cd /opt/nextcloud
docker compose up -d
```

Statut Nextcloud :

```bash
docker exec -u www-data -it nextcloud php occ status
```

---

## 13. Réinitialiser le POC

Attention : cette commande supprime les données Nextcloud, MariaDB et Redis.

```bash
cd /opt/nextcloud
docker compose down -v --remove-orphans
docker compose up -d
```

---

## 14. Résultat attendu

```text
Nextcloud est installé sur Debian 13 avec Docker Compose.

Les services suivants sont actifs :
- nextcloud
- nextcloud-db
- nextcloud-redis

Nextcloud est accessible via :
http://nextcloud.technova.local
ou
http://192.168.192.20
```
