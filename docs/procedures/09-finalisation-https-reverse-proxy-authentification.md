# Procédure finale — Accès sécurisés HTTPS et authentification AD

## Objectif

Finaliser l'infrastructure TechNova avec une connexion sécurisée aux services internes :

```text
- Nginx Proxy Manager sur une VM dédiée SRV-PROXY ;
- un certificat interne auto-signé pour technova.local ;
- un accès HTTPS à Nextcloud ;
- un accès HTTPS à Rocket.Chat ;
- un accès HTTPS à Jitsi Meet ;
- l'installation du certificat sur le poste Windows client ;
- l'authentification Jitsi avec les utilisateurs Active Directory.
```

Cette procédure correspond à la **phase finale** du POC, après l'installation de l'AD, des VM Debian et des services applicatifs.

---

## 1. Architecture finale

```text
Client Windows
     |
     | HTTPS 443
     v
SRV-PROXY / Nginx Proxy Manager
192.168.192.15
     |
     | HTTP interne
     +--> SRV-NEXTCLOUD : 192.168.192.20:80
     |
     | HTTP interne
     +--> SRV-CHAT      : 192.168.192.30:3000
     |
     | HTTPS interne
     +--> SRV-JITSI     : 192.168.192.40:443
```

Flux WebRTC Jitsi :

```text
Client Windows  --->  UDP 10000  --->  SRV-JITSI 192.168.192.40
```

> Le trafic web passe par Nginx Proxy Manager. Le flux audio/vidéo Jitsi utilise directement le port UDP `10000` du serveur Jitsi.

Noms DNS finaux :

```text
nextcloud.technova.local -> 192.168.192.15
rocket.technova.local    -> 192.168.192.15
meet.technova.local      -> 192.168.192.15
```

Les vraies IP des serveurs restent configurées uniquement dans Nginx Proxy Manager en `Forward Host`.

---

## 2. Préparer la VM SRV-PROXY

Configuration réseau attendue :

```text
Nom VM      : SRV-PROXY
Hostname    : nginx
IP          : 192.168.192.15
Masque      : /24
Passerelle  : 192.168.192.2
DNS         : 192.168.192.10
DNS Search  : technova.local
```

Afficher les connexions réseau :

```bash
nmcli connection show
```

Configurer l'IP fixe, en adaptant le nom de la connexion si besoin :

```bash
sudo nmcli connection modify "Wired connection 1" \
  ipv4.addresses "192.168.192.15/24" \
  ipv4.gateway "192.168.192.2" \
  ipv4.dns "192.168.192.10" \
  ipv4.dns-search "technova.local" \
  ipv4.method manual
```

Redémarrer la connexion :

```bash
sudo nmcli connection down "Wired connection 1"
sudo nmcli connection up "Wired connection 1"
```

Vérifier :

```bash
ip a
ip route
resolvectl status
```

Résultat attendu :

```text
IP          : 192.168.192.15
DNS Server  : 192.168.192.10
DNS Domain  : technova.local
```

Si Debian tente d'utiliser IPv6 et que `apt update` échoue, forcer IPv4 :

```bash
sudo nano /etc/apt/apt.conf.d/99force-ipv4
```

Contenu :

```text
Acquire::ForceIPv4 "true";
```

---

## 3. Installer Docker sur SRV-PROXY

Mettre Debian à jour :

```bash
sudo apt update
sudo apt upgrade -y
```

Installer les paquets nécessaires :

```bash
sudo apt install -y ca-certificates curl gnupg lsb-release nano ufw openssl openssh-server
```

Ajouter la clé Docker :

```bash
sudo install -m 0755 -d /etc/apt/keyrings
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

Activer Docker et SSH :

```bash
sudo systemctl enable --now docker
sudo systemctl enable --now ssh
```

Vérifier :

```bash
docker --version
docker compose version
```

Ajouter l'utilisateur Debian au groupe Docker, en adaptant le nom si nécessaire :

```bash
sudo usermod -aG docker yoann
sudo reboot
```

Après redémarrage :

```bash
docker ps
```

La commande doit fonctionner sans `sudo`.

---

## 4. Installer Nginx Proxy Manager

Créer le dossier d'installation :

```bash
sudo mkdir -p /opt/nginx-proxy-manager
sudo chown -R $USER:$USER /opt/nginx-proxy-manager
cd /opt/nginx-proxy-manager
```

Créer le fichier Compose :

```bash
nano compose.yml
```

Contenu :

```yaml
services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt

