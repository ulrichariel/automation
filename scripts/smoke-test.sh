#!/usr/bin/env bash
set -euo pipefail

# Verify that a promoted deployment is serving the expected environment/status metadata.
#
# This script deliberately checks the response payload, not only the HTTP status, so the
# pipeline proves that the right release reached the right environment.

if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "Usage: $0 <url> <expected-environment> [expected-release-version] [expected-status]"
  exit 1
fi

URL="$1"
EXPECTED_ENV="$2"
EXPECTED_RELEASE_VERSION="${3:-}"
EXPECTED_STATUS="${4:-ready}"
ATTEMPTS=20
SLEEP_SECONDS=3

for ((i=1; i<=ATTEMPTS; i++)); do
  RESPONSE="$(curl -fsS "$URL" || true)"

  if [[ -n "$RESPONSE" ]]; then
    STATUS="$(echo "$RESPONSE" | jq -r '.status // empty')"
    ENV="$(echo "$RESPONSE" | jq -r '.environment // empty')"
    VERSION="$(echo "$RESPONSE" | jq -r '.version // empty')"

    STATUS_MATCH=false
    ENV_MATCH=false
    VERSION_MATCH=false

    [[ "$STATUS" == "$EXPECTED_STATUS" ]] && STATUS_MATCH=true
    [[ -z "$ENV" || "$ENV" == "$EXPECTED_ENV" ]] && ENV_MATCH=true
    [[ -z "$EXPECTED_RELEASE_VERSION" || "$VERSION" == "$EXPECTED_RELEASE_VERSION" ]] && VERSION_MATCH=true

    if $STATUS_MATCH && $ENV_MATCH && $VERSION_MATCH; then
      echo "Smoke test passed on attempt $i: $RESPONSE"
      exit 0
    fi
  fi

  echo "Smoke test attempt $i/$ATTEMPTS failed. Waiting ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

echo "Smoke test failed after ${ATTEMPTS} attempts."
exit 1