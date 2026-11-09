#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE:?Set IMAGE, e.g. IMAGE=myuser/nginx-docker-cicd-aws}"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

TAG="${TAG:-$(git rev-parse HEAD 2>/dev/null || echo dev)}"
PUSH="${PUSH:-0}"

echo ">> Building ${IMAGE}:${TAG}"
docker build \
  --build-arg GIT_SHA="${TAG}" \
  -t "${IMAGE}:${TAG}" \
  -t "${IMAGE}:latest" \
  .

if [[ "${PUSH}" == "1" ]]; then
  echo ">> Pushing ${IMAGE}:${TAG} and ${IMAGE}:latest"
  docker push "${IMAGE}:${TAG}"
  docker push "${IMAGE}:latest"
fi

echo ">> Done: ${IMAGE}:${TAG}"