volumes:
  npm_data:
  npm_letsencrypt:
```

Démarrer :

```bash
docker compose up -d
docker compose ps
```

Résultat attendu :

```text
nginx-proxy-manager   Up
```

---

## 5. Configurer le pare-feu de SRV-PROXY

Autoriser SSH, HTTP, HTTPS et l'interface NPM :

```bash
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 81/tcp
sudo ufw enable
sudo ufw status
```

Résultat attendu :

```text
22/tcp    ALLOW
80/tcp    ALLOW
443/tcp   ALLOW
81/tcp    ALLOW
```

Depuis Windows, vérifier :

```powershell
Test-NetConnection 192.168.192.15 -Port 81
Test-NetConnection 192.168.192.15 -Port 443
```

Résultat attendu :

```text
TcpTestSucceeded : True
```

---

## 6. Accéder à Nginx Proxy Manager

Depuis le poste Windows :

```text
http://192.168.192.15:81
```

Au premier accès, modifier le compte administrateur.

Exemple :

```text
Nom complet : Administrateur TechNova
Email       : admin@technova.local
Mot de passe: mot de passe fort du lab
```

---

## 7. Basculer les DNS applicatifs vers le proxy

Sur le contrôleur de domaine Windows :

```text
Gestionnaire de serveur
-> Outils
-> DNS
-> Zones de recherche directe
-> technova.local
```

Modifier ou créer les enregistrements de type `A` :

```text
nextcloud -> 192.168.192.15
rocket    -> 192.168.192.15
meet      -> 192.168.192.15
```

Résultat :

```text
nextcloud.technova.local -> 192.168.192.15
rocket.technova.local    -> 192.168.192.15
meet.technova.local      -> 192.168.192.15
```

Important :

```text
Les enregistrements DNS applicatifs pointent vers SRV-PROXY.
Les IP des serveurs Debian applicatifs ne changent pas.
```

Vérifier depuis Windows :

```powershell
ipconfig /flushdns
nslookup nextcloud.technova.local
nslookup rocket.technova.local
nslookup meet.technova.local
```

Résultat attendu pour les trois noms :

```text
Address: 192.168.192.15
```

---

## 8. Créer le certificat interne technova.local

Sur SRV-PROXY :

```bash
sudo mkdir -p /opt/certs/technova
sudo chown -R $USER:$USER /opt/certs
cd /opt/certs/technova
```

Créer la clé privée :

```bash
openssl genrsa -out technova.local.key 2048
```

Créer le fichier de configuration :

```bash
nano technova.local.cnf
```

Contenu :

```ini
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C = FR
ST = Lab
L = TechNova
O = TechNova
OU = IT
CN = technova.local

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = technova.local
DNS.2 = *.technova.local
DNS.3 = nextcloud.technova.local
DNS.4 = rocket.technova.local
DNS.5 = meet.technova.local
DNS.6 = n8n.technova.local
```

Générer le certificat :

```bash
openssl req -x509 -nodes -days 3650 \
  -key technova.local.key \
  -out technova.local.crt \
  -config technova.local.cnf
