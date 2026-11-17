#!/usr/bin/env bash
set -euo pipefail

image=${1:?usage: smoke.sh <image>}
redis=redis:8.8.4-alpine@sha256:1273af45b299d2b8b60d0e400d90aa6c2c5b1794f01d6a7ca60ff3ba6e65efb5
tests=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
net=celery-smoke-$$

cleanup() {
  docker rm -f "$net-worker" "$net-redis" > /dev/null 2>&1 || true
  docker network rm "$net" > /dev/null 2>&1 || true
}
trap cleanup EXIT

test "$(docker run --rm "$image" id -u)" != "0"
docker run --rm "$image" celery --version

# Run a real worker against Redis and send it a task the way an application would.
docker network create "$net" > /dev/null
docker run -d --name "$net-redis" --network "$net" --network-alias redis "$redis" > /dev/null
docker run -d --name "$net-worker" --network "$net" -v "$tests:/app:ro" "$image" > /dev/null

result=$(docker run --rm --network "$net" -v "$tests:/app:ro" "$image" \
  python -c 'from tasks import add; print(add.delay(2, 3).get(timeout=60))')
if [ "$result" != "5" ]; then
  docker logs "$net-worker"
  echo "expected 5, got: $result"
  exit 1
fi
docker logs "$net-worker" 2>&1 | grep -q 'celery@.* ready'
