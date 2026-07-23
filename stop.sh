#!/usr/bin/env bash
# Stop the multistream and go fully offline on all platforms.
cd "$(dirname "$0")" || exit 1
docker compose down
echo
echo "🛑 OFFLINE: stopped broadcasting on all platforms."
