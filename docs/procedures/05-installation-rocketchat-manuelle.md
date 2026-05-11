# Installation propre de Rocket.Chat sur Debian 13 avec Docker Compose

## 1. Objectif

L'objectif de cette procédure est d'installer Rocket.Chat sur une machine Debian 13 propre à l'aide de Docker et Docker Compose.

Rocket.Chat est une plateforme de messagerie collaborative open source. Elle permet de créer un espace de discussion interne avec des utilisateurs, des canaux, des messages privés et un accès web.

L'installation est réalisée avec Docker Compose afin de simplifier le déploiement et d'éviter les problèmes de compatibilité entre Debian 13, MongoDB et Node.js.

---

## 2. Contexte technique

- Distribution : Debian 13
- Service installé : Rocket.Chat
- Base de données : MongoDB en conteneur Docker
- Port utilisé : `3000`
- Méthode d'installation : Docker Compose

> **À adapter :** remplacez `ADRESSE_IP_DU_SERVEUR` par l'adresse IP réelle du serveur Debian.  
> Exemple de format : `http://ADRESSE_IP_DU_SERVEUR:3000`

---

## 3. Prérequis

Avant de commencer, il faut disposer :

- d'une machine Debian 13 propre ;
- d'un accès Internet ;
- d'un utilisateur avec les droits `sudo` ;
- d'une adresse IP joignable depuis le poste client ;
- d'un accès au terminal du serveur.

---

## 4. Mise à jour du serveur

Mettre à jour la liste des paquets :

```bash
sudo apt update
```

Mettre à jour le système :

```bash
sudo apt upgrade -y
```

Redémarrer le serveur si nécessaire :

```bash
sudo reboot
```

Après le redémarrage, se reconnecter au serveur.

---

## 5. Installation des dépendances de base

Installer les paquets nécessaires :

```bash
sudo apt install -y ca-certificates curl gnupg
```

Créer le dossier destiné aux clés APT :

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

---

## 6. Installation de Docker

Ajouter la clé officielle Docker :

```bash
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

Appliquer les droits sur la clé :

```bash
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

Ajouter le dépôt Docker pour Debian 13 Trixie :

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian trixie stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Mettre à jour les dépôts :

```bash
sudo apt update
```

Installer Docker et Docker Compose :

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Vérifier l'installation :

```bash
docker --version
docker compose version
```

Tester Docker :

```bash
sudo docker ps
```

Si la commande affiche une liste de conteneurs, même vide, Docker est installé correctement.

---

## 7. Donner les droits Docker à l'utilisateur

Ajouter l'utilisateur courant au groupe Docker :

```bash
sudo usermod -aG docker $USER
```

Redémarrer la machine pour appliquer les droits :

```bash
sudo reboot
```

Après le redémarrage, tester Docker sans `sudo` :

```bash
docker ps
```

Si la commande fonctionne sans erreur de permission, l'utilisateur peut gérer Docker.

---

## 8. Création du dossier Rocket.Chat

Créer un dossier dédié à Rocket.Chat :

```bash
mkdir -p ~/rocketchat
cd ~/rocketchat
```

Ce dossier contiendra le fichier Docker Compose.

---

## 9. Création du fichier Docker Compose

Créer le fichier `compose.yml` :

```bash
nano compose.yml
```

Coller le contenu suivant :

