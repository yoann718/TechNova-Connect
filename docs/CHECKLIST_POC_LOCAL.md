# Checklist POC local TechNova

## Infrastructure

- [ ] Les VM sont créées dans VMware Workstation,
- [ ] Les VM sont sur le même réseau VMnet
- [ ] Le réseau utilisé est `192.168.192.0/24`
- [ ] La passerelle est `192.168.192.2`
- [ ] Les serveurs ont des IP fixes
- [ ] Les serveurs communiquent entre eux

## Active Directory

- [ ] SRV-AD a l'IP `192.168.192.10`
- [ ] Le domaine `technova.local` existe
- [ ] Le rôle DNS fonctionne
- [ ] Le rôle DHCP fonctionne
- [ ] Les OU sont créées
- [ ] Les groupes sont créés
- [ ] Les utilisateurs sont créés
- [ ] Les mails utilisateurs sont renseignés

## DNS applicatif

- [ ] `nextcloud.technova.local` résout vers `192.168.192.20`
- [ ] `rocket.technova.local` résout vers `192.168.192.30`
- [ ] `meet.technova.local` résout vers `192.168.192.40`
- [ ] `n8n.technova.local` résout vers `192.168.192.50` si n8n est installé

## DNS final HTTPS

- [ ] `nextcloud.technova.local` résout vers `192.168.192.15`
- [ ] `rocket.technova.local` résout vers `192.168.192.15`
- [ ] `meet.technova.local` résout vers `192.168.192.15`
- [ ] Les vraies IP applicatives restent utilisées comme backends dans Nginx Proxy Manager

## Nextcloud

- [ ] Le conteneur Nextcloud est actif
- [ ] La base MariaDB est active
- [ ] Redis est actif
- [ ] L'interface web est accessible
- [ ] Le compte admin fonctionne
- [ ] Un fichier peut être déposé

## Rocket.Chat

- [ ] Le conteneur Rocket.Chat est actif
- [ ] MongoDB est actif
- [ ] L'interface web est accessible
- [ ] Le compte admin fonctionne
- [ ] Un canal de test peut être créé
- [ ] Un message peut être envoyé

## Jitsi Meet

- [ ] Le service web répond
- [ ] L'interface est accessible
- [ ] Une salle peut être créée
- [ ] L'accès final se fait en HTTPS via `https://meet.technova.local`
- [ ] Les utilisateurs AD peuvent créer une réunion
- [ ] Les invités peuvent rejoindre une réunion existante avec un lien
- [ ] Le port UDP `10000` est disponible vers SRV-JITSI

## Reverse proxy HTTPS

- [ ] SRV-PROXY a l'IP `192.168.192.15`
- [ ] Nginx Proxy Manager est actif
- [ ] Le certificat `technova-local` est importé dans NPM
- [ ] Le certificat `technova.local.crt` est installé dans Windows
- [ ] `https://nextcloud.technova.local` fonctionne
- [ ] `https://rocket.technova.local` fonctionne
- [ ] `https://meet.technova.local` fonctionne
- [ ] Rocket.Chat utilise `ROOT_URL="https://rocket.technova.local"`

## n8n optionnel

- [ ] Le service n8n est accessible si retenu dans le POC
- [ ] Le compte admin fonctionne si n8n est installé
- [ ] Un workflow manuel peut être créé si n8n est installé
- [ ] Le workflow teste au moins un service interne si n8n est installé

## Validation POC

- [ ] Le POC est démontrable
- [ ] Les limites sont connues
- [ ] Les étapes LDAP sont prêtes
- [ ] Les accès HTTPS/proxy sont validés
