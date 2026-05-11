#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# 01-install-nextcloud.sh
# Installation robuste de Nextcloud pour POC TechNova
# Debian 13 + Docker Compose + MariaDB + Redis
#
# Fichiers attendus :
# - scripts/linux/01-install-nextcloud.sh
# - env/nextcloud.env
# ou un fichier .env placé dans le même dossier que le script
#
# Lancement :
# chmod +x 01-install-nextcloud.sh
# ./01-install-nextcloud.sh
#
# Option POC :
# Dans le .env, tu peux mettre :
# POC_RESET="true"
#
# Si POC_RESET=true, le script supprime l'ancienne installation Docker
# et repart proprement avec des volumes neufs.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ENV_FILE="${SCRIPT_DIR}/.env"
REPO_ENV_FILE="${SCRIPT_DIR}/../../env/nextcloud.env"
ENV_FILE="${ENV_FILE:-$DEFAULT_ENV_FILE}"
[[ -f "$ENV_FILE" || ! -f "$REPO_ENV_FILE" ]] || ENV_FILE="$REPO_ENV_FILE"

log(){ echo -e "\n[INFO] $*"; }
warn(){ echo -e "\n[ATTENTION] $*"; }
error(){ echo -e "\n[ERREUR] $*" >&2; exit 1; }

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

docker_cmd() {
  if docker ps >/dev/null 2>&1; then
    docker "$@"
  else
    run_as_root docker "$@"
  fi
}

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    run_as_root docker compose "$@"
  fi
}

load_env() {
  [[ -f "$ENV_FILE" ]] || error "Fichier d'environnement introuvable. Place un .env dans ${SCRIPT_DIR} ou utilise env/nextcloud.env."

  log "Chargement du fichier .env"

  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a

  : "${INSTALL_DIR:?Variable INSTALL_DIR manquante dans .env}"
  : "${NEXTCLOUD_TRUSTED_DOMAIN:?Variable NEXTCLOUD_TRUSTED_DOMAIN manquante dans .env}"
  : "${NEXTCLOUD_IP:?Variable NEXTCLOUD_IP manquante dans .env}"
  : "${NEXTCLOUD_PORT:?Variable NEXTCLOUD_PORT manquante dans .env}"
  : "${NEXTCLOUD_ADMIN_USER:?Variable NEXTCLOUD_ADMIN_USER manquante dans .env}"
  : "${NEXTCLOUD_ADMIN_PASSWORD:?Variable NEXTCLOUD_ADMIN_PASSWORD manquante dans .env}"
  : "${MYSQL_DATABASE:?Variable MYSQL_DATABASE manquante dans .env}"
  : "${MYSQL_USER:?Variable MYSQL_USER manquante dans .env}"
  : "${MYSQL_PASSWORD:?Variable MYSQL_PASSWORD manquante dans .env}"
  : "${MYSQL_ROOT_PASSWORD:?Variable MYSQL_ROOT_PASSWORD manquante dans .env}"
  : "${NEXTCLOUD_IMAGE:?Variable NEXTCLOUD_IMAGE manquante dans .env}"
  : "${MARIADB_IMAGE:?Variable MARIADB_IMAGE manquante dans .env}"
  : "${REDIS_IMAGE:?Variable REDIS_IMAGE manquante dans .env}"
  : "${ADD_USER_TO_DOCKER_GROUP:?Variable ADD_USER_TO_DOCKER_GROUP manquante dans .env}"

  POC_RESET="${POC_RESET:-false}"
  AUTO_FIX_BROKEN_VOLUME="${AUTO_FIX_BROKEN_VOLUME:-true}"
}

check_system() {
  log "Vérification du système"

  [[ -f /etc/os-release ]] || error "Impossible de vérifier la distribution Linux."

  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "${ID:-}" != "debian" ]]; then
    warn "Cette procédure est prévue pour Debian. Système détecté : ${PRETTY_NAME:-inconnu}"
  fi

  if ! command -v sudo >/dev/null 2>&1 && [[ "$(id -u)" -ne 0 ]]; then
    error "sudo n'est pas installé et le script n'est pas lancé en root."
  fi
}

install_dependencies() {
  log "Installation / vérification des dépendances de base"
  run_as_root apt update
  run_as_root apt install -y ca-certificates curl gnupg lsb-release
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "Docker et Docker Compose sont déjà installés."
    docker_cmd --version || true
    docker_cmd compose version || true
    return
  fi

  log "Installation de Docker et Docker Compose"

  run_as_root install -m 0755 -d /etc/apt/keyrings

  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | run_as_root gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    run_as_root chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" | run_as_root tee /etc/apt/sources.list.d/docker.list >/dev/null

  run_as_root apt update
  run_as_root apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  run_as_root systemctl enable --now docker
}

configure_docker_group() {
  [[ "$ADD_USER_TO_DOCKER_GROUP" == "true" ]] || return

  CURRENT_USER="${SUDO_USER:-$USER}"

  if id -nG "$CURRENT_USER" | grep -qw docker; then
    log "L'utilisateur ${CURRENT_USER} est déjà dans le groupe docker."
  else
    log "Ajout de ${CURRENT_USER} au groupe docker"
    run_as_root usermod -aG docker "$CURRENT_USER"
    warn "Les droits Docker sans sudo seront actifs après reconnexion ou redémarrage."
  fi
}