```yaml
services:
  mongodb:
    image: mongo:7.0
    container_name: rocketchat-mongodb
    restart: unless-stopped
    command: mongod --replSet rs0 --oplogSize 128 --bind_ip_all
    volumes:
      - mongodb_data:/data/db

  mongodb-init-replica:
    image: mongo:7.0
    container_name: rocketchat-mongodb-init
    depends_on:
      - mongodb
    command: >
      bash -c "sleep 10 &&
      mongosh --host mongodb:27017 --eval '
      rs.initiate({
        _id: \"rs0\",
        members: [{ _id: 0, host: \"mongodb:27017\" }]
      })'"
    restart: "no"

  rocketchat:
    image: registry.rocket.chat/rocketchat/rocket.chat:latest
    container_name: rocketchat
    restart: unless-stopped
    depends_on:
      - mongodb
      - mongodb-init-replica
    environment:
      ROOT_URL: http://ADRESSE_IP_DU_SERVEUR:3000
      PORT: 3000
      MONGO_URL: mongodb://mongodb:27017/rocketchat?replicaSet=rs0
      MONGO_OPLOG_URL: mongodb://mongodb:27017/local?replicaSet=rs0
      DEPLOY_METHOD: docker
      INITIAL_USER: yes
      ADMIN_USERNAME: admin
      ADMIN_NAME: Administrateur RocketChat
      ADMIN_EMAIL: admin@example.local
      ADMIN_PASS: "CHANGE_ME_ROCKETCHAT_ADMIN_PASSWORD"
      OVERWRITE_SETTING_Setup_Wizard: completed
      OVERWRITE_SETTING_Show_Setup_Wizard: completed
    ports:
      - "3000:3000"
    volumes:
      - uploads_data:/app/uploads

volumes:
  mongodb_data:
  uploads_data:
```

> Important : remplacez `ADRESSE_IP_DU_SERVEUR` par l'adresse IP réelle du serveur Debian.

Enregistrer le fichier :

```text
Ctrl + O
Entrée
Ctrl + X
```

---

## 10. Explication rapide du fichier Compose

Le fichier `compose.yml` contient trois services principaux.

### Service `mongodb`

Ce service lance la base de données MongoDB utilisée par Rocket.Chat.

### Service `mongodb-init-replica`

Ce service initialise MongoDB en mode replica set. Rocket.Chat a besoin de ce mode pour fonctionner correctement.

### Service `rocketchat`

Ce service lance l'application Rocket.Chat.

Variables importantes :

```yaml
ROOT_URL: http://ADRESSE_IP_DU_SERVEUR:3000
MONGO_URL: mongodb://mongodb:27017/rocketchat?replicaSet=rs0
MONGO_OPLOG_URL: mongodb://mongodb:27017/local?replicaSet=rs0
DEPLOY_METHOD: docker
INITIAL_USER: yes
ADMIN_USERNAME: admin
ADMIN_NAME: Administrateur RocketChat
ADMIN_EMAIL: admin@example.local
ADMIN_PASS: "CHANGE_ME_ROCKETCHAT_ADMIN_PASSWORD"
OVERWRITE_SETTING_Setup_Wizard: completed
OVERWRITE_SETTING_Show_Setup_Wizard: completed
```

- `ROOT_URL` définit l'adresse utilisée pour accéder à Rocket.Chat.
- `MONGO_URL` et `MONGO_OPLOG_URL` permettent à Rocket.Chat de communiquer avec MongoDB.
- `DEPLOY_METHOD: docker` indique que Rocket.Chat est exécuté depuis Docker.

### Création automatique du compte administrateur

Les variables suivantes créent automatiquement le premier compte administrateur lors de la première initialisation de Rocket.Chat sur une base MongoDB neuve :

```yaml
INITIAL_USER: yes
ADMIN_USERNAME: admin
ADMIN_NAME: Administrateur RocketChat
ADMIN_EMAIL: admin@example.local
ADMIN_PASS: "CHANGE_ME_ROCKETCHAT_ADMIN_PASSWORD"
```

### Contournement de l'assistant de configuration Cloud

Les variables suivantes indiquent à Rocket.Chat que l'assistant de configuration est déjà terminé :

```yaml
OVERWRITE_SETTING_Setup_Wizard: completed
OVERWRITE_SETTING_Show_Setup_Wizard: completed
```

Ces variables permettent de réduire les étapes de configuration initiale et d'éviter, dans un environnement local ou de test, l'écran d'enregistrement Rocket.Chat Cloud.

---

## 11. Démarrage de Rocket.Chat

Depuis le dossier `~/rocketchat`, lancer les conteneurs :

```bash
docker compose up -d
```

Vérifier les conteneurs actifs :

```bash
docker ps
```

Les conteneurs attendus sont :

```text
rocketchat
rocketchat-mongodb
```

---

## 12. Consultation des logs

Afficher les logs Rocket.Chat :

```bash
docker compose logs -f rocketchat
```

Lorsque le serveur est correctement démarré, on doit voir un message du type :

```text
SERVER RUNNING
Process Port: 3000
Connected to MongoDB database: rocketchat
```

