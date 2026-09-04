#!/usr/bin/env bash
set -Eeuo pipefail

# Instalacao online: a imagem vem do Docker Hub e os dados ficam em volumes.
PACKAGE_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PACKAGE_DIR"
[ "$(id -u)" -eq 0 ] || { echo "Execute como root: sudo ./install-online.sh <imagem> [porta]" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker nao encontrado." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 nao encontrado." >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "OpenSSL nao encontrado." >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Curl nao encontrado." >&2; exit 1; }
command -v ss >/dev/null 2>&1 || command -v lsof >/dev/null 2>&1 || { echo "ss ou lsof nao encontrado." >&2; exit 1; }

IMAGE="${1:?Informe a imagem Docker Hub, por exemplo usuario/bchat-whitelabel:1.2.8}"
PORT="${2:-8080}"
[[ "$IMAGE" =~ ^[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$ ]] || { echo "Imagem invalida." >&2; exit 1; }
[[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || { echo "Porta invalida." >&2; exit 1; }

port_listener() {
  if command -v ss >/dev/null 2>&1; then
    ss -H -ltn 2>/dev/null | awk -v port=":$PORT" '$4 ~ (port "$") { print; found=1 } END { exit !found }'
  else
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null
  fi
}

same_project_port() {
  local container
  container="$(docker compose ps -q bchat 2>/dev/null || true)"
  [ -n "$container" ] || return 1
  docker port "$container" 2>/dev/null | grep -Eq "(^|:)${PORT}->"
}

if listener="$(port_listener)" && ! same_project_port; then
  echo "A porta $PORT ja esta em uso:" >&2
  echo "$listener" >&2
  echo "Escolha outra porta, por exemplo: sudo ./install-online.sh $IMAGE 3388" >&2
  exit 1
fi

SERVER_IP="${BCHAT_SERVER_IP:-}"
if [ -z "$SERVER_IP" ]; then
  SERVER_IP="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
fi
if [ -z "$SERVER_IP" ]; then
  SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
SERVER_IP="${SERVER_IP:-127.0.0.1}"

[ -f .env ] || cp .env.example .env
random_secret() { openssl rand -hex 32; }
replace_value() {
  local key="$1" value="$2" temporary
  temporary="$(mktemp)"
  awk -v key="$key" -v value="$value" 'index($0,key "=")==1 { print key "=" value; next } { print }' .env > "$temporary"
  mv "$temporary" .env
}

replace_value BCHAT_IMAGE "$IMAGE"
replace_value BCHAT_VERSION "${IMAGE##*:}"
replace_value APP_BASE_URL "http://$SERVER_IP:$PORT"
replace_value SIP_DOMAIN "$SERVER_IP"
current_asterisk_ip="$(awk -F= '$1=="ASTERISK_PUBLIC_IP" {print substr($0,index($0,"=")+1)}' .env)"
if [ -z "$current_asterisk_ip" ] || [ "$current_asterisk_ip" = "CHANGE_TO_SERVER_PUBLIC_IP" ]; then
  replace_value ASTERISK_PUBLIC_IP "$SERVER_IP"
fi
replace_value BCHAT_GATEWAY_PORT "$PORT"
replace_value BCHAT_BIND_ADDRESS "0.0.0.0"
current_rtp_end="$(awk -F= '$1=="ASTERISK_RTP_END" {print substr($0,index($0,"=")+1)}' .env)"
if [ -z "$current_rtp_end" ] || [ "$current_rtp_end" = "20000" ]; then
  replace_value ASTERISK_RTP_END "10100"
fi
for key in DB_PASS POSTGRES_PASSWORD REDIS_PASSWORD JWT_SECRET JWT_REFRESH_SECRET MASTER_KEY SEAWEEDFS_SECRET_KEY ASTERISK_AMI_SECRET; do
  current="$(awk -F= -v key="$key" '$1==key {print substr($0,index($0,"=")+1)}' .env)"
  [ -n "$current" ] && [ "$current" != GENERATE_ME ] || replace_value "$key" "$(random_secret)"
done
chmod 600 .env

echo "Baixando $IMAGE..."
docker pull "$IMAGE"
docker compose config >/dev/null
docker compose up -d

container="$(docker compose ps -q bchat 2>/dev/null || true)"
if [ -z "$container" ] || [ "$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)" != "running" ]; then
  echo "O container BChat nao permaneceu em execucao." >&2
  docker compose ps -a >&2 || true
  docker compose logs --tail=100 bchat >&2 || true
  exit 1
fi

echo
echo "Endereco do servidor: http://$SERVER_IP:$PORT"
echo "BChat iniciado em http://$SERVER_IP:$PORT/__bchat"
echo "Acesse esse endereco para ativar a licenca e configurar marca, dominios, Nginx, HTTPS e integracoes."
echo "Admin inicial: ${INIT_ADMIN_EMAIL:-admin@empresa.local}"
echo "Senha inicial: ${INIT_ADMIN_PASSWORD:-admin123} (altere apos o primeiro acesso)"
