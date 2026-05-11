# Procédure manuelle — Installation de Jitsi Meet sur Debian 13

## Objectif

Installer Jitsi Meet manuellement sur Debian 13.

Cette procédure reprend l’installation prévue dans le script `03-install-jitsi.sh`, mais sous forme manuelle.

---

## 1. Architecture utilisée

```text
Serveur Jitsi : Debian 13
Service       : Jitsi Meet
Serveur web   : Nginx
Nom DNS       : meet.technova.local
IP Jitsi      : 192.168.192.40
```

Exemple :

```text
URL de test : http://meet.technova.local
```

Pour un environnement final, l’accès HTTPS est recommandé, surtout pour l’utilisation caméra/micro dans le navigateur.

---

## 2. Vérifier le nom DNS et l’IP

Vérifier l’IP du serveur :

```bash
ip a
```

Vérifier le nom actuel :

```bash
hostname
hostname -f
```

---

## 3. Mettre à jour Debian

```bash
sudo apt update
sudo apt upgrade -y
```

Installer les dépendances nécessaires :

```bash
sudo apt install -y curl gnupg2 apt-transport-https ca-certificates debconf-utils nginx-full
```

---

## 4. Configurer le hostname

Définir le hostname du serveur :

```bash
sudo hostnamectl set-hostname meet.technova.local
```

Vérifier :

```bash
hostname -f
```

---

## 5. Ajouter l’entrée dans `/etc/hosts`

Ouvrir le fichier :

```bash
sudo nano /etc/hosts
```

Ajouter la ligne suivante :

```text
192.168.192.40 meet.technova.local
```

Adapter l’IP si nécessaire.

Vérifier :

```bash
ping -c 4 meet.technova.local
```

---

## 6. Ajouter le dépôt Jitsi

Ajouter la clé du dépôt Jitsi :

```bash
curl -fsSL https://download.jitsi.org/jitsi-key.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/jitsi-keyring.gpg
```

Ajouter le dépôt :

```bash
echo "deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/" | sudo tee /etc/apt/sources.list.d/jitsi-stable.list >/dev/null
```

Mettre à jour les dépôts :

```bash
sudo apt update
```

---

## 7. Préconfigurer l’installation Jitsi

Définir le nom DNS utilisé par Jitsi Videobridge :

```bash
echo "jitsi-videobridge2 jitsi-videobridge/jvb-hostname string meet.technova.local" | sudo debconf-set-selections
```

Choisir un certificat auto-signé pour le POC :

```bash
echo "jitsi-meet-web-config jitsi-meet/cert-choice select Generate a new self-signed certificate" | sudo debconf-set-selections
```

---

## 8. Installer Jitsi Meet

Installer Jitsi Meet :

```bash
sudo DEBIAN_FRONTEND=noninteractive apt install -y jitsi-meet
```

Pendant l’installation, Jitsi configure automatiquement plusieurs composants :

```text
- prosody
- jicofo
- jitsi-videobridge2
- jitsi-meet-web
- nginx
```

---

## 9. Redémarrer les services

```bash
sudo systemctl restart prosody
sudo systemctl restart jicofo
sudo systemctl restart jitsi-videobridge2
sudo systemctl restart nginx
```

---

## 10. Vérifier les services

```bash
systemctl status prosody --no-pager
systemctl status jicofo --no-pager
systemctl status jitsi-videobridge2 --no-pager
systemctl status nginx --no-pager
```

Résultat attendu :

```text
Active: active (running)
```

---

## 11. Tester l’accès navigateur

Depuis un navigateur :

```text
http://meet.technova.local
```

Créer une salle de test :

```text
http://meet.technova.local/test
```

Résultat attendu :

```text
L’interface Jitsi Meet s’affiche.
Une salle de réunion peut être créée.
```

---

## 12. Attention HTTP / HTTPS

En HTTP, certains navigateurs peuvent bloquer caméra et micro.

Pour un POC local, l’interface peut être testée.

Pour un environnement final, prévoir :

```text
- HTTPS
- certificat valide ou certificat interne approuvé
- reverse proxy si nécessaire
```

---

## 13. Commandes utiles

Voir l’état des services :

```bash
systemctl status prosody --no-pager
systemctl status jicofo --no-pager
systemctl status jitsi-videobridge2 --no-pager
systemctl status nginx --no-pager
```

Voir les logs Prosody :

```bash
sudo journalctl -u prosody -f
```

Voir les logs Jicofo :

```bash
sudo journalctl -u jicofo -f
```

Voir les logs Jitsi Videobridge :

```bash
sudo journalctl -u jitsi-videobridge2 -f
```

Voir les logs Nginx :

```bash
sudo journalctl -u nginx -f
```

Redémarrer Jitsi :

```bash
sudo systemctl restart prosody
sudo systemctl restart jicofo
sudo systemctl restart jitsi-videobridge2
sudo systemctl restart nginx
```

---

## 14. Fichiers importants

Configuration web Jitsi :

```text
/etc/jitsi/meet/meet.technova.local-config.js
```

Configuration Prosody :

```text
/etc/prosody/conf.d/meet.technova.local.cfg.lua
```

Configuration Jicofo :

```text
/etc/jitsi/jicofo/jicofo.conf
```

Configuration Nginx :

```text
/etc/nginx/sites-available/meet.technova.local.conf
```

---

## 15. Résultat attendu

```text
Jitsi Meet est installé sur Debian 13.

Les services suivants sont actifs :
- prosody
- jicofo
- jitsi-videobridge2
- nginx

L’interface Jitsi est accessible via :
http://meet.technova.local
```
