# Plan de tests — Validation du POC TechNova Connect

## Objectif

Ce plan de tests permet de valider que l'infrastructure TechNova Connect fonctionne de bout en bout.

Il complète la checklist globale avec des tests observables, des commandes de contrôle et des résultats attendus.

---

## 1. Réseau et résolution DNS

| ID | Test | Commande | Résultat attendu |
|---|---|---|---|
| NET-01 | Vérifier la configuration IP de chaque VM | `ip a` ou `ipconfig` | IP conforme au plan d'adressage |
| NET-02 | Vérifier la passerelle Debian | `ip route` | Route par défaut vers `192.168.192.2` |
| NET-03 | Vérifier le DNS Debian | `resolvectl status` | DNS `192.168.192.10` |
| DNS-01 | Résoudre Nextcloud | `nslookup nextcloud.technova.local` | IP attendue selon la phase |
| DNS-02 | Résoudre Rocket.Chat | `nslookup rocket.technova.local` | IP attendue selon la phase |
| DNS-03 | Résoudre Jitsi | `nslookup meet.technova.local` | IP attendue selon la phase |

Après la phase finale HTTPS, les trois noms applicatifs doivent pointer vers :

```text
192.168.192.15
```

---

## 2. Active Directory

| ID | Test | Commande | Résultat attendu |
|---|---|---|---|
| AD-01 | Vérifier le domaine | `Get-ADDomain` | Domaine `technova.local` |
| AD-02 | Vérifier les utilisateurs | `Get-ADUser -Filter *` | Utilisateurs du POC présents |
| AD-03 | Vérifier les groupes | `Get-ADGroup -Filter *` | Groupes du POC présents |
| AD-04 | Vérifier les mails | `Get-ADUser -Filter * -Properties mail` | Attribut `mail` renseigné |
| AD-05 | Vérifier la jointure Debian | `realm list` | Domaine `technova.local` visible |

---

## 3. Nextcloud

| ID | Test | Commande ou action | Résultat attendu |
|---|---|---|---|
| NC-01 | Vérifier les conteneurs | `docker compose ps` | Conteneurs actifs |
| NC-02 | Accéder en HTTP interne avant proxy | `http://nextcloud.technova.local` | Interface accessible avant phase HTTPS |
| NC-03 | Accéder en HTTPS final | `https://nextcloud.technova.local` | Interface accessible, certificat reconnu |
| NC-04 | Vérifier le domaine de confiance | `occ config:system:get trusted_domains` | Domaine `nextcloud.technova.local` présent |
| NC-05 | Vérifier le proxy de confiance | `occ config:system:get trusted_proxies` | IP `192.168.192.15` présente |
| NC-06 | Tester un dépôt de fichier | Interface web | Upload fonctionnel |
| NC-07 | Tester l'authentification AD | Connexion utilisateur AD | Connexion réussie si LDAP configuré |

Commandes utiles :

```bash
cd /opt/nextcloud
docker compose ps
docker exec -u www-data -it nextcloud php occ config:system:get trusted_domains
docker exec -u www-data -it nextcloud php occ config:system:get trusted_proxies
docker exec -u www-data -it nextcloud php occ config:system:get overwriteprotocol
```

---

## 4. Rocket.Chat

| ID | Test | Commande ou action | Résultat attendu |
|---|---|---|---|
| RC-01 | Vérifier les conteneurs | `docker compose ps` | Rocket.Chat et MongoDB actifs |
| RC-02 | Vérifier `ROOT_URL` | `grep ROOT_URL .env` | `https://rocket.technova.local` |
| RC-03 | Accéder en HTTPS final | `https://rocket.technova.local` | Interface accessible, certificat reconnu |
| RC-04 | Tester WebSocket | Interface Rocket.Chat | Pas d'erreur de connexion temps réel |
| RC-05 | Créer un canal de test | Interface web | Canal créé |
| RC-06 | Envoyer un message | Interface web | Message visible |
| RC-07 | Tester l'authentification AD | Connexion utilisateur AD | Connexion réussie si LDAP configuré |

Commandes utiles :

```bash
cd /opt/rocketchat
docker compose ps
docker compose logs -f rocketchat
grep ROOT_URL .env
```

---

## 5. Jitsi Meet

