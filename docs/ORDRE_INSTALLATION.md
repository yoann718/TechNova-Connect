# Procédure complète d'installation — Infrastructure TechNova

Ce document est le fil conducteur officiel pour reproduire l'infrastructure du POC TechNova Connect.

Il indique l'ordre d'installation, les scripts à lancer, les procédures manuelles disponibles et les liens vers les configurations graphiques des services.

## 1. Architecture cible

| Serveur | OS | Rôle | IP | Nom DNS |
|---|---|---|---:|---|
| SRV-AD | Windows Server 2022 | AD DS / DNS / DHCP | 192.168.192.10 | srv-ad.technova.local |
| SRV-NEXTCLOUD | Debian 13 | Nextcloud | 192.168.192.20 | nextcloud.technova.local |
| SRV-CHAT | Debian 13 | Rocket.Chat | 192.168.192.30 | rocket.technova.local |
| SRV-JITSI | Debian 13 | Jitsi Meet | 192.168.192.40 | meet.technova.local |
| SRV-N8N | Debian 13 | n8n optionnel | 192.168.192.50 | n8n.technova.local |
| SRV-PROXY | Debian 13 | Nginx Proxy Manager / HTTPS | 192.168.192.15 | proxy.technova.local |

Réseau VMware :

```text
Réseau      : 192.168.192.0/24
Passerelle  : 192.168.192.2
DNS interne : 192.168.192.10
Domaine AD  : technova.local
```

## 2. Préparer le réseau VMware

Dans VMware Workstation :

1. Créer ou modifier le réseau VMnet du POC.
2. Utiliser le réseau `192.168.192.0/24`.
3. Utiliser la passerelle `192.168.192.2`.
4. Désactiver le DHCP VMware si le DHCP est fourni par Windows Server.
5. Connecter toutes les VM au même VMnet.

## 3. Installer SRV-AD en premier

Machine :

```text
Nom : SRV-AD
OS  : Windows Server 2022
IP  : 192.168.192.10
DNS : 192.168.192.10
```

Configurer l'IP fixe sur Windows Server, renommer le serveur en `SRV-AD`, puis redémarrer si nécessaire.

### 3.1 Créer l'Active Directory

Sur SRV-AD, ouvrir PowerShell en administrateur.

