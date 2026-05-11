# Procédure — Authentification Jitsi avec les utilisateurs Active Directory

## Objectif

Permettre à **tous les utilisateurs du domaine Active Directory** de se connecter à Jitsi avec leur compte AD afin de pouvoir créer des réunions.

Cette procédure s'applique après l'installation de Jitsi Meet sur `SRV-JITSI`.

Architecture utilisée :

```text
Utilisateur AD
     |
     v
Interface Web Jitsi
     |
     v
Prosody
     |
     v
Cyrus SASL
     |
     v
saslauthd
     |
     v
LDAP / Active Directory
```

Résultat attendu :

```text
- Jitsi Meet est déjà installé sur Debian
- La machine Debian est déjà jointe au domaine technova.local
- L'authentification Jitsi passe par l'Active Directory
- Tous les utilisateurs AD valides peuvent créer une réunion
- Les invités anonymes peuvent rejoindre une réunion existante si le lien leur est transmis
```

---

## 1. Préconditions

```text
Serveur AD/DNS      : Windows Server 2022
Domaine AD          : technova.local
IP du contrôleur AD : 192.168.192.10

Serveur Jitsi       : Debian 13
Nom DNS Jitsi       : meet.technova.local
IP Jitsi            : 192.168.192.40
Jitsi Meet          : déjà installé
Debian              : déjà jointe au domaine AD
```

Vérifier que Debian est bien jointe au domaine :

```bash
realm list
```

Résultat attendu :

```text
technova.local
  type: kerberos
  realm-name: TECHNOVA.LOCAL
  configured: kerberos-member
```

Tester le port LDAP :

```bash
nc -nvz 192.168.192.10 389
```

Résultat attendu :

```text
192.168.192.10 389 (ldap) open
```

Tester LDAP directement :

```bash
ldapsearch -x \
  -H ldap://192.168.192.10 \
  -D "Administrateur@technova.local" \
  -W \
  -b "DC=technova,DC=local" \
  "(sAMAccountName=Administrateur)"
```

Résultat attendu :

```text
sAMAccountName: Administrateur
distinguishedName: CN=Administrateur,CN=Users,DC=technova,DC=local
```

---

## 2. Installer les paquets nécessaires

```bash
sudo apt update

sudo apt install -y \
  ldap-utils \
  netcat-openbsd \
  sasl2-bin \
  libsasl2-modules \
  lua-cyrussasl \
  prosody-modules \
  luarocks \
  mercurial \
  git
```

Vérifier que `testsaslauthd` existe :

```bash
which testsaslauthd
```

Si rien ne sort :

```bash
ls -l /usr/sbin/testsaslauthd
```

---

## 3. Configurer saslauthd avec l'Active Directory

Créer ou modifier le fichier :

```bash
sudo nano /etc/saslauthd.conf
```

Configuration utilisée :

```conf
ldap_servers: ldap://192.168.192.10
ldap_bind_dn: Administrateur@technova.local
ldap_bind_pw: MOT_DE_PASSE_COMPTE_LDAP
ldap_auth_method: bind
ldap_search_base: DC=technova,DC=local
ldap_filter: (sAMAccountName=%u)
ldap_version: 3
```

Explication du filtre :

```conf
ldap_filter: (sAMAccountName=%u)
```

Cela permet à tous les utilisateurs AD de se connecter avec leur identifiant court.

Exemples de connexion valides :

```text
Administrateur
Alice.Smith
Jean.Dupont
```

Exemples à ne pas utiliser dans Jitsi :

```text
TECHNOVA\Administrateur
Administrateur@technova.local
```

> Note sécurité : en production, il est recommandé de créer un compte de service dédié, par exemple `svc_ldap_jitsi`, au lieu d'utiliser le compte `Administrateur`.

---

## 4. Configurer le service saslauthd

Modifier le fichier :

```bash
sudo nano /etc/default/saslauthd
```

Mettre :

```conf
START=yes
DESC="SASL Authentication Daemon"
NAME="saslauthd"
MECHANISMS="ldap"
MECH_OPTIONS=""
THREADS=5
OPTIONS="-c -m /run/saslauthd"
```

Point important :

```conf
MECHANISMS="ldap"
```

Créer le dossier du socket :

```bash
sudo mkdir -p /run/saslauthd
sudo chown root:sasl /run/saslauthd
sudo chmod 710 /run/saslauthd
```

Activer et redémarrer le service :

```bash
sudo systemctl daemon-reload
sudo systemctl enable saslauthd
sudo systemctl restart saslauthd
sudo systemctl status saslauthd --no-pager
```

Résultat attendu :

```text
Active: active (running)
```

---

## 5. Configurer SASL pour Prosody

Créer les dossiers si nécessaire :

```bash
sudo mkdir -p /etc/sasl
sudo mkdir -p /etc/sasl2
```

Créer ou modifier le fichier :

```bash
sudo nano /etc/sasl2/xmpp.conf
```

Contenu :

```conf
pwcheck_method: saslauthd
mech_list: PLAIN
```

