#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Installation automatique de Rocket.Chat sur Debian 13
# Docker Compose + MongoDB replica set
# ============================================================
#
# Fichiers attendus :
# - scripts/linux/02-install-rocketchat.sh
# - env/rocketchat.env
# ou un fichier .env placé dans le même dossier que le script
#
# Lancer :
# chmod +x 02-install-rocketchat.sh
# ./02-install-rocketchat.sh
#
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ENV_FILE="${SCRIPT_DIR}/.env"
REPO_ENV_FILE="${SCRIPT_DIR}/../../env/rocketchat.env"
ENV_FILE="${ENV_FILE:-$DEFAULT_ENV_FILE}"
[[ -f "$ENV_FILE" || ! -f "$REPO_ENV_FILE" ]] || ENV_FILE="$REPO_ENV_FILE"

log() {
  echo -e "\n[INFO] $*"
}

warn() {
  echo -e "\n[ATTENTION] $*"
}

error() {
  echo -e "\n[ERREUR] $*" >&2
  exit 1
}

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

docker_cmd() {
  # Utilise Docker sans sudo si l'utilisateur a déjà les droits.
  # Sinon, utilise sudo docker.
  if docker ps >/dev/null 2>&1; then
    docker "$@"
  else
    run_as_root docker "$@"
  fi
}

load_env() {
  [[ -f "$ENV_FILE" ]] || error "Fichier d'environnement introuvable. Place un .env dans ${SCRIPT_DIR} ou utilise env/rocketchat.env."

  log "Chargement du fichier .env"

  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a

  : "${INSTALL_DIR:?Variable INSTALL_DIR manquante dans .env}"
  : "${ROOT_URL:?Variable ROOT_URL manquante dans .env}"
  : "${ROCKETCHAT_PORT:?Variable ROCKETCHAT_PORT manquante dans .env}"
  : "${MONGO_IMAGE:?Variable MONGO_IMAGE manquante dans .env}"
  : "${ROCKETCHAT_IMAGE:?Variable ROCKETCHAT_IMAGE manquante dans .env}"
  : "${MONGO_CONTAINER_NAME:?Variable MONGO_CONTAINER_NAME manquante dans .env}"
  : "${MONGO_INIT_CONTAINER_NAME:?Variable MONGO_INIT_CONTAINER_NAME manquante dans .env}"
  : "${ROCKETCHAT_CONTAINER_NAME:?Variable ROCKETCHAT_CONTAINER_NAME manquante dans .env}"
  : "${MONGO_DB_NAME:?Variable MONGO_DB_NAME manquante dans .env}"
  : "${MONGO_REPLICA_SET:?Variable MONGO_REPLICA_SET manquante dans .env}"
  : "${MONGO_OPLOG_SIZE:?Variable MONGO_OPLOG_SIZE manquante dans .env}"
  : "${ADMIN_USERNAME:?Variable ADMIN_USERNAME manquante dans .env}"
  : "${ADMIN_NAME:?Variable ADMIN_NAME manquante dans .env}"
  : "${ADMIN_EMAIL:?Variable ADMIN_EMAIL manquante dans .env}"
  : "${ADMIN_PASS:?Variable ADMIN_PASS manquante dans .env}"
  : "${SKIP_SETUP_WIZARD:?Variable SKIP_SETUP_WIZARD manquante dans .env}"
  : "${ADD_USER_TO_DOCKER_GROUP:?Variable ADD_USER_TO_DOCKER_GROUP manquante dans .env}"

  if [[ "$ROOT_URL" == *"ADRESSE_IP_DU_SERVEUR"* ]]; then
    error "Tu dois modifier ROOT_URL dans le fichier .env avant de lancer l'installation. Exemple : ROOT_URL=\"http://192.168.42.139:3000\""
  fi
}

check_system() {
  log "Vérification du système"

  [[ -f /etc/os-release ]] || error "Impossible de vérifier la distribution Linux."

  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "${ID:-}" != "debian" ]]; then
    warn "Cette procédure est prévue pour Debian. Système détecté : ${PRETTY_NAME:-inconnu}"
  fi

  if [[ "${VERSION_CODENAME:-}" != "trixie" ]]; then
    warn "Cette procédure vise Debian 13 Trixie. Codename détecté : ${VERSION_CODENAME:-inconnu}"
  fi

  if ! command -v sudo >/dev/null 2>&1 && [[ "$(id -u)" -ne 0 ]]; then
    error "sudo n'est pas installé et le script n'est pas lancé en root."
  fi
}

