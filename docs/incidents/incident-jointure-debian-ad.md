# POC — Jointure Debian au domaine Active Directory TechNova

## 1. Contexte

Dans le cadre du POC TechNova, les serveurs Debian doivent être intégrés au domaine Active Directory afin de centraliser l'identité et préparer les futures intégrations LDAP/AD.

Serveur testé :

```text
Serveur : SRV-NEXTCLOUD
Système : Debian 13
Domaine AD : technova.local
Royaume Kerberos : TECHNOVA.LOCAL
Contrôleur de domaine / DNS : 192.168.192.10
```

Objectif :

```text
Joindre la machine Debian au domaine Active Directory technova.local.
```

---

## 2. Procédure initiale prévue

La procédure de base était :

```bash
sudo apt update
sudo apt install -y realmd sssd sssd-tools adcli krb5-user packagekit samba-common samba-common-bin
realm discover technova.local
sudo realm join --user=Administrateur technova.local
realm list
```

---

## 3. Problème rencontré

Après installation des paquets, la commande suivante ne fonctionnait pas :

```bash
realm discover technova.local
```

Erreur obtenue :

```text
bash: realm : commande introuvable
```

Pourtant, le paquet `realmd` était bien installé.

---

## 4. Diagnostic

Recherche de la commande :

```bash
sudo find / -name realm -type f 2>/dev/null
```

Résultat :

```text
/usr/sbin/realm
```

Conclusion :

```text
La commande realm existe, mais elle doit être appelée avec son chemin complet : /usr/sbin/realm.
```

---

## 5. Correction appliquée

Commande corrigée :

```bash
sudo /usr/sbin/realm discover technova.local
```

Résultat obtenu :

```text
technova.local
  type: kerberos
  realm-name: TECHNOVA.LOCAL
  domain-name: technova.local
  configured: no
  server-software: active-directory
  client-software: sssd
```

Ce résultat valide que Debian détecte correctement le domaine Active Directory.

---

## 6. Jointure au domaine

Commande utilisée :

```bash
sudo /usr/sbin/realm join --user=Administrateur technova.local
```

Le mot de passe demandé correspond au compte :

```text
TECHNOVA\Administrateur
```

Après validation, aucune erreur n'a été affichée.

---

## 7. Validation de la jointure

Commande de vérification :

```bash
sudo /usr/sbin/realm list
```

Résultat attendu :

```text
configured: kerberos-member
```

Cela indique que la machine Debian est bien intégrée au domaine Active Directory.

---

## 8. Configuration PAM

Après la jointure, la commande suivante a été lancée :

```bash
sudo pam-auth-update
```

L'option suivante a été activée :

```text
Create home directory on login
```

Objectif :

```text
Créer automatiquement le dossier personnel d'un utilisateur AD lors de sa première connexion sur Debian.
```

---

## 9. Vérifications complémentaires

Vérifier qu'un utilisateur AD est reconnu :

```bash
id 'TECHNOVA\Administrateur'
```

ou :

```bash
id administrateur@technova.local
```

Vérifier côté Windows Server :

```text
Utilisateurs et ordinateurs Active Directory > Computers
```

La machine suivante doit apparaître :

```text
SRV-NEXTCLOUD
```

---

## 10. Écart entre procédure initiale et procédure corrigée

La procédure initiale était correcte dans son principe, mais elle manquait de précision sur les points suivants :

```text
Utilisation du chemin complet /usr/sbin/realm.
Saisie du royaume Kerberos TECHNOVA.LOCAL en majuscules.
Activation de la création automatique des dossiers personnels avec pam-auth-update.
Ajout de tests de validation après jointure.
Vérification côté Active Directory.
```

---

## 11. Procédure corrigée retenue

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

## 12. Conclusion POC

La jointure de Debian au domaine Active Directory est validée.

Le problème rencontré ne venait pas de l'AD ni du DNS, mais du fait que la commande `realm` devait être appelée depuis son chemin complet :

```text
/usr/sbin/realm
```

La procédure a donc été corrigée pour être plus fiable et réutilisable sur les autres serveurs Debian du projet :

```text
SRV-CHAT
SRV-JITSI
SRV-N8N
```

Cette correction améliore la reproductibilité du POC et facilite la suite du déploiement.
