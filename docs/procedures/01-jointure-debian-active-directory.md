# Procédure corrigée — Joindre une Debian au domaine Active Directory TechNova

## Objectif

Joindre une machine Debian au domaine Active Directory :

```text
Domaine AD : technova.local
Royaume Kerberos : TECHNOVA.LOCAL
Contrôleur de domaine / DNS : 192.168.192.10
```

Cette procédure est à réaliser sur chaque serveur Debian qui doit être intégré au domaine.

---

## 1. Prérequis

Avant de commencer, vérifier que :

```text
L'AD est installé et fonctionnel.
Le DNS du domaine répond.
La Debian a une IP fixe.
La Debian utilise le DNS du contrôleur de domaine.
Le serveur Debian peut joindre le contrôleur de domaine.
```

Exemple pour `SRV-NEXTCLOUD` :

```text
Hostname : SRV-NEXTCLOUD
IP : 192.168.192.20
DNS : 192.168.192.10
Domaine : technova.local
```

---

## 2. Vérifier la résolution DNS

```bash
cat /etc/resolv.conf
```

Résultat attendu :

```text
search technova.local
nameserver 192.168.192.10
```

Tester le contrôleur de domaine :

```bash
ping -c 4 192.168.192.10
ping -c 4 technova.local
```

---

## 3. Installer les paquets nécessaires

```bash
sudo apt update
sudo apt install -y realmd sssd sssd-tools adcli krb5-user packagekit samba-common samba-common-bin libnss-sss libpam-sss
```

Pendant l'installation, si une fenêtre Kerberos apparaît, renseigner le royaume en majuscules :

```text
TECHNOVA.LOCAL
```

Valider avec `Tab`, puis `Entrée`.

---

## 4. Point important sur la commande `realm`

Sur certaines Debian, la commande `realm` est installée mais n'est pas accessible directement.

Vérifier :

```bash
sudo find / -name realm -type f 2>/dev/null
```

Résultat attendu :

```text
/usr/sbin/realm
```

Dans cette procédure, on utilise donc le chemin complet :

```bash
sudo /usr/sbin/realm
```

---

## 5. Découvrir le domaine Active Directory

```bash
sudo /usr/sbin/realm discover technova.local
```

Résultat attendu :

```text
technova.local
  type: kerberos
  realm-name: TECHNOVA.LOCAL
  domain-name: technova.local
  configured: no
  server-software: active-directory
  client-software: sssd
```

Les lignes importantes sont :

```text
server-software: active-directory
client-software: sssd
```

---

## 6. Joindre la Debian au domaine

```bash
sudo /usr/sbin/realm join --user=Administrateur technova.local
```

Saisir le mot de passe du compte :

```text
TECHNOVA\Administrateur
```

Si le compte `Administrateur` ne fonctionne pas, essayer :

```bash
sudo /usr/sbin/realm join --user=Administrator technova.local
```

---

## 7. Vérifier la jointure au domaine

```bash
sudo /usr/sbin/realm list
```

Résultat attendu :

```text
configured: kerberos-member
```

---

## 8. Vérifier qu'un compte AD est reconnu

```bash
id 'TECHNOVA\Administrateur'
```

Si cela ne répond pas correctement, tester :

```bash
id administrateur@technova.local
```

Résultat attendu :

```text
uid=...
gid=...
groups=...
```

---

## 9. Activer la création automatique du dossier personnel

```bash
sudo pam-auth-update
```

Dans l'écran de configuration PAM, cocher :

```text
Create home directory on login
```

Touches à utiliser :

```text
Flèches du clavier pour descendre
Espace pour cocher
Tab pour aller sur OK
Entrée pour valider
```

---

## 10. Vérification côté Windows Server

Sur le contrôleur de domaine, ouvrir :

```text
Utilisateurs et ordinateurs Active Directory
```

Aller dans :

```text
Computers
```

Vérifier que la machine Debian apparaît, par exemple :

```text
SRV-NEXTCLOUD
```

---

## 11. Redémarrer la Debian

```bash
sudo reboot
```

Après redémarrage :

```bash
sudo /usr/sbin/realm list
```

Résultat attendu :

```text
configured: kerberos-member
```

---

## 12. Résumé court des commandes

```bash
sudo apt update
sudo apt install -y realmd sssd sssd-tools adcli krb5-user packagekit samba-common samba-common-bin libnss-sss libpam-sss

sudo /usr/sbin/realm discover technova.local

sudo /usr/sbin/realm join --user=Administrateur technova.local

sudo /usr/sbin/realm list

id 'TECHNOVA\Administrateur'
id administrateur@technova.local

sudo pam-auth-update

sudo reboot
```

---

## 13. Dépannage rapide

### Problème : `realm : commande introuvable`

Cause probable :

```text
La commande est installée dans /usr/sbin mais ce chemin n'est pas dans le PATH de l'utilisateur.
```

Solution :

```bash
sudo /usr/sbin/realm discover technova.local
sudo /usr/sbin/realm join --user=Administrateur technova.local
sudo /usr/sbin/realm list
```

### Problème : le domaine n'est pas détecté

Vérifier le DNS :

```bash
cat /etc/resolv.conf
ping -c 4 192.168.192.10
ping -c 4 technova.local
```

Le DNS doit pointer vers :

```text
192.168.192.10
```

### Problème : échec de jointure au domaine

Vérifier :

```text
Le mot de passe du compte Administrateur.
Le nom du compte : Administrateur ou Administrator.
La résolution DNS.
L'heure du système Debian et du contrôleur de domaine.
```

Tester l'heure :

```bash
date
```

Si nécessaire :

```bash
sudo timedatectl set-ntp true
```

---

## 14. Validation finale

La jointure est validée si :

```text
realm list affiche configured: kerberos-member
Un utilisateur AD est reconnu avec la commande id
La machine apparaît dans Active Directory > Computers
Le dossier personnel peut être créé automatiquement à la connexion
```