prepare_install_dir() {
  log "Préparation du dossier ${INSTALL_DIR}"

  run_as_root mkdir -p "$INSTALL_DIR"
  run_as_root cp "$ENV_FILE" "${INSTALL_DIR}/.env"

  CURRENT_USER="${SUDO_USER:-$USER}"
  run_as_root chown -R "$CURRENT_USER:$CURRENT_USER" "$INSTALL_DIR"
}

write_compose() {
  log "Création du fichier compose.yml"

  cat > "${INSTALL_DIR}/compose.yml" <<'EOF'
services:
  db:
    image: ${MARIADB_IMAGE}
    container_name: nextcloud-db
    restart: unless-stopped
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 10

  redis:
    image: ${REDIS_IMAGE}
    container_name: nextcloud-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data

  app:
    image: ${NEXTCLOUD_IMAGE}
    container_name: nextcloud
    restart: unless-stopped
    ports:
      - "${NEXTCLOUD_PORT}:80"
    depends_on:
      - db
      - redis
    environment:
      MYSQL_HOST: db
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      NEXTCLOUD_ADMIN_USER: ${NEXTCLOUD_ADMIN_USER}
      NEXTCLOUD_ADMIN_PASSWORD: ${NEXTCLOUD_ADMIN_PASSWORD}
      NEXTCLOUD_TRUSTED_DOMAINS: ${NEXTCLOUD_TRUSTED_DOMAIN} ${NEXTCLOUD_IP}
      REDIS_HOST: redis
    volumes:
      - nextcloud_data:/var/www/html

volumes:
  db_data:
  redis_data:
  nextcloud_data:
EOF
}

clean_poc_install() {
  cd "$INSTALL_DIR"

  if [[ "$POC_RESET" == "true" ]]; then
    warn "POC_RESET=true : suppression de l'ancienne installation Nextcloud"
    compose_cmd down -v --remove-orphans || true
  else
    log "POC_RESET=false : conservation des volumes existants"
  fi
}

start_service() {
  cd "$INSTALL_DIR"

  log "Téléchargement des images"
  compose_cmd pull

  log "Démarrage de Nextcloud"
  compose_cmd up -d
}

wait_for_nextcloud_files() {
  log "Vérification de l'initialisation des fichiers Nextcloud"

  for i in {1..60}; do
    if docker_cmd exec nextcloud test -f /var/www/html/version.php >/dev/null 2>&1; then
      log "Fichier version.php détecté."
      return 0
    fi

    echo "Attente des fichiers Nextcloud... tentative ${i}/60"
    sleep 3
  done

  return 1
}

auto_fix_broken_volume() {
  if [[ "$AUTO_FIX_BROKEN_VOLUME" != "true" ]]; then
    return
  fi

  warn "Le fichier /var/www/html/version.php est absent."
  warn "Le volume Nextcloud semble incomplet. Nettoyage automatique et relance."

  cd "$INSTALL_DIR"
  compose_cmd down -v --remove-orphans
  compose_cmd up -d

  if ! wait_for_nextcloud_files; then
    error "Échec : version.php toujours absent après nettoyage. Vérifie l'image Nextcloud et les logs."
  fi
}

wait_for_nextcloud_ready() {
  log "Attente de la disponibilité de Nextcloud"

  for i in {1..60}; do
    if docker_cmd exec -u www-data nextcloud php occ status >/dev/null 2>&1; then
      log "Commande occ disponible."
      return 0
    fi

    echo "Attente de occ... tentative ${i}/60"
    sleep 3
  done

  warn "La commande occ ne répond pas encore. Affichage des logs."
  compose_cmd logs --tail=80 app || true
  error "Nextcloud n'est pas prêt."
}

show_status() {
  cd "$INSTALL_DIR"

  echo
  echo "============================================================"
  echo "État des conteneurs"
  echo "============================================================"
  compose_cmd ps

  echo
  echo "============================================================"
  echo "Statut Nextcloud"
  echo "============================================================"
  docker_cmd exec -u www-data nextcloud php occ status || true
}

show_result() {
  echo
  echo "============================================================"
  echo "Installation Nextcloud terminée"
  echo "============================================================"
  echo "URL DNS : http://${NEXTCLOUD_TRUSTED_DOMAIN}"
  echo "URL IP  : http://${NEXTCLOUD_IP}:${NEXTCLOUD_PORT}"
  echo
  echo "Compte administrateur local Nextcloud :"
  echo "Utilisateur : ${NEXTCLOUD_ADMIN_USER}"
  echo "Mot de passe: valeur définie dans le fichier .env"
  echo
  echo "Commandes utiles :"
  echo "cd ${INSTALL_DIR}"
  echo "docker compose ps"
  echo "docker compose logs -f app"
  echo "docker exec -u www-data -it nextcloud php occ status"
  echo
  echo "Si l'utilisateur vient d'être ajouté au groupe docker : sudo reboot"
  echo "============================================================"
}

main() {
  load_env
  check_system
  install_dependencies
  install_docker
  configure_docker_group
  prepare_install_dir
  write_compose
  clean_poc_install
  start_service

  if ! wait_for_nextcloud_files; then
    auto_fix_broken_volume
  fi

  wait_for_nextcloud_ready
  show_status
  show_result
}

main "$@"