Lancer :

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
.\scripts\windows\01-Creation_AD.ps1
```

Ce script installe et configure :

- le rôle AD DS ;
- le domaine `technova.local` ;
- le DNS ;
- le DHCP ;
- les OU ;
- les groupes ;
- les utilisateurs.

Après promotion du serveur en contrôleur de domaine, un redémarrage peut être nécessaire.

### 3.2 Ajouter les mails utilisateurs

Après le redémarrage de SRV-AD, relancer PowerShell en administrateur.

```powershell
.\scripts\windows\02-mailUtil.ps1
```

Résultat attendu :

```text
prenom.nom@technova.local
```

### 3.3 Créer les DNS applicatifs

Toujours sur SRV-AD :

```powershell
.\scripts\windows\03-DNS_Services.ps1
```

Ce script crée :

```text
nextcloud.technova.local -> 192.168.192.20
rocket.technova.local    -> 192.168.192.30
meet.technova.local      -> 192.168.192.40
n8n.technova.local       -> 192.168.192.50 (optionnel)
```

Vérifier :

```powershell
Resolve-DnsName nextcloud.technova.local
Resolve-DnsName rocket.technova.local
Resolve-DnsName meet.technova.local
Resolve-DnsName n8n.technova.local
```

## 4. Préparer les VM Debian

Créer les VM Debian 13 suivantes :

| Serveur | IP | Service |
|---|---:|---|
| SRV-NEXTCLOUD | 192.168.192.20 | Nextcloud |
| SRV-CHAT | 192.168.192.30 | Rocket.Chat |
| SRV-JITSI | 192.168.192.40 | Jitsi Meet |
| SRV-N8N | 192.168.192.50 | n8n optionnel |
| SRV-PROXY | 192.168.192.15 | Reverse proxy HTTPS final |

Configurer l'IP fixe avec le script du dépôt :

[scripts/linux/00-configure-static-ip.sh](../scripts/linux/00-configure-static-ip.sh)

Sur SRV-NEXTCLOUD :

```bash
sudo ./scripts/linux/00-configure-static-ip.sh --hostname SRV-NEXTCLOUD --ip 192.168.192.20 --gateway 192.168.192.2 --dns 192.168.192.10
```

Sur SRV-CHAT :

```bash
sudo ./scripts/linux/00-configure-static-ip.sh --hostname SRV-CHAT --ip 192.168.192.30 --gateway 192.168.192.2 --dns 192.168.192.10
```

Sur SRV-JITSI :

```bash
sudo ./scripts/linux/00-configure-static-ip.sh --hostname SRV-JITSI --ip 192.168.192.40 --gateway 192.168.192.2 --dns 192.168.192.10
```

Sur SRV-N8N, uniquement si n8n est installé dans le POC :

```bash
sudo ./scripts/linux/00-configure-static-ip.sh --hostname SRV-N8N --ip 192.168.192.50 --gateway 192.168.192.2 --dns 192.168.192.10
```

Sur SRV-PROXY, pour la phase finale HTTPS :

```bash
sudo ./scripts/linux/00-configure-static-ip.sh --hostname SRV-PROXY --ip 192.168.192.15 --gateway 192.168.192.2 --dns 192.168.192.10
```

Redémarrer chaque serveur Debian après application :

```bash
sudo reboot
```

## 5. Joindre les serveurs Debian au domaine

Faire la jointure au domaine avant l'installation des services permet de valider immédiatement le DNS, la résolution du domaine et l'accès à Active Directory.

Précondition importante :

```text
DNS Debian = 192.168.192.10
```

Commande normale à lancer sur chaque Debian :

```bash
sudo apt update
sudo apt install -y realmd sssd sssd-tools adcli krb5-user packagekit samba-common samba-common-bin libnss-sss libpam-sss
realm discover technova.local
sudo realm join --user=Administrateur technova.local
realm list
```

Le domaine `technova.local` doit apparaître avant de continuer.

Si `realm list` ne retourne pas le domaine, ou si la commande `realm` ne fonctionne pas avec une erreur comme :

```text
bash: realm : commande introuvable
```

se référer à la procédure corrigée :

[Jointure Debian au domaine Active Directory](procedures/01-jointure-debian-active-directory.md)

## 6. Installer les services applicatifs

Pour chaque service, deux approches peuvent exister :

- **Installation scriptée** : recommandée pour reproduire rapidement le POC.
- **Installation manuelle** : utile pour comprendre, documenter ou dépanner.

Les scripts Linux utilisent les fichiers du dossier `env/`. Ils acceptent aussi un `.env` placé à côté du script si le script est copié seul sur une VM Debian.

### 6.1 Nextcloud

Installation scriptée :

```bash
chmod +x scripts/linux/01-install-nextcloud.sh
./scripts/linux/01-install-nextcloud.sh
```

Installation manuelle :

[Procédure manuelle Nextcloud](procedures/02-installation-nextcloud-manuelle.md)

### 6.2 Rocket.Chat

Installation scriptée recommandée :

```bash
chmod +x scripts/linux/02-install-rocketchat.sh
./scripts/linux/02-install-rocketchat.sh
```

Procédures détaillées :

- [Installation Rocket.Chat automatisée](procedures/04-installation-rocketchat-automatisee.md)
- [Installation Rocket.Chat manuelle](procedures/05-installation-rocketchat-manuelle.md)

### 6.3 Jitsi Meet

Installation scriptée :

```bash
chmod +x scripts/linux/03-install-jitsi.sh
./scripts/linux/03-install-jitsi.sh
```

Installation manuelle :

[Procédure manuelle Jitsi](procedures/07-installation-jitsi-manuelle.md)

Après l'installation de Jitsi, appliquer la procédure d'authentification Active Directory si les utilisateurs du domaine doivent pouvoir créer des réunions avec leur compte AD :

[Authentification Jitsi avec Active Directory](procedures/08-jitsi-active-directory.md)

### 6.4 n8n optionnel

n8n est optionnel pour ce projet. Il peut être installé si le POC doit démontrer des automatisations internes, mais il n'est pas nécessaire pour valider l'infrastructure AD, Nextcloud, Rocket.Chat et Jitsi.

Installation scriptée, seulement si n8n est retenu :

```bash
chmod +x scripts/linux/04-install-n8n.sh
./scripts/linux/04-install-n8n.sh
```

Pour le POC, n8n peut rester avec un compte local administrateur.

## 7. Configurer les services avec Active Directory

La configuration des services vers Active Directory se fait uniquement en graphique dans ce POC.

Aucun script automatique n'est utilisé pour paramétrer LDAP dans les applications.

Procédures graphiques :

- [Nextcloud — LDAP/AD via interface graphique](procedures/03-nextcloud-ldap-active-directory.md)
- [Rocket.Chat — LDAP, groupes et canaux via interface graphique](procedures/06-rocketchat-ldap-groupes-canaux.md)

Pour Jitsi, l'authentification AD complète demande une configuration système côté Debian/Prosody. Elle est donc conservée comme procédure avancée, pas comme étape graphique obligatoire du POC :

[Jitsi — authentification Active Directory](procedures/08-jitsi-active-directory.md)

## 8. Finaliser les accès sécurisés HTTPS

La dernière phase publie les services derrière Nginx Proxy Manager, installe un certificat interne reconnu par Windows et valide l'accès sécurisé aux applications :

[Finalisation HTTPS et authentification AD](procedures/09-finalisation-https-reverse-proxy-authentification.md)

À la fin de cette phase, les accès attendus sont :

```text
https://nextcloud.technova.local
https://rocket.technova.local
https://meet.technova.local
```

Les enregistrements DNS applicatifs `nextcloud`, `rocket` et `meet` pointent alors vers `SRV-PROXY` en `192.168.192.15`.

## 9. Valider le POC

Utiliser les documents de validation :

- [CONFORMITE_PREREQUIS.md](CONFORMITE_PREREQUIS.md)
- [PLAN_TESTS_VALIDATION.md](PLAN_TESTS_VALIDATION.md)
- [CHECKLIST_POC_LOCAL.md](CHECKLIST_POC_LOCAL.md)

Les incidents rencontrés pendant le POC sont conservés ici :

[incidents/](incidents/)

## 10. Suite possible

Après validation du POC local :

- documenter les sauvegardes ;
- préparer une procédure de restauration.
