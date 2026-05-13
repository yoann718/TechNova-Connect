# TechNova Connect 

Ce dépôt regroupe les scripts et procédures nécessaires pour déployer le POC local TechNova Connect.

L'objectif est d'obtenir une installation reproductible avec :

- un contrôleur Active Directory Windows Server ;
- des serveurs Debian pour Nextcloud, Rocket.Chat et Jitsi Meet ;
- une VM Debian dédiée au reverse proxy HTTPS final ;
- un service n8n optionnel pour les automatisations du POC ;
- une résolution DNS interne en `technova.local` ;
- une base prête pour les intégrations LDAP/AD.

## Point de départ

Pour suivre l'installation complète pas à pas, lire d'abord :

[docs/ORDRE_INSTALLATION.md](docs/ORDRE_INSTALLATION.md)

## Architecture cible

| Serveur | OS | Rôle | IP |
|---|---|---|---|
| SRV-AD | Windows Server 2022 | AD DS / DNS / DHCP | 192.168.192.10 |
| SRV-NEXTCLOUD | Debian 13 | Nextcloud | 192.168.192.20 |
| SRV-CHAT | Debian 13 | Rocket.Chat | 192.168.192.30 |
| SRV-JITSI | Debian 13 | Jitsi Meet | 192.168.192.40 |
| SRV-N8N | Debian 13 | n8n optionnel | 192.168.192.50 |
| SRV-PROXY | Debian 13 | Nginx Proxy Manager / HTTPS | 192.168.192.15 |

## Organisation du dépôt

```text
technova-connect-poc-automatisation/
├── README.md
├── docs/
│   ├── ORDRE_INSTALLATION.md
│   ├── CHECKLIST_POC_LOCAL.md
│   ├── procedures/
│   │   └── README.md
│   └── incidents/
│       └── README.md
├── env/
│   ├── nextcloud.env
│   ├── rocketchat.env
│   ├── jitsi.env
│   └── n8n.env
└── scripts/
    ├── windows/
    └── linux/
```

## Scripts principaux

| Étape | Script |
|---|---|
| Création AD, DNS, DHCP, OU, groupes, utilisateurs | `scripts/windows/01-Creation_AD.ps1` |
| Ajout des mails utilisateurs AD | `scripts/windows/02-mailUtil.ps1` |
| DNS applicatif | `scripts/windows/03-DNS_Services.ps1` |
| IP fixe Debian | `scripts/linux/00-configure-static-ip.sh` |
| Installation Nextcloud | `scripts/linux/01-install-nextcloud.sh` |
| Installation Rocket.Chat | `scripts/linux/02-install-rocketchat.sh` |
| Installation Jitsi Meet | `scripts/linux/03-install-jitsi.sh` |
| Installation n8n optionnelle | `scripts/linux/04-install-n8n.sh` |

## Validation

La checklist de fin de POC est ici :

[docs/CHECKLIST_POC_LOCAL.md](docs/CHECKLIST_POC_LOCAL.md)

Les prérequis et le plan de tests sont documentés ici :

- [docs/CONFORMITE_PREREQUIS.md](docs/CONFORMITE_PREREQUIS.md)
- [docs/PLAN_TESTS_VALIDATION.md](docs/PLAN_TESTS_VALIDATION.md)

La phase finale de sécurisation HTTPS est documentée ici :

[docs/procedures/09-finalisation-https-reverse-proxy-authentification.md](docs/procedures/09-finalisation-https-reverse-proxy-authentification.md)
