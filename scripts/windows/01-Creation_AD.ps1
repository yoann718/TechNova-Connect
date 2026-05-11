Set-ExecutionPolicy RemoteSigned -Scope Process -Force
# Fonction pour installer un rôle si nécessaire
function Install-WindowsFeatureIfNeeded {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FeatureName,
        [string]$DisplayName = $FeatureName,
        [switch]$IncludeManagementTools
    )
    if (-not (Get-WindowsFeature -Name $FeatureName).Installed) {
        if ($IncludeManagementTools) {
            Install-WindowsFeature -Name $FeatureName -IncludeManagementTools -ErrorAction Stop
        }
        else {
            Install-WindowsFeature -Name $FeatureName -ErrorAction Stop
        }
        Write-Host "$DisplayName installé(e)."
    }
    else {
        Write-Host "$DisplayName déjà installé(e)."
    }
}

# Fonction pour créer une OU si elle n'existe pas
function New-ADOrganizationalUnitIfNeeded {
    param (
        [Parameter(Mandatory=$true)]
        [string]$OUName,
        [Parameter(Mandatory=$true)]
        [string]$DomainDN
    )
    $OUPath = "OU=$OUName,$DomainDN"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OUPath'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $OUName -Path $DomainDN -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
        Write-Host "OU créée: $OUName"
    }
    else {
        Write-Host "OU existante: $OUName"
    }
}

# Fonction pour créer un groupe si il n'existe pas
function Test-ADGroup {
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [string]$OUPath
    )
    if (-not (Get-ADGroup -Filter "Name -eq '$GroupName'" -SearchBase $OUPath -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $GroupName -GroupScope Global -Description $Description -Path $OUPath -ErrorAction Stop
        Write-Host "Groupe créé: $GroupName dans $OUPath."
    }
    else {
        Write-Host "Groupe existant: $GroupName dans $OUPath."
    }
}

# Fonction pour créer un utilisateur et l'ajouter à un groupe
function New-ADUserIfNeeded {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FirstName,
        [Parameter(Mandatory=$true)]
        [string]$LastName,
        [Parameter(Mandatory=$true)]
        [string]$Department,
        [Parameter(Mandatory=$true)]
        [string]$GroupName,
        [Parameter(Mandatory=$true)]
        [string]$DomainName,
        [Parameter(Mandatory=$true)]
        [string]$DomainDN,
        [Parameter(Mandatory=$true)]
        [System.Security.SecureString]$DefaultPassword
    )
    $SamAccountName = "$FirstName.$LastName"
    $UserOUPath = "OU=$Department,$DomainDN"
    $Password = $DefaultPassword

    if (-not (Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue)) {
        New-ADUser -GivenName $FirstName -Surname $LastName `
                   -Name "$FirstName $LastName" `
                   -SamAccountName $SamAccountName `
                   -UserPrincipalName "$SamAccountName@$DomainName" `
                   -Path $UserOUPath `
                   -AccountPassword $Password `
                   -Enabled $true -ErrorAction Stop
        Write-Host "Utilisateur créé: $SamAccountName dans $Department."
    }
    else {
        Write-Host "Utilisateur existant: $SamAccountName dans $Department."
    }

    # Vérifier et ajouter l'utilisateur au groupe s'il n'y est pas déjà
    $CreatedUser = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue
    if ($CreatedUser) {
        if (-not (Get-ADGroupMember -Identity $GroupName | Where-Object { $_.SamAccountName -eq $SamAccountName })) {
            Add-ADGroupMember -Identity $GroupName -Members $SamAccountName -ErrorAction Stop
            Write-Host "Utilisateur $SamAccountName ajouté au groupe $GroupName."
        }
        else {
            Write-Host "Utilisateur $SamAccountName déjà dans le groupe $GroupName."
        }
    }
    else {
        Write-Host "Erreur: Utilisateur $SamAccountName non trouvé après création."
    }
}

# ------------------------ DÉBUT DU SCRIPT ------------------------

