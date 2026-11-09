#!/usr/bin/env bash
set -euo pipefail

: "${CI_PUBLIC_KEY:?Set CI_PUBLIC_KEY to the PUBLIC key used by GitHub Actions}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (use sudo)" >&2
  exit 1
fi

echo ">> Installing Docker"
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y ca-certificates curl
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

echo ">> Creating user ${DEPLOY_USER}"
if ! id "${DEPLOY_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${DEPLOY_USER}"
fi
# NB: членство в группе docker фактически равно root-доступу; для тестового стенда это допустимо
usermod -aG docker "${DEPLOY_USER}"

echo ">> Installing CI public key"
install -d -m 700 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"
AUTH="/home/${DEPLOY_USER}/.ssh/authorized_keys"
touch "${AUTH}"
grep -qxF "${CI_PUBLIC_KEY}" "${AUTH}" || echo "${CI_PUBLIC_KEY}" >> "${AUTH}"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${AUTH}"
chmod 600 "${AUTH}"

echo ">> Done. Test from your machine: ssh -i ci_deploy_key ${DEPLOY_USER}@<EC2_IP> docker ps"
