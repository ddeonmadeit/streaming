#!/usr/bin/env bash
# Start the multistream. Brings the server up and begins broadcasting the BRB
# screen to your platforms. Then open Moblin and tap Go Live to replace the BRB
# with your iPhone camera.
cd "$(dirname "$0")" || exit 1
docker compose up -d
echo
echo "✅ LIVE: the BRB screen is now broadcasting to Twitch + Kick."
echo "   → Open Moblin and tap Go Live to switch to your camera."
echo "   → Run ./stop.sh when you're finished to go fully offline."