Pour quitter l'affichage des logs :

```text
Ctrl + C
```

Cette action ne coupe pas Rocket.Chat. Elle arrête seulement l'affichage des logs.

---

## 13. Vérification de l'adresse IP du serveur

Afficher les adresses IP du serveur :

```bash
hostname -I
```

Repérer l'adresse IP principale du serveur Debian.

Les adresses de type `172.17.0.1` ou `172.18.0.1` correspondent généralement aux réseaux internes Docker. Elles ne doivent pas être utilisées pour accéder à Rocket.Chat depuis un poste client.

---

## 14. Accès à l'interface web Rocket.Chat

Depuis un navigateur web, ouvrir l'adresse suivante :

```text
http://ADRESSE_IP_DU_SERVEUR:3000
```

Si la page Rocket.Chat s'affiche, le service est accessible.

---

## 15. Initialisation du workspace

Lors du premier accès, Rocket.Chat demande de créer un compte administrateur.

Exemple de compte administrateur :

```text
Nom complet : Administrateur Rocket.Chat
Nom d'utilisateur : admin
E-mail : admin@example.local
Mot de passe : mot de passe fort
```

Le mot de passe doit respecter les règles de sécurité indiquées par Rocket.Chat.

Exemple de contraintes possibles :

```text
Minimum 14 caractères
Au moins une majuscule
Au moins une minuscule
Au moins un chiffre
Au moins un symbole
```

---

## 16. Informations de l'organisation

Renseigner les informations de l'organisation.

Exemple :

```text
Nom de l'organisation : Nom de l'organisation
Secteur : Technology
Taille : 1-10
Pays : France
```

---

## 17. Enregistrement du serveur

Rocket.Chat peut demander d'enregistrer le serveur auprès de Rocket.Chat Cloud.

Dans un environnement de test local, cette étape peut être évitée grâce aux variables présentes dans le fichier `compose.yml` :

```yaml
OVERWRITE_SETTING_Setup_Wizard: completed
OVERWRITE_SETTING_Show_Setup_Wizard: completed
```

Après modification du fichier Compose, recréer les conteneurs :

```bash
cd ~/rocketchat
docker compose down
docker compose up -d --force-recreate
```

Ensuite, ouvrir directement :

```text
http://ADRESSE_IP_DU_SERVEUR:3000/home
```

ou :

```text
http://ADRESSE_IP_DU_SERVEUR:3000/login
```

Si Rocket.Chat affiche un message indiquant :

```text
Unique ID change detected
```

cliquer sur :

```text
Configuration update
```

Ne pas cliquer sur `New workspace`.

---

## Dépannage complémentaire : Rocket.Chat demande encore l'enregistrement Cloud

### Problème

Rocket.Chat peut afficher encore :

```text
Étape 3 sur 4 - Enregistrer votre serveur
E-mail du compte cloud
Register workspace
```

Ce comportement peut se produire même si les variables `OVERWRITE_SETTING_Setup_Wizard: completed` et `OVERWRITE_SETTING_Show_Setup_Wizard: completed` sont présentes, lorsque l'état du setup a déjà été enregistré dans MongoDB.

### Solution

1. Ouvrir une session MongoDB dans le conteneur :

```bash
docker exec -it rocketchat-mongodb mongosh
```

2. Sélectionner la base de données Rocket.Chat :

```javascript
use rocketchat
```

3. Forcer l'état du setup comme terminé :

```javascript
db.rocketchat_settings.updateOne(
  { _id: "Show_Setup_Wizard" },
  { $set: { value: "completed" } },
  { upsert: true }
)

db.rocketchat_settings.updateOne(
  { _id: "Setup_Wizard" },
  { $set: { value: "completed" } },
  { upsert: true }
)
```

4. Quitter :

```text
.exit
```

5. Redémarrer Rocket.Chat :

```bash
docker compose restart rocketchat
```

6. Accéder ensuite à :

```text
http://ADRESSE_IP_DU_SERVEUR:3000/home
```

---

## 18. Connexion à Rocket.Chat

Une fois l'installation terminée, se connecter avec le compte administrateur créé précédemment.

Adresse :

```text
http://ADRESSE_IP_DU_SERVEUR:3000
```

