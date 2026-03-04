#!/bin/bash
set -euo pipefail

if [ ! -f docker-compose.yml ]; then
	echo 'Almost there! You need to run ./init.sh first :)'
	exit 1
fi

docker compose up -d

echo

echo 'Current services status:'
docker compose ps

echo

echo 'Waiting for snikket_server health status...'

SNIKKET_CONTAINER="snikket"
MAX_ATTEMPTS=60
SLEEP_SECONDS=5

# If healthcheck is unavailable (e.g. old compose file/container), report and exit successfully.
if [ "$(docker inspect --format='{{if .State.Health}}yes{{else}}no{{end}}' "$SNIKKET_CONTAINER" 2>/dev/null || echo no)" != "yes" ]; then
	echo 'Healthcheck is not available for snikket_server container.'
	echo 'Readiness status: UNKNOWN'
	exit 0
fi

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
	status="$(docker inspect --format='{{.State.Health.Status}}' "$SNIKKET_CONTAINER" 2>/dev/null || echo unknown)"
	case "$status" in
		healthy)
			echo 'Readiness status: READY (snikket_server is healthy).'
			exit 0
			;;
		unhealthy)
			echo 'Readiness status: NOT READY (snikket_server is unhealthy).'
			echo 'Run `docker compose logs snikket_server` for details.'
			exit 1
			;;
		starting|unknown)
			echo "Attempt ${attempt}/${MAX_ATTEMPTS}: health=${status}, waiting..."
			sleep "$SLEEP_SECONDS"
			;;
		*)
			echo "Attempt ${attempt}/${MAX_ATTEMPTS}: unexpected health state '${status}', waiting..."
			sleep "$SLEEP_SECONDS"
			;;
	esac
done

echo 'Readiness status: TIMEOUT (snikket_server did not become healthy in time).'
echo 'Run `docker compose ps` and `docker compose logs snikket_server` for diagnostics.'
exit 1
