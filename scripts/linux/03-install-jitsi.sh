#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ENV_FILE="${SCRIPT_DIR}/.env"
REPO_ENV_FILE="${SCRIPT_DIR}/../../env/jitsi.env"
ENV_FILE="${ENV_FILE:-$DEFAULT_ENV_FILE}"
[[ -f "$ENV_FILE" || ! -f "$REPO_ENV_FILE" ]] || ENV_FILE="$REPO_ENV_FILE"

log(){ echo -e "\n[INFO] $*"; }
warn(){ echo -e "\n[ATTENTION] $*"; }
error(){ echo -e "\n[ERREUR] $*" >&2; exit 1; }

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

load_env() {
  [[ -f "$ENV_FILE" ]] || error "Fichier d'environnement introuvable. Place un .env dans ${SCRIPT_DIR} ou utilise env/jitsi.env."
  set -a
  source "$ENV_FILE"
  set +a
  : "${JITSI_FQDN:?}"
  : "${JITSI_IP:?}"
}

install_jitsi() {
  log "Préparation système"
  run_as_root apt update
  run_as_root apt install -y curl gnupg2 apt-transport-https ca-certificates debconf-utils nginx-full

  log "Configuration du hostname"
  run_as_root hostnamectl set-hostname "$JITSI_FQDN"

  if ! grep -q "$JITSI_FQDN" /etc/hosts; then
    echo "$JITSI_IP $JITSI_FQDN" | run_as_root tee -a /etc/hosts >/dev/null
  fi

  log "Ajout du dépôt Jitsi"
  curl -fsSL https://download.jitsi.org/jitsi-key.gpg.key | run_as_root gpg --dearmor -o /usr/share/keyrings/jitsi-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/" | run_as_root tee /etc/apt/sources.list.d/jitsi-stable.list >/dev/null

  run_as_root apt update

  log "Préconfiguration Jitsi"
  echo "jitsi-videobridge2 jitsi-videobridge/jvb-hostname string $JITSI_FQDN" | run_as_root debconf-set-selections
  echo "jitsi-meet-web-config jitsi-meet/cert-choice select Generate a new self-signed certificate" | run_as_root debconf-set-selections

  log "Installation Jitsi Meet"
  DEBIAN_FRONTEND=noninteractive run_as_root apt install -y jitsi-meet

  log "Redémarrage des services Jitsi"
  run_as_root systemctl restart prosody || true
  run_as_root systemctl restart jicofo || true
  run_as_root systemctl restart jitsi-videobridge2 || true
  run_as_root systemctl restart nginx || true
}

show_result() {
  echo
  echo "============================================================"
  echo "Jitsi Meet installé"
  echo "URL de test : http://${JITSI_FQDN}"
  echo
  echo "Attention : pour tester correctement caméra/micro,"
  echo "la phase HTTPS sera nécessaire ou fortement recommandée."
  echo
  echo "Commandes utiles :"
  echo "systemctl status jitsi-videobridge2"
  echo "systemctl status jicofo"
  echo "systemctl status prosody"
  echo "============================================================"
}

main() {
  load_env
  install_jitsi
  show_result
}

main "$@"