Fichier optionnel à garder identique :

```bash
sudo nano /etc/sasl2/prosody.conf
```

Contenu :

```conf
pwcheck_method: saslauthd
mech_list: PLAIN
```

Si Prosody attend aussi `/etc/sasl/prosody.conf`, le créer :

```bash
sudo cp /etc/sasl2/xmpp.conf /etc/sasl/prosody.conf
```

Ajouter Prosody au groupe `sasl` :

```bash
sudo usermod -aG sasl prosody
```

Vérifier :

```bash
groups prosody
```

Résultat attendu :

```text
prosody : prosody sasl
```

---

## 6. Tester l'authentification AD avec SASL

Commande :

```bash
sudo /usr/sbin/testsaslauthd -u Administrateur -p 'MOT_DE_PASSE_AD' -s xmpp
```

Résultat attendu :

```text
0: OK "Success."
```

Tester avec un utilisateur AD classique :

```bash
sudo /usr/sbin/testsaslauthd -u Alice.Smith -p 'MOT_DE_PASSE_ALICE' -s xmpp
```

Résultat attendu :

```text
0: OK "Success."
```

Cela confirme que la chaîne suivante fonctionne :

```text
saslauthd -> LDAP -> Active Directory
```

---

## 7. Installer manuellement le module Prosody auth_cyrus si nécessaire

Selon la version des paquets Prosody/Jitsi, le module `auth_cyrus` peut déjà être présent. Vérifier :

```bash
ls -l /usr/lib/prosody/modules/mod_auth_cyrus.lua
```

Si le fichier est absent, télécharger les modules Prosody :

```bash
cd /tmp
hg clone https://hg.prosody.im/prosody-modules/
```

Copier le module principal :

```bash
sudo cp /tmp/prosody-modules/mod_auth_cyrus/mod_auth_cyrus.lua /usr/lib/prosody/modules/
```

Installer la dépendance `sasl_cyrus` :

```bash
sudo mkdir -p /usr/lib/prosody/modules/share/lua/5.4/mod_sasl_cyrus

sudo cp /tmp/prosody-modules/mod_auth_cyrus/sasl_cyrus.lua \
  /usr/lib/prosody/modules/share/lua/5.4/mod_sasl_cyrus/sasl_cyrus.lib.lua
```

Vérifier Lua Cyrus SASL :

```bash
lua5.4 -e 'require "cyrussasl"; print("cyrussasl OK")'
```

Résultat attendu :

```text
cyrussasl OK
```

---

## 8. Configurer Prosody pour Jitsi

Ouvrir le fichier Prosody de Jitsi :

```bash
sudo nano /etc/prosody/conf.d/meet.technova.local.cfg.lua
```

Selon l'installation, le fichier peut aussi être disponible via :

```bash
sudo nano /etc/prosody/conf.avail/meet.technova.local.cfg.lua
```

Dans le bloc principal, vérifier :

```lua
VirtualHost "meet.technova.local"
    authentication = "cyrus" -- do not delete me
    cyrus_application_name = "xmpp"
    allow_unencrypted_plain_auth = true
```

Ajouter ou conserver le bloc invité :

```lua
VirtualHost "guest.meet.technova.local"
    authentication = "jitsi-anonymous"
    c2s_require_encryption = false
```

Dans le composant MUC, conserver :

```lua
Component "conference.meet.technova.local" "muc"
    restrict_room_creation = true
```

Cette ligne permet d'avoir le comportement suivant :

```text
Utilisateurs AD authentifiés = peuvent créer une réunion
Invités anonymes = peuvent rejoindre une réunion existante
```

Vérifier Prosody :

```bash
sudo prosodyctl check config
```

Les warnings `cross_domain_bosh` ou `mod_posix deprecated` ne bloquent pas le fonctionnement.

---

## 9. Configurer l'accès invité côté Jitsi Web

Ouvrir :

```bash
sudo nano /etc/jitsi/meet/meet.technova.local-config.js
```

Chercher :

```javascript
hosts: {
```

Mettre :

```javascript
hosts: {
    domain: 'meet.technova.local',
    anonymousdomain: 'guest.meet.technova.local',
    muc: 'conference.meet.technova.local'
},
```

Point important :

```javascript
anonymousdomain: 'guest.meet.technova.local',
```

---

## 10. Configurer Jicofo

Ouvrir :

```bash
sudo nano /etc/jitsi/jicofo/jicofo.conf
```

Ajouter le bloc `authentication` dans `jicofo { ... }`.

Exemple :

```hocon
jicofo {
  authentication: {
    enabled: true
    type: XMPP
    login-url: "meet.technova.local"
  }

  xmpp: {
    client: {
      client-proxy: "focus.meet.technova.local"
      xmpp-domain: "meet.technova.local"
      domain: "auth.meet.technova.local"
      username: "focus"
      password: "MOT_DE_PASSE_FOCUS_EXISTANT"
    }
    trusted-domains: [ "recorder.meet.technova.local" ]
  }

  bridge: {
    brewery-jid: "JvbBrewery@internal.auth.meet.technova.local"
  }
}
```

