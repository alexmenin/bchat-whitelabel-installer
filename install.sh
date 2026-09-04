#!/usr/bin/env bash
set -Eeuo pipefail

PACKAGE_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PACKAGE_DIR"
[ "$(id -u)" -eq 0 ] || { echo "Execute como root: sudo ./install.sh" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker nao encontrado." >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "OpenSSL nao encontrado." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 nao encontrado." >&2; exit 1; }

[ -f .env ] || cp .env.example .env
random_secret() { openssl rand -hex 32; }
replace_value() {
  local key="$1" value="$2" temporary
  temporary="$(mktemp)"
  awk -v key="$key" -v value="$value" 'index($0,key "=")==1 { print key "=" value; next } { print }' .env > "$temporary"
  mv "$temporary" .env
}
while IFS='=' read -r key value; do
  case "$key" in
    DB_PASS|POSTGRES_PASSWORD|REDIS_PASSWORD|JWT_SECRET|JWT_REFRESH_SECRET|MASTER_KEY|SEAWEEDFS_SECRET_KEY|ASTERISK_AMI_SECRET)
      if [ "$value" = "GENERATE_ME" ] || [ -z "$value" ]; then replace_value "$key" "$(random_secret)"; fi
      ;;
  esac
done < .env

if grep -q 'CHANGE_TO_SERVER_PUBLIC_IP' .env; then
  detected_ip="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  [ -n "$detected_ip" ] && replace_value ASTERISK_PUBLIC_IP "$detected_ip" || echo "Preencha ASTERISK_PUBLIC_IP para usar WebRTC." >&2
fi
chmod 600 .env
mkdir -p secrets/firebase runtime/asterisk-sounds
docker compose config >/dev/null
image="$(awk -F= '$1=="BCHAT_IMAGE" {print substr($0, index($0,"=")+1)}' .env | tr -d "[:space:]")"
[ -n "$image" ] || { echo "BCHAT_IMAGE ausente no .env." >&2; exit 1; }
if ! docker image inspect "$image" >/dev/null 2>&1; then
  echo "Baixando imagem $image..."
  docker pull "$image"
fi
docker compose up -d
echo "BChat iniciado. Codigo: sudo ./bchatctl setup-code"
echo "Configurador local: http://127.0.0.1:${BCHAT_GATEWAY_PORT:-8080}/__bchat"