```

Vérifier :

```bash
ls -l
openssl x509 -in technova.local.crt -text -noout | grep -A1 "Subject Alternative Name"
```

Résultat attendu :

```text
DNS:technova.local, DNS:*.technova.local, DNS:nextcloud.technova.local, DNS:rocket.technova.local, DNS:meet.technova.local, DNS:n8n.technova.local
```

Important :

```text
technova.local.key est une clé privée.
Elle ne doit pas être publiée dans le dépôt Git.
```

---

## 9. Importer le certificat dans Nginx Proxy Manager

Dans Nginx Proxy Manager :

```text
Certificates
-> Add Certificate
-> Custom Certificate
```

Remplir :

```text
Name : technova-local
```

Sélectionner :

```text
Certificate Key          -> technova.local.key
Certificate              -> technova.local.crt
Intermediate Certificate -> vide
```

Cliquer sur :

```text
Save
```

Résultat attendu :

```text
Certificat : technova-local
Provider   : Custom Certificate
```

---

## 10. Installer le certificat sur Windows

Depuis Windows, copier le certificat :

```powershell
scp -o StrictHostKeyChecking=accept-new yoann@192.168.192.15:/opt/certs/technova/technova.local.crt "$env:USERPROFILE\Desktop\technova.local.crt"
```

Installer le certificat :

```text
Clic droit sur technova.local.crt
-> Installer le certificat
-> Ordinateur local
-> Placer tous les certificats dans le magasin suivant
-> Autorités de certification racines de confiance
-> Terminer
-> Oui
```

Fermer puis rouvrir complètement le navigateur.

---

## 11. Créer le Proxy Host Nextcloud

Dans Nginx Proxy Manager :

```text
Hosts
-> Proxy Hosts
-> Add Proxy Host
```

Onglet **Details** :

```text
Domain Names  : nextcloud.technova.local
Scheme        : http
Forward Host  : 192.168.192.20
Forward Port  : 80
Access List   : Publicly Accessible
```

Options :

```text
Cache Assets           : OFF
Block Common Exploits  : ON
Websockets Support     : ON
```

Onglet **SSL** :

```text
SSL Certificate : technova-local
Force SSL       : ON
HTTP/2 Support  : ON
HSTS Enabled    : OFF
HSTS Subdomains : OFF
```

Enregistrer.

---

## 12. Adapter Nextcloud au reverse proxy HTTPS

Sur SRV-NEXTCLOUD :

```bash
cd /opt/nextcloud
```

Ajouter le domaine de confiance :

```bash
docker exec -u www-data -it nextcloud php occ config:system:set trusted_domains 2 --value=nextcloud.technova.local
```

Ajouter le proxy de confiance :

```bash
docker exec -u www-data -it nextcloud php occ config:system:set trusted_proxies 0 --value=192.168.192.15
```

Forcer HTTPS côté Nextcloud :

```bash
docker exec -u www-data -it nextcloud php occ config:system:set overwriteprotocol --value=https
```

Définir l'URL principale :

```bash
docker exec -u www-data -it nextcloud php occ config:system:set overwrite.cli.url --value=https://nextcloud.technova.local
```

Redémarrer :

```bash
docker compose restart
```

Tester depuis Windows :

```text
https://nextcloud.technova.local
```

Résultat attendu :

```text
La page Nextcloud s'affiche en HTTPS avec un certificat reconnu par Windows.
```

---

## 13. Créer le Proxy Host Rocket.Chat

Dans Nginx Proxy Manager :

```text
Hosts
-> Proxy Hosts
-> Add Proxy Host
```

Onglet **Details** :

```text
Domain Names  : rocket.technova.local
Scheme        : http
Forward Host  : 192.168.192.30
Forward Port  : 3000
Access List   : Publicly Accessible
```

Options :

```text
Cache Assets           : OFF
Block Common Exploits  : ON
Websockets Support     : ON
```

Important :

```text
Websockets Support doit être activé pour Rocket.Chat.
```

Onglet **SSL** :

```text
SSL Certificate : technova-local
Force SSL       : ON
HTTP/2 Support  : ON
HSTS Enabled    : OFF
HSTS Subdomains : OFF
```

Enregistrer.

---

## 14. Adapter Rocket.Chat au reverse proxy HTTPS

Sur SRV-CHAT :

```bash
cd /opt/rocketchat
nano .env
```

Modifier `ROOT_URL`.

Avant :

```env
ROOT_URL="http://rocket.technova.local:3000"
```

Après :

```env
ROOT_URL="https://rocket.technova.local"
```

Conserver :

```env
ROCKETCHAT_PORT="3000"
```

Explication :

```text
Le client accède à Rocket.Chat en HTTPS sur le port 443 via le proxy.
Le port 3000 reste utilisé uniquement entre Nginx Proxy Manager et Rocket.Chat.
```

Redémarrer Rocket.Chat :

```bash
docker compose down
docker compose up -d
docker compose ps
```

Tester depuis Windows :

```text
https://rocket.technova.local
```

Résultat attendu :

```text
Rocket.Chat s'ouvre en HTTPS via Nginx Proxy Manager.
```

---

## 15. Créer le Proxy Host Jitsi Meet

Dans Nginx Proxy Manager :

```text
Hosts
-> Proxy Hosts
-> Add Proxy Host
```

Onglet **Details** :

```text
Domain Names          : meet.technova.local
Scheme                : https
Forward Hostname / IP : 192.168.192.40
Forward Port          : 443
Access List           : Publicly Accessible
```

Options :

```text
Cache Assets           : OFF
Block Common Exploits  : OFF
Websockets Support     : ON
```

Important :

```text
Websockets Support doit être activé pour Jitsi.
Block Common Exploits est laissé désactivé pour éviter de casser certains chemins Jitsi.
```

Onglet **SSL** :

```text
SSL Certificate : technova-local
Force SSL       : ON
HTTP/2 Support  : ON
HSTS Enabled    : OFF
HSTS Subdomains : OFF
```

Onglet **Advanced** :

```nginx
proxy_ssl_verify off;
```

Cette directive permet à Nginx Proxy Manager de communiquer en HTTPS avec SRV-JITSI même si le certificat backend de Jitsi est un certificat local généré automatiquement.

Enregistrer.

---

## 16. Vérifier le port WebRTC Jitsi

Sur SRV-JITSI :

```bash
sudo ss -lunp | grep 10000
```

Résultat attendu :

```text
192.168.192.40:10000
```

Si un pare-feu est présent entre le client et Jitsi, autoriser :

```text
Source      : réseau client
Destination : 192.168.192.40
Protocole   : UDP
Port        : 10000
Action      : Allow
```

Tester depuis Windows :

```text
https://meet.technova.local
```

Résultat attendu :

```text
La page Jitsi s'affiche en HTTPS.
Le certificat est reconnu.
Une salle peut être créée ou rejointe.
Le micro et la caméra peuvent être autorisés.
```

---

## 17. Activer l'authentification Jitsi avec Active Directory

La configuration détaillée est conservée dans la procédure dédiée :

[Authentification Jitsi avec Active Directory](08-jitsi-active-directory.md)

Résumé de la chaîne d'authentification :

```text
Jitsi Meet
   |
