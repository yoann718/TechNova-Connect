# Procédure graphique — Configuration LDAP Rocket.Chat avec Active Directory

## Objectif

Configurer Rocket.Chat pour :

```text
- authentifier les utilisateurs Active Directory ;
- rechercher les utilisateurs AD ;
- synchroniser les données utilisateurs ;
- mapper les groupes AD vers des équipes Rocket.Chat ;
- synchroniser les groupes AD vers des canaux Rocket.Chat.
```

Environnement utilisé :

```text
Domaine AD        : technova.local
Contrôleur AD     : 192.168.192.10
Port LDAP         : 389
Base DN           : DC=technova,DC=local
Rocket.Chat URL   : http://rocket.technova.local:3000
```

Groupes AD utilisés :

```text
ITAdmins
RHTeam
VentesTeam
MarketingTeam
FinanceTeam
```

Canaux Rocket.Chat créés :

```text
#it-admins
#rh
#ventes
#marketing
#finance
```

---

## 1. Accéder à la configuration LDAP

Dans Rocket.Chat, se connecter avec un compte administrateur.

Aller dans :

```text
Administration
→ Paramètres
→ LDAP
```

La configuration se fait dans les onglets suivants :

```text
Connexion
Recherche utilisateur
Synchronisation de données
Enterprise
```

---

## 2. Onglet Connexion

### Activer LDAP

Activer l’option :

```text
Activer : activé
```

### Type de serveur

Sélectionner :

```text
Type de serveur : Active Directory
```

### Hôte LDAP

Renseigner :

```text
Hôte : 192.168.192.10
```

### Port LDAP

Renseigner :

```text
Port : 389
```

### Reconnexion

Activer :

```text
Reconnexion : activé
```

---

## 3. Authentification LDAP

Dans la section **Authentification**, activer :

```text
Activer : activé
```

Renseigner le compte de liaison LDAP :

```text
DN utilisateur : Administrateur@technova.local
Mot de passe   : mot de passe du compte Administrateur
```

Ce compte sert à interroger l’annuaire Active Directory.

Pour un environnement de production, il est préférable d’utiliser un compte de service dédié, par exemple :

```text
svc_rocketchat_ldap@technova.local
```

---

## 4. Onglet Recherche utilisateur

Aller dans :

```text
LDAP
→ Recherche utilisateur
```

### Trouver un utilisateur après la connexion

Activer :

```text
Trouver un utilisateur après la connexion : activé
```

Cette option permet à Rocket.Chat de rechercher le DN LDAP de l’utilisateur après son authentification.

### Filtre de recherche

Dans la section **Filtre de recherche**, renseigner :

```text
DN de base : DC=technova,DC=local
```

Filtre LDAP :

```ldap
(&(objectCategory=person)(objectClass=user))
```

Périmètre :

```text
sub
```

Champ de recherche :

```text
sAMAccountName
```

Résultat attendu :

```text
Rocket.Chat recherche les utilisateurs Active Directory dans tout le domaine technova.local.
Les comptes utilisateurs AD sont identifiés via l’attribut sAMAccountName.
```

---

## 5. Filtre de groupe utilisateur LDAP

Dans la section **Filtre de groupe**, laisser désactivé :

```text
Activer le filtre de groupe d'utilisateurs LDAP : désactivé
```

Dans cette configuration, l’accès LDAP n’est pas limité à un seul groupe AD.

Les champs visibles peuvent rester avec leurs valeurs par défaut :

```text
ObjectClass du groupe : groupOfUniqueNames
Attribut d'ID de groupe : cn
Attribut de membre de groupe : uniqueMember
```

Comme le filtre de groupe est désactivé, ces valeurs ne bloquent pas l’authentification.

---

## 6. Onglet Synchronisation de données

Aller dans :

```text
LDAP
→ Synchronisation de données
```

### Mappage des attributs

Configurer les champs suivants :

