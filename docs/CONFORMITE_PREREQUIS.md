# Conformité des prérequis — POC TechNova Connect

## Objectif

Ce document sert à vérifier que tous les prérequis techniques sont réunis avant de lancer ou de présenter le POC TechNova Connect.

Il peut être utilisé comme feuille de contrôle avant publication, démonstration ou soutenance.

---

## 1. Environnement de virtualisation

| Contrôle | Attendu | Statut |
|---|---|---|
| Hyperviseur disponible | VMware Workstation | À valider |
| Réseau isolé du POC | VMnet dédié | À valider |
| Plage réseau | `192.168.192.0/24` | À valider |
| Passerelle | `192.168.192.2` | À valider |
| DHCP VMware | Désactivé si DHCP fourni par Windows Server | À valider |
| Communication inter-VM | Toutes les VM se joignent par IP | À valider |

---

## 2. Inventaire des serveurs

| Serveur | Rôle | IP attendue | DNS attendu | Statut |
|---|---|---:|---|---|
| SRV-AD | AD DS / DNS / DHCP | `192.168.192.10` | `srv-ad.technova.local` | À valider |
| SRV-PROXY | Nginx Proxy Manager / HTTPS | `192.168.192.15` | `proxy.technova.local` | À valider |
| SRV-NEXTCLOUD | Nextcloud | `192.168.192.20` | `nextcloud.technova.local` | À valider |
| SRV-CHAT | Rocket.Chat | `192.168.192.30` | `rocket.technova.local` | À valider |
| SRV-JITSI | Jitsi Meet | `192.168.192.40` | `meet.technova.local` | À valider |
| SRV-N8N | n8n optionnel | `192.168.192.50` | `n8n.technova.local` | Optionnel |

---

## 3. Active Directory

| Contrôle | Attendu | Statut |
|---|---|---|
| Domaine AD | `technova.local` | À valider |
| Contrôleur de domaine | SRV-AD | À valider |
| DNS interne | `192.168.192.10` | À valider |
| DHCP | Activé si utilisé dans le lab | À valider |
| OU | Créées par le script AD | À valider |
| Groupes | Créés par le script AD | À valider |
| Utilisateurs | Créés par le script AD | À valider |
| Attribut mail | Renseigné pour les utilisateurs | À valider |

Commandes de contrôle :

```powershell
Get-ADDomain
Get-ADUser -Filter * -Properties mail | Select-Object Name,SamAccountName,mail
Resolve-DnsName nextcloud.technova.local
Resolve-DnsName rocket.technova.local
Resolve-DnsName meet.technova.local
```

---

## 4. DNS applicatif

Avant la phase HTTPS finale :

| Nom DNS | IP attendue |
|---|---:|
| `nextcloud.technova.local` | `192.168.192.20` |
| `rocket.technova.local` | `192.168.192.30` |
| `meet.technova.local` | `192.168.192.40` |

Après la phase HTTPS finale :

| Nom DNS | IP attendue |
|---|---:|
| `nextcloud.technova.local` | `192.168.192.15` |
| `rocket.technova.local` | `192.168.192.15` |
| `meet.technova.local` | `192.168.192.15` |

Commande de contrôle :

```powershell
ipconfig /flushdns
nslookup nextcloud.technova.local
nslookup rocket.technova.local
nslookup meet.technova.local
```

---

## 5. Prérequis Debian

| Contrôle | Attendu | Statut |
|---|---|---|
| IP fixe | Configurée sur chaque serveur | À valider |
| DNS Debian | `192.168.192.10` | À valider |
| Résolution du domaine | `technova.local` résolu | À valider |
| Accès Internet ou miroir local | `apt update` fonctionne | À valider |
| Jointure AD | Serveurs Debian joints si nécessaire | À valider |

Commandes de contrôle :

```bash
ip a
ip route
resolvectl status
realm list
ping -c 4 srv-ad.technova.local
```

---

## 6. Services applicatifs

| Service | Contrôle attendu | Statut |
|---|---|---|
| Nextcloud | Conteneurs actifs, interface accessible | À valider |
| Rocket.Chat | Conteneurs actifs, interface accessible | À valider |
| Jitsi Meet | Services actifs, interface accessible | À valider |
| n8n | Service accessible si retenu | Optionnel |

Commandes de contrôle :

```bash
docker compose ps
systemctl status prosody --no-pager
systemctl status jicofo --no-pager
systemctl status jitsi-videobridge2 --no-pager
```

---

## 7. Reverse proxy et HTTPS

| Contrôle | Attendu | Statut |
|---|---|---|
| Nginx Proxy Manager | Accessible sur `http://192.168.192.15:81` | À valider |
| Certificat interne | `technova-local` importé dans NPM | À valider |
| Certificat Windows | `technova.local.crt` installé dans les autorités racines | À valider |
| Proxy Host Nextcloud | `https://nextcloud.technova.local` | À valider |
| Proxy Host Rocket.Chat | `https://rocket.technova.local` | À valider |
| Proxy Host Jitsi | `https://meet.technova.local` | À valider |
| WebSockets Rocket.Chat | Activés dans NPM | À valider |
| WebSockets Jitsi | Activés dans NPM | À valider |

Commandes de contrôle :

```powershell
Test-NetConnection nextcloud.technova.local -Port 443
Test-NetConnection rocket.technova.local -Port 443
Test-NetConnection meet.technova.local -Port 443
```

---

## 8. Authentification et annuaire

| Service | Intégration attendue | Statut |
|---|---|---|
| Nextcloud | LDAP/AD configuré via l'interface graphique | À valider |
| Rocket.Chat | LDAP/AD, groupes et canaux configurés | À valider |
| Jitsi Meet | Création de réunion réservée aux utilisateurs AD | À valider |

Test Jitsi :

```bash
sudo /usr/sbin/testsaslauthd -u Administrateur -p 'MOT_DE_PASSE_AD' -s xmpp
```

Résultat attendu :

```text
0: OK "Success."
```

---

## 9. Sécurité et hygiène du dépôt

| Contrôle | Attendu | Statut |
|---|---|---|
| Mots de passe réels | Absents ou remplacés par des valeurs de lab | À valider |
| Clés privées | Aucune clé privée publiée | À valider |
| Certificats privés | Aucun fichier `.key` versionné | À valider |
| Valeurs `CHANGE_ME` | Remplacées avant déploiement réel | À valider |
| Procédures | Rangées dans `docs/procedures/` | À valider |
| Incidents | Rangés dans `docs/incidents/` | À valider |
| Fichiers temporaires | Absents de la racine | À valider |

À vérifier avant publication GitHub :

```text
- ne pas publier technova.local.key ;
- ne pas publier de mot de passe de production ;
- conserver les mots de passe de lab uniquement si le contexte pédagogique est clair ;
- ajouter des captures d'écran seulement si elles ne révèlent pas de secret.
```

---

## 10. Verdict de conformité

| Élément | Résultat |
|---|---|
| Infrastructure prête | À valider |
| Services installés | À valider |
| AD fonctionnel | À valider |
| HTTPS final fonctionnel | À valider |
| Tests réalisés | À valider |
| Publication GitHub possible | À valider |

Conclusion attendue :

```text
Le POC TechNova Connect respecte les prérequis techniques définis.
L'infrastructure est reproductible, documentée et prête pour démonstration.
```