# Vérifier et installer les rôles et outils nécessaires
Install-WindowsFeatureIfNeeded -FeatureName "AD-Domain-Services" -DisplayName "Rôle AD DS" -IncludeManagementTools
Import-Module ActiveDirectory

# Supprimer la tâche planifiée si elle existe
if (Get-ScheduledTask -TaskName "Resume_AD_Creation" -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName "Resume_AD_Creation" -Confirm:$false
}

Install-WindowsFeatureIfNeeded -FeatureName "RSAT-AD-Tools" -DisplayName "Outils RSAT pour AD"

# Vérifier si la configuration ADDS Forest a déjà été effectuée via un flag
$FlagFile = "C:\ADSetupComplete.flag"
if (-not (Test-Path $FlagFile)) {

    # Variables de base
    $DomainName = "technova.local"
    $DomainDN   = "DC=technova,DC=local"
    $AdminUser  = "administrateur"
    # ⚠️ À MODIFIER AVANT UTILISATION — ne pas laisser ce mot de passe en production
    $AdminPassword = ConvertTo-SecureString "password/69" -AsPlainText -Force

    # Créer la forêt et le domaine
    Install-ADDSForest `
        -DomainName $DomainName `
        -InstallDns `
        -SafeModeAdministratorPassword $AdminPassword `
        -Force `
        -DomainNetbiosName "TECHNOVA" -ErrorAction Stop

    # Création du flag de fin de configuration
    New-Item -Path $FlagFile -ItemType File -Force | Out-Null
    Write-Host "La configuration de la forêt ADDS est terminée. Le serveur doit redémarrer."

    # Créer une tâche planifiée pour reprendre le script à la connexion de l'administrateur
    $ScriptPath = $MyInvocation.MyCommand.Path
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -NoExit -File `"$ScriptPath`""
    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $AdminUser
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName "Resume_AD_Creation" -Action $Action -Trigger $Trigger -Settings $Settings

    Restart-Computer -Force
    exit
}

# Petite pause pour laisser le temps aux services AD de se stabiliser
Start-Sleep -Seconds 60

# Création des Unités Organisationnelles (OUs)
$DomainDN = "DC=technova,DC=local"
$OUs = @("IT", "RH", "Ventes", "Marketing", "Finance")
foreach ($OU in $OUs) {
    New-ADOrganizationalUnitIfNeeded -OUName $OU -DomainDN $DomainDN
    Start-Sleep -Seconds 2  # Pause légère (à ajuster si nécessaire)
}

# Création des groupes dans leurs OUs respectives
$Groups = @(
    @{Name = "ITAdmins"; Description = "Administrateurs IT"; OU = "IT"},
    @{Name = "RHTeam"; Description = "Equipe des RH"; OU = "RH"},
    @{Name = "VentesTeam"; Description = "Equipe des ventes"; OU = "Ventes"},
    @{Name = "MarketingTeam"; Description = "Equipe marketing"; OU = "Marketing"},
    @{Name = "FinanceTeam"; Description = "Equipe Finance"; OU = "Finance"}
)
foreach ($Group in $Groups) {
    $GroupOUPath = "OU=$($Group.OU),$DomainDN"
    Test-ADGroup -GroupName $Group.Name -Description $Group.Description -OUPath $GroupOUPath
    Start-Sleep -Seconds 2
}

# Création des utilisateurs et ajout aux groupes
# ⚠️ À MODIFIER AVANT UTILISATION — ne pas laisser ce mot de passe en production
$DefaultPassword = ConvertTo-SecureString "P@ssw0rd!TSSR2025" -AsPlainText -Force