```text
Champ de nom d'utilisateur : sAMAccountName
Champ d'adresse e-mail    : mail
Champ de nom              : cn
Extension Field           : laisser vide
```

Résultat attendu :

```text
L’identifiant Rocket.Chat est basé sur sAMAccountName.
L’adresse mail est récupérée depuis l’attribut mail.
Le nom affiché est récupéré depuis cn.
```

Exemple :

```text
AD sAMAccountName : Alice.Smith
AD mail           : alice.smith@technova.local
AD cn             : Alice Smith

Rocket.Chat username : Alice.Smith
Rocket.Chat email    : alice.smith@technova.local
Rocket.Chat name     : Alice Smith
```

---

## 7. Onglet Enterprise — Synchroniser les équipes

Aller dans :

```text
LDAP
→ Enterprise
→ Synchroniser les équipes
```

### Activer le mappage d’équipes

Activer :

```text
Activer le mappage d'équipes de LDAP vers Rocket.Chat : activé
```

### Mappage d’équipe LDAP vers Rocket.Chat

Renseigner le mapping suivant :

```json
{
  "ITAdmins": "ITAdmins",
  "RHTeam": "RHTeam",
  "VentesTeam": "VentesTeam",
  "MarketingTeam": "MarketingTeam",
  "FinanceTeam": "FinanceTeam"
}
```

Ce mapping signifie :

```text
Groupe AD ITAdmins       → Équipe Rocket.Chat ITAdmins
Groupe AD RHTeam         → Équipe Rocket.Chat RHTeam
Groupe AD VentesTeam     → Équipe Rocket.Chat VentesTeam
Groupe AD MarketingTeam  → Équipe Rocket.Chat MarketingTeam
Groupe AD FinanceTeam    → Équipe Rocket.Chat FinanceTeam
```

### Valider le mappage à chaque connexion

Activer :

```text
Valider le mappage pour chaque connexion : activé
```

### DN de base des équipes LDAP

Renseigner :

```text
DC=technova,DC=local
```

### Attribut de nom d’équipe LDAP

Renseigner :

```text
cn
```

### Requête LDAP pour récupérer les groupes d’utilisateurs

Renseigner :

```ldap
(&(objectClass=group)(member=#{userdn}))
```

Résultat attendu :

```text
Rocket.Chat vérifie les groupes AD auxquels appartient l’utilisateur connecté.
Si l’utilisateur appartient à un groupe mappé, il est associé à l’équipe Rocket.Chat correspondante.
```

---

## 8. Onglet Enterprise — Synchronisation avancée

Aller dans :

```text
LDAP
→ Enterprise
→ Synchronisation avancée
```

### Synchroniser l’état actif de l’utilisateur

Configurer :

```text
Synchroniser l’état actif de l’utilisateur : Désactiver les utilisateurs
```

Cela permet à Rocket.Chat de désactiver les utilisateurs si leur compte est désactivé dans l’annuaire.

### Attributs à interroger

Renseigner :

```text
*,+
```

Explication :

```text
*  : récupère les attributs LDAP standards
+  : récupère les attributs LDAP opérationnels
```

---

## 9. Onglet Enterprise — Synchroniser les canaux

Aller dans :

```text
LDAP
→ Enterprise
→ Synchroniser les canaux
```

### Activer la synchronisation automatique

Activer :

```text
Synchronisation automatique des groupes LDAP avec les canaux : activé
```

Cette option permet d’ajouter automatiquement les utilisateurs aux canaux Rocket.Chat selon leurs groupes AD.

### Administrateur de canaux

Renseigner le compte administrateur Rocket.Chat :

```text
Administrateur de canaux : admin
```

ou le compte réellement utilisé dans l’environnement.

Ce compte devient administrateur des canaux créés automatiquement.

### Nom de base du groupe LDAP

Renseigner :

```text
DC=technova,DC=local
```

### Group membership validation strategy

Sélectionner :

```text
Apply filter for each group
```

Cette stratégie vérifie l’appartenance de l’utilisateur à chaque groupe mappé.