install_dependencies() {
  log "Installation / vérification des dépendances de base"

  run_as_root apt update

  PACKAGES_TO_INSTALL=""

  for package in ca-certificates curl gnupg lsb-release; do
    if dpkg -s "$package" >/dev/null 2>&1; then
      log "$package est déjà installé."
    else
      log "$package n'est pas installé. Il va être installé."
      PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $package"
    fi
  done

  if [[ -n "$PACKAGES_TO_INSTALL" ]]; then
    run_as_root apt install -y $PACKAGES_TO_INSTALL
  else
    log "Toutes les dépendances de base sont déjà installées."
  fi
}

install_docker() {
  log "Installation / vérification de Docker"

  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "Docker et Docker Compose sont déjà installés."
    docker --version || true
    docker compose version || true
    return
  fi

  log "Docker n'est pas complètement installé. Installation en cours."

  run_as_root install -m 0755 -d /etc/apt/keyrings

  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    log "Ajout de la clé officielle Docker"
    curl -fsSL https://download.docker.com/linux/debian/gpg | run_as_root gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    run_as_root chmod a+r /etc/apt/keyrings/docker.gpg
  else
    log "La clé Docker existe déjà."
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  DOCKER_CODENAME="${VERSION_CODENAME:-trixie}"

  log "Ajout / mise à jour du dépôt Docker pour Debian ${DOCKER_CODENAME}"

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${DOCKER_CODENAME} stable" | run_as_root tee /etc/apt/sources.list.d/docker.list >/dev/null

  run_as_root apt update

  PACKAGES_TO_INSTALL=""

  for package in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
    if dpkg -s "$package" >/dev/null 2>&1; then
      log "$package est déjà installé."
    else
      log "$package n'est pas installé. Il va être installé."
      PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $package"
    fi
  done

  if [[ -n "$PACKAGES_TO_INSTALL" ]]; then
    run_as_root apt install -y $PACKAGES_TO_INSTALL
  else
    log "Tous les paquets Docker sont déjà installés."
  fi

  log "Activation du service Docker"
  run_as_root systemctl enable --now docker

  log "Versions Docker"
  docker_cmd --version
  docker_cmd compose version
}

configure_docker_group() {
  if [[ "${ADD_USER_TO_DOCKER_GROUP}" != "true" ]]; then
    log "Ajout au groupe docker désactivé dans .env"
    return
  fi

  CURRENT_USER="${SUDO_USER:-$USER}"

  log "Vérification du groupe docker pour l'utilisateur ${CURRENT_USER}"

  if id -nG "$CURRENT_USER" | grep -qw docker; then
    log "L'utilisateur ${CURRENT_USER} est déjà membre du groupe docker."
  else
    log "Ajout de ${CURRENT_USER} au groupe docker"
    run_as_root usermod -aG docker "$CURRENT_USER"
    warn "Les droits Docker sans sudo seront actifs après déconnexion/reconnexion ou redémarrage."
  fi
}

prepare_install_dir() {
  log "Préparation du dossier d'installation : ${INSTALL_DIR}"

  run_as_root mkdir -p "$INSTALL_DIR"
  run_as_root cp "$ENV_FILE" "${INSTALL_DIR}/.env"

  CURRENT_USER="${SUDO_USER:-$USER}"
  run_as_root chown -R "$CURRENT_USER:$CURRENT_USER" "$INSTALL_DIR"
}