| ID | Test | Commande ou action | Résultat attendu |
|---|---|---|---|
| JM-01 | Vérifier les services | `systemctl status` | Services actifs |
| JM-02 | Accéder en HTTPS final | `https://meet.technova.local` | Interface accessible, certificat reconnu |
| JM-03 | Vérifier WebRTC | `sudo ss -lunp \| grep 10000` | Port UDP `10000` en écoute |
| JM-04 | Tester SASL vers AD | `testsaslauthd` | `0: OK "Success."` |
| JM-05 | Créer une réunion avec un compte AD | Navigateur | Salle créée, utilisateur modérateur |
| JM-06 | Rejoindre comme invité | Navigateur avec lien | Invité rejoint la salle existante |
| JM-07 | Tester micro et caméra | Navigateur | Périphériques détectés |

Commandes utiles :

```bash
systemctl status prosody --no-pager
systemctl status jicofo --no-pager
systemctl status jitsi-videobridge2 --no-pager
sudo journalctl -u prosody -n 50 --no-pager
sudo ss -lunp | grep 10000
sudo /usr/sbin/testsaslauthd -u Administrateur -p 'MOT_DE_PASSE_AD' -s xmpp
```

---

## 6. Nginx Proxy Manager et HTTPS

| ID | Test | Commande ou action | Résultat attendu |
|---|---|---|---|
| NPM-01 | Accéder à l'interface NPM | `http://192.168.192.15:81` | Interface accessible |
| NPM-02 | Vérifier le conteneur | `docker compose ps` | Conteneur `nginx-proxy-manager` actif |
| NPM-03 | Tester HTTPS Nextcloud | `Test-NetConnection nextcloud.technova.local -Port 443` | `TcpTestSucceeded : True` |
| NPM-04 | Tester HTTPS Rocket.Chat | `Test-NetConnection rocket.technova.local -Port 443` | `TcpTestSucceeded : True` |
| NPM-05 | Tester HTTPS Jitsi | `Test-NetConnection meet.technova.local -Port 443` | `TcpTestSucceeded : True` |
| NPM-06 | Vérifier le certificat navigateur | Navigateur Windows | Certificat reconnu |
| NPM-07 | Vérifier les Proxy Hosts | Interface NPM | Nextcloud, Rocket.Chat et Jitsi actifs |

Commandes utiles :

```bash
cd /opt/nginx-proxy-manager
docker compose ps
docker compose logs -f
```

Depuis Windows :

```powershell
Test-NetConnection nextcloud.technova.local -Port 443
Test-NetConnection rocket.technova.local -Port 443
Test-NetConnection meet.technova.local -Port 443
```

---

## 7. Tests de bout en bout

| ID | Scénario | Résultat attendu |
|---|---|---|
| E2E-01 | Un utilisateur AD se connecte à Nextcloud | Accès aux fichiers |
| E2E-02 | Un utilisateur AD se connecte à Rocket.Chat | Accès au chat |
| E2E-03 | Un utilisateur AD crée une réunion Jitsi | Réunion créée |
| E2E-04 | Un second utilisateur rejoint la réunion | Connexion réussie |
| E2E-05 | Le navigateur affiche HTTPS sur les trois services | Certificat reconnu |
| E2E-06 | Les DNS applicatifs pointent vers SRV-PROXY | Résolution vers `192.168.192.15` |

---

## 8. Critères d'acceptation

Le POC est considéré comme validé si :

```text
- l'Active Directory est opérationnel ;
- les VM ont les IP prévues ;
- les services Nextcloud, Rocket.Chat et Jitsi sont accessibles ;
- les intégrations LDAP/AD fonctionnent ;
- les trois applications sont publiées en HTTPS ;
- le certificat interne est reconnu par Windows ;
- Jitsi permet la création de réunion aux utilisateurs AD ;
- les incidents connus sont documentés ;
- la checklist finale est complétée.
```

---

## 9. Résultat de validation

| Élément | Statut |
|---|---|
| Réseau | À valider |
| Active Directory | À valider |
| DNS | À valider |
| Nextcloud | À valider |
| Rocket.Chat | À valider |
| Jitsi Meet | À valider |
| HTTPS / Nginx Proxy Manager | À valider |
| Authentification AD | À valider |
| Documentation | À valider |

Conclusion attendue :

```text
Le POC TechNova Connect est validé.
Les services collaboratifs sont accessibles en HTTPS et intégrés à l'Active Directory.
```
