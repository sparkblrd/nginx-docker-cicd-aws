#!/usr/bin/env bash
# Выполняется НА СЕРВЕРЕ (pipeline копирует его в ~/app/ и запускает по SSH).
#
#   IMAGE=myuser/nginx-docker-cicd-aws TAG=<git-sha> bash deploy.sh
#
# Что делает:
#   1. тянет новый образ;
#   2. перезапускает контейнер через docker compose;
#   3. ждёт статус healthy;
#   4. если не healthy -> откатывается на предыдущий тег и завершается с ошибкой.
set -euo pipefail

: "${IMAGE:?IMAGE is required}"
: "${TAG:?TAG is required}"

HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-60}"
CONTAINER="nginx-docker-cicd-aws"
STATE_FILE=".current_tag"

cd "$(dirname "${BASH_SOURCE[0]}")"

log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*"; }

previous_tag=""
if [[ -f "${STATE_FILE}" ]]; then
  previous_tag="$(cat "${STATE_FILE}")"
fi

start_tag() {
  local tag="$1"
  printf 'IMAGE=%s\nTAG=%s\n' "${IMAGE}" "${tag}" > .env
  docker compose up -d --remove-orphans
}

wait_healthy() {
  local deadline=$((SECONDS + HEALTH_TIMEOUT)) status
  while (( SECONDS < deadline )); do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${CONTAINER}" 2>/dev/null || echo missing)"
    case "${status}" in
      healthy)   return 0 ;;
      unhealthy) return 1 ;;
    esac
    sleep 2
  done
  return 1
}

log "Pulling ${IMAGE}:${TAG}"
docker pull "${IMAGE}:${TAG}"

log "Starting ${IMAGE}:${TAG} (previous: ${previous_tag:-none})"
if start_tag "${TAG}" && wait_healthy; then
  echo "${TAG}" > "${STATE_FILE}"
  log "Deploy OK: ${TAG} is healthy"
  # Чистим старые неиспользуемые образы (старше 3 суток), чтобы не забить диск
  docker image prune -af --filter "until=72h" >/dev/null || true
  exit 0
fi

log "ERROR: ${TAG} did not become healthy"
docker logs --tail 50 "${CONTAINER}" || true

if [[ -n "${previous_tag}" && "${previous_tag}" != "${TAG}" ]]; then
  log "Rolling back to ${previous_tag}"
  start_tag "${previous_tag}"
  if wait_healthy; then
    log "Rollback OK: ${previous_tag} is healthy"
  else
    log "ERROR: rollback to ${previous_tag} also failed, manual intervention required"
  fi
else
  log "No previous version to roll back to"
fi
exit 1
