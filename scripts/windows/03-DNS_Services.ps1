# ============================================================
# 03-DNS_Services.ps1
# Création des enregistrements DNS applicatifs TechNova
# À lancer sur SRV-AD en PowerShell administrateur
# ============================================================

$ZoneName = "technova.local"

$Records = @(
    @{ Name = "nextcloud"; IPv4Address = "192.168.192.20" },
    @{ Name = "rocket";    IPv4Address = "192.168.192.30" },
    @{ Name = "meet";      IPv4Address = "192.168.192.40" },
    @{ Name = "n8n";       IPv4Address = "192.168.192.50" }
)

Write-Host "=== Création / vérification des enregistrements DNS TechNova ==="

foreach ($Record in $Records) {
    $Name = $Record.Name
    $IP = $Record.IPv4Address

    $Existing = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $Name -ErrorAction SilentlyContinue

    if ($Existing) {
        Write-Host "Enregistrement existant : $Name.$ZoneName"
        Write-Host "Suppression de l'ancien enregistrement pour recréation propre..."
        Remove-DnsServerResourceRecord -ZoneName $ZoneName -Name $Name -RRType "A" -Force
    }

    Add-DnsServerResourceRecordA -ZoneName $ZoneName -Name $Name -IPv4Address $IP -TimeToLive 01:00:00
    Write-Host "Créé : $Name.$ZoneName -> $IP"
}

Write-Host ""
Write-Host "=== Vérification DNS ==="

foreach ($Record in $Records) {
    $Fqdn = "$($Record.Name).$ZoneName"
    Resolve-DnsName $Fqdn -Server 127.0.0.1
}

Write-Host ""
Write-Host "Configuration DNS applicative terminée."