Identifiant :

```text
admin
```

ou l'adresse e-mail utilisée pendant la création du compte.

---

## 19. Création d'un canal de test

Depuis l'interface Rocket.Chat :

1. Cliquer sur créer un canal.
2. Choisir un nom de canal.
3. Créer un canal public.

Exemple de canal :

```text
general
```

Ce canal permet de tester la messagerie entre plusieurs utilisateurs.

---

## 20. Ajout d'un utilisateur de test

Créer un utilisateur de test.

Exemple :

```text
Nom : Test User
Nom d'utilisateur : testuser
E-mail : testuser@example.local
Mot de passe : mot de passe fort
```

Ensuite, tester la connexion avec cet utilisateur depuis un autre navigateur ou une fenêtre de navigation privée.

---

## 21. Vérification depuis un autre poste

Depuis un autre poste présent sur le même réseau, ouvrir :

```text
http://ADRESSE_IP_DU_SERVEUR:3000
```

Si l'interface Rocket.Chat s'affiche, le service est accessible depuis le réseau local.

---

## 22. Commandes utiles

Afficher les conteneurs actifs :

```bash
docker ps
```

Voir les logs Rocket.Chat :

```bash
cd ~/rocketchat
docker compose logs -f rocketchat
```

Redémarrer Rocket.Chat :

```bash
cd ~/rocketchat
docker compose restart
```

Arrêter Rocket.Chat :

```bash
cd ~/rocketchat
docker compose down
```

Démarrer Rocket.Chat :

```bash
cd ~/rocketchat
docker compose up -d
```

Mettre à jour les images Docker :

```bash
cd ~/rocketchat
docker compose pull
docker compose up -d
```

---

## 23. Vérifications réalisées

Les vérifications suivantes sont à réaliser :

- Rocket.Chat démarre correctement.
- Le conteneur Rocket.Chat est actif.
- Le conteneur MongoDB est actif.
- L'interface web est accessible.
- La connexion administrateur est possible.
- La création d'un canal est possible.
- La création d'un utilisateur de test est possible.
- L'accès depuis un autre poste du réseau est possible.

---

## 24. Points restants pour une installation complète

Pour une installation plus professionnelle, il reste à ajouter :

- un reverse proxy Nginx ;
- un accès avec un nom DNS ;
- un certificat HTTPS ;
- une URL propre de type `https://NOM_DNS_DU_SERVEUR` ;
- une stratégie de sauvegarde des volumes Docker ;
- une supervision du service ;
- une politique de mise à jour.

---

## 25. Dépannage rapide

### Rocket.Chat ne répond pas dans le navigateur

Vérifier que les conteneurs sont démarrés :

```bash
docker ps
```

Vérifier les logs :

```bash
cd ~/rocketchat
docker compose logs -f rocketchat
```

Tester localement depuis le serveur :

```bash
curl -I http://localhost:3000
```

Vérifier que l'adresse IP utilisée est bien celle du serveur :

```bash
hostname -I
```

### Erreur de permission avec Docker

Si la commande `docker ps` affiche une erreur de permission, vérifier que l'utilisateur est bien membre du groupe Docker :

```bash
groups
```

Si le groupe `docker` n'apparaît pas, refaire :

```bash
sudo usermod -aG docker $USER
sudo reboot
```

### Modification de l'adresse IP du serveur

Si l'adresse IP du serveur change, modifier la variable `ROOT_URL` dans le fichier `compose.yml` :

```bash
cd ~/rocketchat
nano compose.yml
```

Remplacer :

```yaml
ROOT_URL: http://ADRESSE_IP_DU_SERVEUR:3000
```

Puis recréer les conteneurs :

```bash
docker compose down
docker compose up -d
```

---

## 26. Conclusion

Rocket.Chat est installé sur Debian 13 à l'aide de Docker Compose.

L'application est accessible depuis le réseau local à l'adresse suivante :

```text
http://ADRESSE_IP_DU_SERVEUR:3000
```

Cette installation constitue une base fonctionnelle. Pour une utilisation en production ou en environnement professionnel, il est recommandé d'ajouter un reverse proxy, un certificat HTTPS, une sauvegarde régulière et une supervision du service.
