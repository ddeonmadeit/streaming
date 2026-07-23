#!/usr/bin/env bash
# Update the TikTok destination with a fresh key, then apply it.
#
# TikTok issues a NEW stream key every session (it expires after ~2 hours), so
# run this each time before you go live on TikTok. Twitch and Kick are unaffected.
#
# Usage:
#   ./set-tiktok.sh 'rtmp://push.live.tiktok.com/live/YOUR_FRESH_KEY'
#   ./set-tiktok.sh ''      # clear TikTok (stream to Twitch + Kick only)
cd "$(dirname "$0")" || exit 1

if [ -z "${1+set}" ]; then
  echo "Usage: ./set-tiktok.sh 'rtmp://push.live.tiktok.com/live/YOUR_KEY'"
  echo "       ./set-tiktok.sh ''    (to remove TikTok)"
  exit 1
fi
URL="$1"

# Rewrite .env's TIKTOK_URL line safely (no sed escaping issues with the URL).
touch .env
grep -v '^TIKTOK_URL=' .env > .env.tmp
echo "TIKTOK_URL=${URL}" >> .env.tmp
mv .env.tmp .env

echo "TIKTOK_URL set to: ${URL:-(empty)}"

# Recreate the restreamer so it re-reads .env and picks up the new destination.
docker compose up -d --force-recreate restreamer

echo
if [ -n "$URL" ]; then
  echo "✅ TikTok added. Now streaming to Twitch + Kick + TikTok."
else
  echo "✅ TikTok removed. Now streaming to Twitch + Kick only."
fi
