#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# 00-configure-static-ip.sh
# Configure IP fixe + hostname + DNS sur Debian 13
# Usage :
# sudo ./00-configure-static-ip.sh --hostname SRV-NEXTCLOUD --ip 192.168.192.20 --gateway 192.168.192.2 --dns 192.168.192.10
# ============================================================

HOSTNAME_VALUE=""
IP_ADDRESS=""
GATEWAY=""
DNS_SERVER=""
NETMASK="255.255.255.0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hostname) HOSTNAME_VALUE="$2"; shift 2 ;;
    --ip) IP_ADDRESS="$2"; shift 2 ;;
    --gateway) GATEWAY="$2"; shift 2 ;;
    --dns) DNS_SERVER="$2"; shift 2 ;;
    --netmask) NETMASK="$2"; shift 2 ;;
    *) echo "Paramètre inconnu : $1"; exit 1 ;;
  esac
done

if [[ -z "$HOSTNAME_VALUE" || -z "$IP_ADDRESS" || -z "$GATEWAY" || -z "$DNS_SERVER" ]]; then
  echo "Paramètres obligatoires manquants."
  echo "Exemple : sudo ./00-configure-static-ip.sh --hostname SRV-NEXTCLOUD --ip 192.168.192.20 --gateway 192.168.192.2 --dns 192.168.192.10"
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Lance ce script avec sudo."
  exit 1
fi

IFACE="$(ip -o -4 route show to default | awk '{print $5}' | head -n1)"

if [[ -z "$IFACE" ]]; then
  IFACE="$(ls /sys/class/net | grep -E '^(ens|enp|eth)' | head -n1)"
fi

if [[ -z "$IFACE" ]]; then
  echo "Impossible de détecter l'interface réseau."
  exit 1
fi

echo "[INFO] Interface détectée : $IFACE"
echo "[INFO] Configuration hostname : $HOSTNAME_VALUE"
hostnamectl set-hostname "$HOSTNAME_VALUE"

echo "[INFO] Sauvegarde de /etc/network/interfaces"
cp /etc/network/interfaces "/etc/network/interfaces.backup-$(date +%F-%H%M%S)" 2>/dev/null || true

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $IP_ADDRESS
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS_SERVER
    dns-search technova.local
EOF

echo "[INFO] Configuration DNS temporaire dans /etc/resolv.conf"
cat > /etc/resolv.conf <<EOF
search technova.local
nameserver $DNS_SERVER
EOF

echo "[INFO] Redémarrage réseau"
systemctl restart networking || true

echo ""
echo "Configuration terminée."
echo "IP configurée : $IP_ADDRESS"
echo "DNS configuré : $DNS_SERVER"
echo "Hostname      : $HOSTNAME_VALUE"
echo ""
echo "Redémarrage recommandé : sudo reboot"
