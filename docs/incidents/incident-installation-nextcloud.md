# POC — Incident d'installation Nextcloud

## 1. Contexte

Dans le cadre du POC TechNova, le service Nextcloud devait être installé sur le serveur Debian suivant :

```text
Serveur : SRV-NEXTCLOUD
Adresse IP : 192.168.192.20
Nom DNS : nextcloud.technova.local
Service : Nextcloud
Mode d'installation : Docker Compose
Composants : Nextcloud + MariaDB + Redis
```

L'objectif était d'automatiser l'installation à l'aide d'un script Bash et d'un fichier `.env`.

---

## 2. Problème rencontré

Après l'exécution du script d'installation, l'interface web Nextcloud affichait encore la page de création du compte administrateur.

Lors d'une tentative d'installation depuis l'interface web, Nextcloud a retourné une erreur indiquant qu'une table existait déjà :

```text
oc_authtoken already exists
```

Ensuite, la commande de contrôle suivante a été exécutée :

```bash
docker exec -it nextcloud php occ status
```

Elle a retourné une erreur PHP indiquant qu'un fichier essentiel était absent :

```text
/var/www/html/version.php
No such file or directory
```

---

## 3. Diagnostic

L'erreur montre que le conteneur Nextcloud était démarré, mais que le volume Docker contenant les fichiers applicatifs était incomplet.

Le fichier suivant était absent :

```text
/var/www/html/version.php
```

Cela signifie que l'initialisation du volume `nextcloud_data` ne s'est pas terminée correctement.

En parallèle, la base MariaDB avait commencé à créer certaines tables Nextcloud. Cela explique l'erreur :

```text
oc_authtoken already exists
```

La situation était donc la suivante :

```text
Conteneur Nextcloud démarré
Base MariaDB partiellement initialisée
Volume Nextcloud incomplet
Installation applicative non finalisée
```

---

## 4. Cause probable

La cause la plus probable est une initialisation partielle du conteneur Nextcloud lors du premier démarrage.

Le script initial lançait les conteneurs, mais ne contrôlait pas suffisamment :

```text
la création complète des fichiers Nextcloud ;
la présence du fichier version.php ;
l'état réel de l'installation via occ ;
la cohérence entre le volume Nextcloud et la base MariaDB.
```

Le script automatisait donc le déploiement Docker, mais pas assez la validation de l'installation applicative.

---

## 5. Correction appliquée

La correction a consisté à supprimer les volumes Docker liés à l'installation incomplète, puis à relancer proprement les conteneurs.

Commandes utilisées :

```bash
cd /opt/nextcloud
docker compose down -v
docker compose pull
docker compose up -d
```

Puis vérification :

```bash
docker exec -it nextcloud ls -l /var/www/html/version.php
docker exec -u www-data -it nextcloud php occ status
```

Après la relance propre, le service Nextcloud est devenu fonctionnel.

---

## 6. Résultat obtenu

Nextcloud est maintenant accessible :

```text
http://nextcloud.technova.local
```

ou :

```text
http://192.168.192.20
```

Compte administrateur local :

```text
Utilisateur : admin
Mot de passe : défini dans le fichier .env
```

La commande de validation attendue est :

```bash
docker exec -u www-data -it nextcloud php occ status
```

Résultat attendu :

```text
installed: true
```

---

## 7. Amélioration du script

Le script initial a été amélioré afin de :

```text
vérifier la présence du fichier /var/www/html/version.php ;
détecter un volume Nextcloud incomplet ;
nettoyer automatiquement les volumes en mode POC si besoin ;
relancer les conteneurs proprement ;
attendre que la commande occ soit disponible ;
afficher l'état final de l'installation.
```

Une variable optionnelle peut être ajoutée au fichier `.env` :

```env
POC_RESET="true"
```

Elle permet de forcer un redéploiement propre pendant les tests.

---

## 8. Conclusion POC

L'incident n'invalide pas le choix technique Nextcloud.

Il montre plutôt une limite du premier script d'automatisation : le script lançait les conteneurs, mais ne contrôlait pas assez l'état applicatif final.

Après correction, le déploiement Nextcloud est validé pour le POC.

Pour une intégration finale, il faudra prévoir :

```text
une gestion plus propre des secrets ;
du HTTPS ;
une sauvegarde de la base et des volumes ;
une intégration LDAP/AD ;
une procédure de supervision ;
une documentation de restauration.
```
