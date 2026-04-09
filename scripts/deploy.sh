#!/usr/bin/env bash
set -euo pipefail

# Deploy a previously built image into a named target environment.
#
# This script is intentionally small because the assessment focuses on release flow,
# not on a full production orchestration stack. In a larger implementation, the same
# deployment contract would typically be executed by a platform-specific tool such as
# Kubernetes, Helm, Terraform, or a cloud deployment service.

if [[ $# -ne 5 ]]; then
  echo "Usage: $0 <environment> <image-ref> <env-file> <container-name> <host-port>"
  exit 1
fi

ENVIRONMENT="$1"
IMAGE_REF="$2"
ENV_FILE="$3"
CONTAINER_NAME="$4"
HOST_PORT="$5"
APP_PORT="${APP_PORT:-3000}"
RELEASE_VERSION="${IMAGE_REF##*:}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Environment file not found: $ENV_FILE"
  exit 1
fi

echo "Deploying $IMAGE_REF to $ENVIRONMENT using $ENV_FILE"

# Stop and remove the previous container instance so the new release becomes authoritative.
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

# Pass only runtime configuration here. The release artifact itself stays the same
# across environments, which keeps promotion cleaner and more auditable.
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  -e "RELEASE_VERSION=${RELEASE_VERSION}" \
  --label "app.environment=${ENVIRONMENT}" \
  --label "app.release-version=${RELEASE_VERSION}" \
  -p "${HOST_PORT}:${APP_PORT}" \
  "$IMAGE_REF"

ATTEMPTS=20
SLEEP_SECONDS=3
for ((i=1; i<=ATTEMPTS; i++)); do
  HEALTH_STATUS="$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' "$CONTAINER_NAME" 2>/dev/null || true)"
  if [[ "$HEALTH_STATUS" == "healthy" || "$HEALTH_STATUS" == "unknown" ]]; then
    echo "Container health status is $HEALTH_STATUS on attempt $i"
    echo "Deployment complete: container=$CONTAINER_NAME environment=$ENVIRONMENT hostPort=$HOST_PORT releaseVersion=$RELEASE_VERSION"
    exit 0
  fi

  if [[ "$HEALTH_STATUS" == "unhealthy" ]]; then
    echo "Container became unhealthy. Recent logs:"
    docker logs --tail 50 "$CONTAINER_NAME" || true
    exit 1
  fi

  echo "Waiting for container health check ($i/$ATTEMPTS)..."
  sleep "$SLEEP_SECONDS"
done

echo "Container did not become healthy in time. Recent logs:"
docker logs --tail 50 "$CONTAINER_NAME" || true
exit 1
