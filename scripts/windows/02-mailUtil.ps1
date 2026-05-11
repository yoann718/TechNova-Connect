# Import du module Active Directory (si ce n'est pas déjà fait)
Import-Module ActiveDirectory

# Récupérer les utilisateurs Active Directory (hors comptes système)
$users = Get-ADUser -Filter {
    SamAccountName -ne "Administrator" -and
    SamAccountName -ne "Administrateur" -and
    SamAccountName -ne "krbtgt" -and
    SamAccountName -ne "Invité" -and
    SamAccountName -ne "Guest"
} -Property SamAccountName, EmailAddress

foreach ($user in $users) {
    # Générer l'adresse e-mail à partir du login
    $email = "$($user.SamAccountName)@technova.local"

    # Mise à jour du champ EmailAddress si ce n'est pas déjà fait
    if ($user.EmailAddress -ne $email) {
        Set-ADUser -Identity $user -EmailAddress $email
        Write-Host "Email mis à jour pour l'utilisateur $($user.SamAccountName): $email"
    } else {
        Write-Host "Email déjà correct pour l'utilisateur $($user.SamAccountName)"
    }
}
