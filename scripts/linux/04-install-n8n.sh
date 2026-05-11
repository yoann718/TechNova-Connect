#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ENV_FILE="${SCRIPT_DIR}/.env"
REPO_ENV_FILE="${SCRIPT_DIR}/../../env/n8n.env"
ENV_FILE="${ENV_FILE:-$DEFAULT_ENV_FILE}"
[[ -f "$ENV_FILE" || ! -f "$REPO_ENV_FILE" ]] || ENV_FILE="$REPO_ENV_FILE"

log(){ echo -e "\n[INFO] $*"; }
warn(){ echo -e "\n[ATTENTION] $*"; }
error(){ echo -e "\n[ERREUR] $*" >&2; exit 1; }

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

docker_cmd() {
  if docker ps >/dev/null 2>&1; then docker "$@"; else run_as_root docker "$@"; fi
}

load_env() {
  [[ -f "$ENV_FILE" ]] || error "Fichier d'environnement introuvable. Place un .env dans ${SCRIPT_DIR} ou utilise env/n8n.env."
  set -a
  source "$ENV_FILE"
  set +a

  : "${INSTALL_DIR:?}"
  : "${N8N_HOST:?}"
  : "${N8N_PORT:?}"
  : "${N8N_PROTOCOL:?}"
  : "${POSTGRES_DB:?}"
  : "${POSTGRES_USER:?}"
  : "${POSTGRES_PASSWORD:?}"
  : "${N8N_ENCRYPTION_KEY:?}"
  : "${N8N_IMAGE:?}"
  : "${POSTGRES_IMAGE:?}"
  : "${ADD_USER_TO_DOCKER_GROUP:?}"
}

install_dependencies() {
  run_as_root apt update
  run_as_root apt install -y ca-certificates curl gnupg lsb-release
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "Docker déjà installé."
    return
  fi

  run_as_root install -m 0755 -d /etc/apt/keyrings

  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | run_as_root gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    run_as_root chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  source /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" | run_as_root tee /etc/apt/sources.list.d/docker.list >/dev/null

  run_as_root apt update
  run_as_root apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  run_as_root systemctl enable --now docker
}

configure_docker_group() {
  [[ "$ADD_USER_TO_DOCKER_GROUP" == "true" ]] || return
  CURRENT_USER="${SUDO_USER:-$USER}"
  if ! id -nG "$CURRENT_USER" | grep -qw docker; then
    run_as_root usermod -aG docker "$CURRENT_USER"
    warn "Les droits Docker sans sudo seront actifs après redémarrage."
  fi
}

write_compose() {
  run_as_root mkdir -p "$INSTALL_DIR"
  run_as_root cp "$ENV_FILE" "$INSTALL_DIR/.env"
  CURRENT_USER="${SUDO_USER:-$USER}"
  run_as_root chown -R "$CURRENT_USER:$CURRENT_USER" "$INSTALL_DIR"

  cat > "$INSTALL_DIR/compose.yml" <<'EOF'
services:
  postgres:
    image: ${POSTGRES_IMAGE}
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

  n8n:
    image: ${N8N_IMAGE}
    container_name: n8n
    restart: unless-stopped
    ports:
      - "${N8N_PORT}:5678"
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
      N8N_HOST: ${N8N_HOST}
      N8N_PORT: 5678
      N8N_PROTOCOL: ${N8N_PROTOCOL}
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      WEBHOOK_URL: ${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}/
      GENERIC_TIMEZONE: Europe/Paris
    depends_on:
      - postgres
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  postgres_data:
  n8n_data:
EOF
}

start_service() {
  cd "$INSTALL_DIR"
  docker_cmd compose pull
  docker_cmd compose up -d
}

show_result() {
  echo
  echo "============================================================"
  echo "n8n installé"
  echo "URL : ${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}"
  echo
  echo "Commandes utiles :"
  echo "cd ${INSTALL_DIR}"
  echo "docker compose ps"
  echo "docker compose logs -f n8n"
  echo
  echo "Workflow POC conseillé :"
  echo "Manual Trigger -> HTTP Request Nextcloud/Rocket.Chat/Jitsi -> synthèse"
  echo
  echo "Redémarrage recommandé : sudo reboot"
  echo "============================================================"
}

main() {
  load_env
  install_dependencies
  install_docker
  configure_docker_group
  write_compose
  start_service
  show_result
}

main "$@"