write_compose_file() {
  log "Création du fichier compose.yml dans ${INSTALL_DIR}"

  cat > "${INSTALL_DIR}/compose.yml" <<'EOF'
services:
  mongodb:
    image: ${MONGO_IMAGE}
    container_name: ${MONGO_CONTAINER_NAME}
    restart: unless-stopped
    command: mongod --replSet ${MONGO_REPLICA_SET} --oplogSize ${MONGO_OPLOG_SIZE} --bind_ip_all
    volumes:
      - mongodb_data:/data/db

  mongodb-init-replica:
    image: ${MONGO_IMAGE}
    container_name: ${MONGO_INIT_CONTAINER_NAME}
    depends_on:
      - mongodb
    command: >
      bash -c "
      sleep 10 &&
      mongosh --host mongodb:27017 --eval '
      try {
        rs.status()
      } catch (e) {
        rs.initiate({
          _id: \"${MONGO_REPLICA_SET}\",
          members: [{ _id: 0, host: \"mongodb:27017\" }]
        })
      }'"
    restart: "no"

  rocketchat:
    image: ${ROCKETCHAT_IMAGE}
    container_name: ${ROCKETCHAT_CONTAINER_NAME}
    restart: unless-stopped
    depends_on:
      - mongodb
      - mongodb-init-replica
    environment:
      ROOT_URL: ${ROOT_URL}
      PORT: 3000
      MONGO_URL: mongodb://mongodb:27017/${MONGO_DB_NAME}?replicaSet=${MONGO_REPLICA_SET}
      MONGO_OPLOG_URL: mongodb://mongodb:27017/local?replicaSet=${MONGO_REPLICA_SET}
      DEPLOY_METHOD: docker
      INITIAL_USER: "yes"
      ADMIN_USERNAME: ${ADMIN_USERNAME}
      ADMIN_NAME: ${ADMIN_NAME}
      ADMIN_EMAIL: ${ADMIN_EMAIL}
      ADMIN_PASS: ${ADMIN_PASS}
      OVERWRITE_SETTING_Setup_Wizard: completed
      OVERWRITE_SETTING_Show_Setup_Wizard: completed
    ports:
      - "${ROCKETCHAT_PORT}:3000"
    volumes:
      - uploads_data:/app/uploads

volumes:
  mongodb_data:
  uploads_data:
EOF
}

start_rocketchat() {
  log "Téléchargement des images Docker"
  cd "$INSTALL_DIR"
  docker_cmd compose pull

  log "Démarrage de Rocket.Chat"
  docker_cmd compose up -d
}

wait_for_mongodb() {
  log "Attente du démarrage de MongoDB"

  for i in {1..45}; do
    if docker_cmd exec "${MONGO_CONTAINER_NAME}" mongosh --quiet --eval "db.adminCommand('ping').ok" >/dev/null 2>&1; then
      log "MongoDB répond correctement."
      return
    fi

    echo "Attente MongoDB... tentative ${i}/45"
    sleep 2
  done

  warn "MongoDB ne répond pas encore. Vérifie les logs si Rocket.Chat ne démarre pas."
}

force_skip_setup_wizard() {
  if [[ "${SKIP_SETUP_WIZARD}" != "true" ]]; then
    log "Forçage du Setup Wizard désactivé dans .env"
    return
  fi

  log "Forçage du Setup Wizard Rocket.Chat à l'état completed"

  if docker_cmd exec "${MONGO_CONTAINER_NAME}" mongosh "${MONGO_DB_NAME}" --quiet --eval '
    db.rocketchat_settings.updateOne(
      { _id: "Show_Setup_Wizard" },
      { $set: { value: "completed" } },
      { upsert: true }
    );
    db.rocketchat_settings.updateOne(
      { _id: "Setup_Wizard" },
      { $set: { value: "completed" } },
      { upsert: true }
    );
  ' >/dev/null 2>&1; then
    log "Setup Wizard mis à jour dans MongoDB."
    cd "$INSTALL_DIR"
    docker_cmd compose restart rocketchat >/dev/null 2>&1 || true
  else
    warn "Impossible de modifier le Setup Wizard pour le moment. Ce n'est pas toujours bloquant."
  fi
}

show_result() {
  cd "$INSTALL_DIR"

  log "État des conteneurs"
  docker_cmd ps --filter "name=rocketchat"

  echo
  echo "============================================================"
  echo "Installation terminée"
  echo "Adresse Rocket.Chat : ${ROOT_URL}"
  echo
  echo "Compte administrateur prévu au premier démarrage :"
  echo "Utilisateur : ${ADMIN_USERNAME}"
  echo "E-mail      : ${ADMIN_EMAIL}"
  echo "Mot de passe: valeur définie dans le fichier .env"
  echo
  echo "Commandes utiles :"
  echo "cd ${INSTALL_DIR}"
  echo "docker compose ps"
  echo "docker compose logs -f rocketchat"
  echo "docker compose restart"
  echo "docker compose down"
  echo "docker compose up -d"
  echo
  echo "IMPORTANT :"
  echo "Il est recommandé de redémarrer la machine après l'installation."
  echo "Cela permet d'appliquer correctement les droits Docker de l'utilisateur."
  echo
  echo "Commande :"
  echo "sudo reboot"
  echo "============================================================"
}

main() {
  load_env
  check_system
  install_dependencies
  install_docker
  configure_docker_group
  prepare_install_dir
  write_compose_file
  start_rocketchat
  wait_for_mongodb
  force_skip_setup_wizard
  show_result
}

main "$@"
