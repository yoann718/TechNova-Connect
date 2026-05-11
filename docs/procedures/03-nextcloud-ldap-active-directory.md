# Procédure graphique — Joindre Nextcloud à l’Active Directory via LDAP

## 1. Accéder à l’intégration LDAP/AD

Se connecter à Nextcloud avec un compte administrateur.

Aller dans :

```text
Paramètres d’administration
→ Administration
→ LDAP/AD integration
```

Créer ou sélectionner la configuration LDAP :

```text
s01: 192.168.192.10
```

---

## 2. Onglet Serveur

Dans l’onglet **Serveur**, renseigner :

```text
Configuration active : activée

Hôte : 192.168.192.10
Port : 389

Utilisateur DN : Administrateur@technova.local
Mot de passe : mot de passe du compte Administrateur

DN de base : DC=technova,DC=local
```

Puis cliquer sur :

```text
Save credentials
```

Ensuite tester :

```text
Tester le DN de base
```

Résultat attendu :

```text
Le DN de base est valide.
Nextcloud peut contacter le serveur LDAP/AD.
```

---

## 3. Onglet Utilisateurs

Aller dans l’onglet **Utilisateurs**.

Dans :

```text
Seulement ces classes d’objets :
```

laisser :

```text
person
```

Dans :

```text
Seulement dans ces groupes :
```

laisser vide.

Cocher :

```text
Modifier la requête LDAP
```

Mettre exactement le filtre suivant :

```ldap
(&(objectCategory=person)(objectClass=user))
```

Puis cliquer sur :

```text
Vérifier les paramètres et compter les utilisateurs
```

Ensuite cliquer sur :

```text
Tester la configuration
```

Résultat attendu :

```text
Nextcloud trouve les utilisateurs Active Directory correspondant au filtre.
```

---

## 4. Onglet Attributs de connexion

Aller dans l’onglet **Attributs de connexion**.

Cocher :

```text
Nom d’utilisateur LDAP/AD
Adresse e-mail LDAP/AD
```

Dans :

```text
Autres attributs :
```

mettre :

```text
sAMAccountName
```

Laisser la requête LDAP générée comme suit :

```ldap
(&(&(objectCategory=person)(objectClass=user))(|(samaccountname=%uid)(mailPrimaryAddress=%uid)(mail=%uid)(sAMAccountName=%uid)))
```

Utilisation prévue :

```text
L’utilisateur peut se connecter avec son identifiant AD.
Exemple : Alice.Smith
```

Puis tester avec un utilisateur AD existant :

```text
Loginname de test : Alice.Smith
```

Cliquer sur :

```text
Tester les paramètres
```

Résultat attendu :

```text
Nextcloud trouve l’utilisateur AD correspondant au login testé.
```

---

## 5. Onglet Groupes

Aller dans l’onglet **Groupes**.

Dans :

```text
Seulement ces classes d’objets :
```

laisser :

```text
group
```

Dans :

```text
Seulement dans ces groupes :
```

laisser vide.

Cocher :

```text
Modifier la requête LDAP
```

Mettre exactement le filtre suivant :

```ldap
(&(objectClass=group)(|(cn=ITAdmins)(cn=RHTeam)(cn=VentesTeam)(cn=MarketingTeam)(cn=FinanceTeam)))
```

Ce filtre remonte uniquement les groupes AD suivants :

```text
ITAdmins
RHTeam
VentesTeam
MarketingTeam
FinanceTeam
```

Cliquer sur :

```text
Vérifier les paramètres et compter les groupes
```

Puis :

```text
Tester la configuration
```

Résultat attendu :

```text
Nextcloud trouve uniquement les groupes AD sélectionnés.
```

---

## 6. Onglet Avancé — Paramètres du dossier

Aller dans l’onglet **Avancé**.

Déplier :

```text
Paramètres du dossier
```

Configurer comme suit.

### Utilisateurs

```text
Champ « nom d’affichage » de l’utilisateur :
cn
```

```text
Second attribut pour le nom d’affichage :
laisser vide
```

```text
DN racine de l’arbre utilisateurs :
DC=technova,DC=local
```

```text
Attributs de recherche utilisateurs :
cn;sAMAccountName;displayName
```

Ne pas cocher :

```text
Désactiver les utilisateurs absents du LDAP
```

### Groupes

```text
Champ "nom d’affichage" du groupe :
cn
```

```text
DN racine de l’arbre groupes :
DC=technova,DC=local
```

```text
Attributs de recherche des groupes :
cn;sAMAccountName;displayName
```

```text
Association groupe-membre :
member (AD)
```

```text
Dynamic Group Member URL :
laisser vide
```

Ne pas cocher :

```text
Groupes imbriqués
```

```text
Paging chunksize :
500
```

Ne pas cocher :

```text
Activer la modification du mot de passe LDAP par l’utilisateur
```

```text
DN stratégie de mots de passe par défaut :
laisser vide
```

Cliquer ensuite sur :

```text
Tester la configuration
```

---

## 7. Validation finale

Une fois tous les onglets configurés, cliquer sur :

```text
Tester la configuration
```

Résultat attendu :

```text
La configuration LDAP est valide.
Nextcloud peut interroger l’Active Directory.
Les utilisateurs AD peuvent être trouvés.
Les groupes AD sélectionnés peuvent être remontés.
```

---

## 8. Test de connexion utilisateur

Depuis la page de connexion Nextcloud :

```text
URL : http://nextcloud.technova.local
```

Tester avec un compte AD :

```text
Utilisateur : Alice.Smith
Mot de passe : mot de passe AD de Alice.Smith
```

Résultat attendu :

```text
L’utilisateur AD se connecte à Nextcloud.
Le compte apparaît dans Nextcloud.
L’authentification utilise bien l’Active Directory.
```

---

## 9. Résultat obtenu

```text
Nextcloud est relié à l’Active Directory technova.local via LDAP.

Le serveur LDAP utilisé est :
192.168.192.10:389

La base LDAP utilisée est :
DC=technova,DC=local

Les utilisateurs remontés correspondent au filtre :
(&(objectCategory=person)(objectClass=user))

Les groupes remontés sont limités aux groupes :
ITAdmins
RHTeam
VentesTeam
MarketingTeam
FinanceTeam

L’identifiant de connexion principal repose sur :
sAMAccountName
```