Prosody avec authentication = "cyrus"
   |
Cyrus SASL
   |
saslauthd
   |
LDAP / Active Directory technova.local
```

Points essentiels à appliquer sur SRV-JITSI :

```text
- configurer /etc/saslauthd.conf vers l'AD ;
- activer MECHANISMS="ldap" dans /etc/default/saslauthd ;
- créer /etc/sasl2/xmpp.conf avec pwcheck_method: saslauthd ;
- ajouter prosody au groupe sasl ;
- configurer Prosody avec authentication = "cyrus" ;
- conserver guest.meet.technova.local pour les invités ;
- activer l'authentification XMPP dans Jicofo ;
- supprimer libsasl2-modules-ldap si le module ldapdb provoque no-auth-mech.
```

Test SASL attendu :

```bash
sudo /usr/sbin/testsaslauthd -u Administrateur -p 'MOT_DE_PASSE_AD' -s xmpp
```

Résultat attendu :

```text
0: OK "Success."
```

Test navigateur :

```text
https://meet.technova.local/test-cyrus-ok
```

Connexion :

```text
Utilisateur : Administrateur
Mot de passe : mot de passe AD
```

Résultat attendu :

```text
L'utilisateur AD peut créer une réunion Jitsi.
Les invités peuvent rejoindre une réunion existante si le lien leur est transmis.
```

---

## 18. Validation finale du POC sécurisé

Depuis Windows :

```powershell
ipconfig /flushdns
nslookup nextcloud.technova.local
nslookup rocket.technova.local
nslookup meet.technova.local
Test-NetConnection nextcloud.technova.local -Port 443
Test-NetConnection rocket.technova.local -Port 443
Test-NetConnection meet.technova.local -Port 443
```

Résultat attendu :

```text
Les trois noms DNS pointent vers 192.168.192.15.
TcpTestSucceeded : True
```

Accès à valider :

```text
https://nextcloud.technova.local
https://rocket.technova.local
https://meet.technova.local
```

Résultat final :

```text
Nextcloud est accessible en HTTPS via Nginx Proxy Manager.
Rocket.Chat est accessible en HTTPS via Nginx Proxy Manager.
Jitsi Meet est accessible en HTTPS via Nginx Proxy Manager.
Jitsi utilise l'Active Directory pour autoriser la création de réunions.
Le certificat technova-local est reconnu par le poste Windows.
```

---

## 19. Commandes de dépannage

### Nginx Proxy Manager

```bash
cd /opt/nginx-proxy-manager
docker compose ps
docker compose logs -f
docker compose restart
```

### Nextcloud

```bash
cd /opt/nextcloud
docker compose ps
docker compose logs -f app
```

Vérifier les paramètres :

```bash
docker exec -u www-data -it nextcloud php occ config:system:get trusted_domains
docker exec -u www-data -it nextcloud php occ config:system:get trusted_proxies
docker exec -u www-data -it nextcloud php occ config:system:get overwriteprotocol
docker exec -u www-data -it nextcloud php occ config:system:get overwrite.cli.url
```

### Rocket.Chat

```bash
cd /opt/rocketchat
docker compose ps
docker compose logs -f rocketchat
grep ROOT_URL .env
```

### Jitsi

```bash
systemctl status prosody --no-pager
systemctl status jicofo --no-pager
systemctl status jitsi-videobridge2 --no-pager
sudo journalctl -u prosody -n 50 --no-pager
sudo ss -lunp | grep 10000
```

### Windows

```powershell
ipconfig /flushdns
nslookup nextcloud.technova.local
nslookup rocket.technova.local
nslookup meet.technova.local
Test-NetConnection nextcloud.technova.local -Port 443
Test-NetConnection rocket.technova.local -Port 443
Test-NetConnection meet.technova.local -Port 443
```

---

## 20. Problème possible : micro et caméra non détectés dans Jitsi

Symptôme :

```text
Microphone : Aucun
Caméra     : Aucun
```

Causes possibles :

```text
- micro ou caméra non connectés à la machine virtuelle ;
- carte son non connectée dans VMware ;
- webcam USB non attachée à la VM ;
- périphérique déjà utilisé par une autre application ;
- autorisation navigateur incorrecte ;
- autorisation Windows désactivée.
```

Dans Edge, vérifier :

```text
edge://settings/content/microphone
edge://settings/content/camera
```

Dans VMware Workstation :

```text
VM
-> Settings
-> Sound Card
-> Connected
-> Connect at power on
```

Pour une webcam USB :

```text
VM
-> Removable Devices
-> Nom de la webcam
-> Connect to this virtual machine
```

Une fois les périphériques attachés à la VM, Jitsi peut les détecter depuis :

```text
https://meet.technova.local
```

---

## 21. Points importants à retenir

```text
- Les DNS applicatifs pointent vers SRV-PROXY.
- Les IP des serveurs applicatifs ne changent pas.
- Nginx Proxy Manager redirige le trafic vers les vraies IP internes.
- Le certificat auto-signé doit être importé dans Windows.
- Rocket.Chat ne doit pas avoir :3000 dans ROOT_URL quand il passe par HTTPS.
- Rocket.Chat nécessite Websockets Support activé dans NPM.
- Jitsi nécessite Websockets Support activé dans NPM.
- Jitsi conserve UDP 10000 vers SRV-JITSI pour les flux audio/vidéo.
- HSTS reste désactivé au début pour éviter les blocages en lab.
- La clé privée technova.local.key ne doit jamais être publiée dans le dépôt.
```
