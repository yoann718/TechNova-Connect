# Procédures

Les procédures sont numérotées selon l'ordre logique du POC.

| Ordre | Procédure | Usage |
|---:|---|---|
| 01 | [Jointure Debian Active Directory](01-jointure-debian-active-directory.md) | Joindre les serveurs Debian au domaine `technova.local` |
| 02 | [Installation Nextcloud manuelle](02-installation-nextcloud-manuelle.md) | Installer Nextcloud sans script pour comprendre ou dépanner |
| 03 | [LDAP Nextcloud Active Directory](03-nextcloud-ldap-active-directory.md) | Configurer l'authentification AD dans Nextcloud via l'interface graphique |
| 04 | [Installation Rocket.Chat automatisée](04-installation-rocketchat-automatisee.md) | Installer Rocket.Chat avec le script Bash |
| 05 | [Installation Rocket.Chat manuelle](05-installation-rocketchat-manuelle.md) | Installer Rocket.Chat sans script pour comprendre ou dépanner |
| 06 | [Rocket.Chat LDAP groupes canaux](06-rocketchat-ldap-groupes-canaux.md) | Synchroniser utilisateurs, groupes et canaux Rocket.Chat via l'interface graphique |
| 07 | [Installation Jitsi manuelle](07-installation-jitsi-manuelle.md) | Installer Jitsi sans script |
| 08 | [Authentification Jitsi avec Active Directory](08-jitsi-active-directory.md) | Connecter Jitsi à l'AD via Prosody, Cyrus SASL et saslauthd |
| 09 | [Finalisation HTTPS et authentification AD](09-finalisation-https-reverse-proxy-authentification.md) | Publier Nextcloud, Rocket.Chat et Jitsi en HTTPS via Nginx Proxy Manager |

Le fil conducteur global est dans :

[../ORDRE_INSTALLATION.md](../ORDRE_INSTALLATION.md)