$Users = @(
    @{FirstName = "Alice";   LastName = "Smith";   Department = "IT";       Group = "ITAdmins"},
    @{FirstName = "John";    LastName = "Doe";     Department = "IT";       Group = "ITAdmins"},
    @{FirstName = "Emma";    LastName = "Jones";   Department = "IT";       Group = "ITAdmins"},
    @{FirstName = "Bob";     LastName = "Johnson"; Department = "RH";       Group = "RHTeam"},
    @{FirstName = "Sarah";   LastName = "Connor";  Department = "RH";       Group = "RHTeam"},
    @{FirstName = "Michael"; LastName = "Scott";   Department = "RH";       Group = "RHTeam"},
    @{FirstName = "Charlie"; LastName = "Brown";   Department = "Ventes";   Group = "VentesTeam"},
    @{FirstName = "Lucy";    LastName = "VanPelt"; Department = "Ventes";   Group = "VentesTeam"},
    @{FirstName = "Linus";   LastName = "VanPelt"; Department = "Ventes";   Group = "VentesTeam"},
    @{FirstName = "Diana";   LastName = "White";   Department = "Marketing";Group = "MarketingTeam"},
    @{FirstName = "Bruce";   LastName = "Wayne";   Department = "Marketing";Group = "MarketingTeam"},
    @{FirstName = "Clark";   LastName = "Kent";    Department = "Marketing";Group = "MarketingTeam"},
    @{FirstName = "Edward";  LastName = "Black";   Department = "Finance";  Group = "FinanceTeam"},
    @{FirstName = "Anna";    LastName = "Smith";   Department = "Finance";  Group = "FinanceTeam"},
    @{FirstName = "Paul";    LastName = "Walker";  Department = "Finance";  Group = "FinanceTeam"}
)
foreach ($User in $Users) {
    New-ADUserIfNeeded -FirstName $User.FirstName `
                  -LastName $User.LastName `
                  -Department $User.Department `
                  -GroupName $User.Group `
                  -DomainName "technova.local" `
                  -DomainDN $DomainDN `
                  -DefaultPassword $DefaultPassword
    Start-Sleep -Seconds 2
}

Write-Host "Configuration de l'Active Directory terminée avec succès."

# ------------------ DÉBUT DE LA CONFIGURATION DHCP ------------------

# Vérifier et installer le rôle DHCP
Install-WindowsFeatureIfNeeded -FeatureName "DHCP" -DisplayName "Rôle DHCP" -IncludeManagementTools

# Autoriser le serveur DHCP dans Active Directory
$ServerName = $env:COMPUTERNAME
if (-not (Get-DhcpServerInDC -ErrorAction SilentlyContinue)) {
    # Récupérer la première adresse IPv4 sur l'interface "Ethernet0" (à ajuster si nécessaire)
    # Détection automatique de la première interface IPv4 active (compatible VMware, Hyper-V, VirtualBox, physique)
    $IPAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" } | Select-Object -First 1 -ExpandProperty IPAddress)
    Add-DhcpServerInDC -DnsName "$ServerName.$env:USERDNSDOMAIN" -IPAddress $IPAddress -ErrorAction Stop
    Write-Host "Serveur DHCP autorisé dans Active Directory."
}
else {
    Write-Host "Serveur DHCP déjà autorisé dans Active Directory."
}

# Création d'un périmètre DHCP (scope)
$ScopeName      = "ScopeTechnova"
$StartRange     = "192.168.192.100"
$EndRange       = "192.168.192.200"
$SubnetMask     = "255.255.255.0"
$DefaultGateway = "192.168.192.2"
$DnsServers     = "192.168.192.10"

$ExistingScope = Get-DhcpServerv4Scope | Where-Object { $_.Name -eq $ScopeName }
if (-not $ExistingScope) {
    Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -State Active -ErrorAction Stop
    Write-Host "Périmètre DHCP '$ScopeName' créé."

    $ScopeId = (Get-DhcpServerv4Scope | Where-Object { $_.Name -eq $ScopeName }).ScopeId
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -Router $DefaultGateway -DnsServer $DnsServers -ErrorAction Stop
    Write-Host "Options DHCP configurées pour le périmètre '$ScopeName'."
}
else {
    Write-Host "Le périmètre DHCP '$ScopeName' existe déjà."
}

Write-Host "Configuration du DHCP terminée avec succès."
# ------------------ FIN DE LA CONFIGURATION DHCP ------------------