### Filtre de groupe d’utilisateurs

Renseigner le filtre Active Directory suivant :

```ldap
(&(objectClass=group)(cn=#{groupName})(member=#{userdn}))
```

Explication :

```text
#{groupName} : nom du groupe AD défini dans le mapping
#{userdn}    : DN LDAP complet de l’utilisateur connecté
member       : attribut AD contenant les membres du groupe
```

### Mappage de canaux et de groupes LDAP

Renseigner le mapping suivant :

```json
{
  "ITAdmins": "it-admins",
  "RHTeam": "rh",
  "VentesTeam": "ventes",
  "MarketingTeam": "marketing",
  "FinanceTeam": "finance"
}
```

Ce mapping signifie :

```text
Groupe AD ITAdmins       → canal Rocket.Chat #it-admins
Groupe AD RHTeam         → canal Rocket.Chat #rh
Groupe AD VentesTeam     → canal Rocket.Chat #ventes
Groupe AD MarketingTeam  → canal Rocket.Chat #marketing
Groupe AD FinanceTeam    → canal Rocket.Chat #finance
```

---

## 10. Sauvegarder et synchroniser

Après configuration, sauvegarder les modifications.

Puis cliquer sur :

```text
Synchroniser maintenant
```

depuis le haut de la page LDAP.

---

## 11. Vérifier la synchronisation

Aller dans :

```text
Administration
→ Salons
```

Résultat attendu :

```text
#finance
#it-admins
#marketing
#rh
#ventes
```

Chaque canal doit contenir les utilisateurs correspondant aux groupes AD.

---

## 12. Test utilisateur

Tester avec un utilisateur AD membre d’un groupe, par exemple :

```text
Utilisateur AD : Alice.Smith
Groupe AD      : ITAdmins
```

Résultat attendu :

```text
Alice.Smith peut se connecter à Rocket.Chat.
Alice.Smith est automatiquement ajoutée au canal #it-admins.
```

Autres exemples :

```text
Utilisateur membre de RHTeam         → accès au canal #rh
Utilisateur membre de VentesTeam     → accès au canal #ventes
Utilisateur membre de MarketingTeam  → accès au canal #marketing
Utilisateur membre de FinanceTeam    → accès au canal #finance
```

---

## 13. Résultat final

```text
Rocket.Chat est intégré à l’Active Directory technova.local via LDAP.

Les utilisateurs Active Directory peuvent se connecter à Rocket.Chat avec leur compte AD.

Les attributs utilisateurs sont récupérés depuis l’AD :
- sAMAccountName pour le nom d’utilisateur ;
- mail pour l’adresse e-mail ;
- cn pour le nom affiché.

Les groupes Active Directory sont synchronisés vers Rocket.Chat.

Les groupes AD sont mappés vers des équipes Rocket.Chat et vers des canaux de discussion.

Les canaux créés automatiquement sont :
- #it-admins
- #rh
- #ventes
- #marketing
- #finance
```

---

## 14. Commandes utiles pour diagnostic

Depuis le serveur Rocket.Chat :

```bash
cd /opt/rocketchat
docker compose logs -f rocketchat
```

Vérifier les conteneurs :

```bash
cd /opt/rocketchat
docker compose ps
```

Redémarrer Rocket.Chat :

```bash
cd /opt/rocketchat
docker compose restart rocketchat
```

Tester LDAP depuis Debian :

```bash
ldapsearch -x \
  -H ldap://192.168.192.10:389 \
  -D "Administrateur@technova.local" \
  -W \
  -b "DC=technova,DC=local" \
  "(sAMAccountName=Alice.Smith)"
```

Tester les groupes AD d’un utilisateur :

```bash
ldapsearch -x \
  -H ldap://192.168.192.10:389 \
  -D "Administrateur@technova.local" \
  -W \
  -b "DC=technova,DC=local" \
  "(&(objectClass=group)(member=CN=Alice Smith,OU=IT,DC=technova,DC=local))" cn
```