Important :

```text
Ne pas changer le mot de passe focus.
Il est déjà généré par Jitsi.
Il faut seulement ajouter le bloc authentication.
```

---

## 11. Supprimer le module parasite ldapdb si l'erreur apparaît

Si la connexion Jitsi déconnecte automatiquement l'utilisateur avec :

```text
Vous avez été déconnecté.
Veuillez vérifier votre connexion réseau.
connection.otherError
no-auth-mech
```

et si les logs Prosody affichent :

```text
auxpropfunc error invalid parameter supplied
_sasl_plugin_load failed on sasl_auxprop_plug_init for plugin: ldapdb
ldapdb_canonuser_plug_init() failed
_sasl_plugin_load failed on sasl_canonuser_init for plugin: ldapdb
```

vérifier le paquet responsable :

```bash
dpkg -l | grep libsasl2-modules-ldap
```

Le paquet suivant peut provoquer le conflit :

```text
libsasl2-modules-ldap
```

Suppression :

```bash
sudo apt remove libsasl2-modules-ldap -y
```

Ce paquet n'est pas nécessaire ici, car l'authentification passe par :

```text
saslauthd -> LDAP
```

et non directement par le module `ldapdb`.

---

## 12. Redémarrer les services Jitsi

Commandes :

```bash
sudo systemctl restart saslauthd
sudo systemctl restart prosody
sudo systemctl restart jicofo
sudo systemctl restart jitsi-videobridge2
sudo systemctl restart nginx
```

Vérifier :

```bash
systemctl status saslauthd --no-pager
systemctl status prosody --no-pager
systemctl status jicofo --no-pager
systemctl status jitsi-videobridge2 --no-pager
systemctl status nginx --no-pager
```

---

## 13. Vérifier les logs Prosody

Commande :

```bash
sudo journalctl -u prosody -n 30 --no-pager
```

Avant correction, l'erreur suivante était présente :

```text
_sasl_plugin_load failed ... plugin: ldapdb
```

Après correction, l'erreur `ldapdb` ne doit plus apparaître.

Il ne faut pas non plus voir :

```text
Unable to load module 'auth_cyrus'
Failed to load plugin library 'sasl_cyrus'
```

---

## 14. Test final côté navigateur

Depuis l'interface Web Jitsi, ouvrir une salle :

```text
https://meet.technova.local/test-cyrus-ok
```

Se connecter avec le login court AD :

```text
Utilisateur : Administrateur
Mot de passe : mot de passe AD
```

Pour les autres utilisateurs :

```text
Alice.Smith
Jean.Dupont
```

Résultat attendu :

```text
La salle se crée.
L'utilisateur rejoint la réunion.
L'utilisateur authentifié devient modérateur.
```

Chaque utilisateur du domaine peut se connecter si :

```text
- le compte existe dans l'AD
- le compte n'est pas désactivé
- le mot de passe est correct
- le sAMAccountName correspond au login utilisé
```

---

## 15. Sauvegarder la configuration fonctionnelle

```bash
sudo cp /etc/prosody/conf.d/meet.technova.local.cfg.lua ~/prosody-jitsi-ad-ok.cfg.lua
sudo cp /etc/jitsi/jicofo/jicofo.conf ~/jicofo-ad-ok.conf
sudo cp /etc/saslauthd.conf ~/saslauthd-ad-ok.conf
sudo cp /etc/default/saslauthd ~/default-saslauthd-ok
sudo cp /etc/jitsi/meet/meet.technova.local-config.js ~/jitsi-web-ad-ok.js
sudo cp /etc/sasl/prosody.conf ~/prosody-sasl-ok.conf
sudo cp /etc/sasl2/xmpp.conf ~/xmpp-sasl-ok.conf
```

---

## 16. Solution finale retenue

Le problème a été résolu en configurant correctement la chaîne suivante :

```text
Jitsi Meet
   |
Prosody avec authentication = "cyrus"
   |
Cyrus SASL avec xmpp.conf
   |
saslauthd actif avec mécanisme LDAP
   |
Active Directory technova.local
```

Et en supprimant le module qui causait le conflit si celui-ci est installé :

```bash
sudo apt remove libsasl2-modules-ldap -y
```

Résultat final :

```text
Les utilisateurs du domaine Active Directory peuvent se connecter à Jitsi
avec leur identifiant AD court et créer des réunions.
```

Phrase pour le dossier TechNova :

```text
Jitsi Meet a été intégré à l'Active Directory TechNova afin de centraliser l'authentification des utilisateurs.

Le serveur Debian hébergeant Jitsi est joint au domaine technova.local.
Prosody utilise le module mod_auth_cyrus afin de déléguer l'authentification à Cyrus SASL.
saslauthd interroge ensuite l'Active Directory en LDAP avec l'attribut sAMAccountName.

Cette configuration permet à tous les utilisateurs AD valides de créer des réunions Jitsi avec leurs identifiants du domaine.
```
