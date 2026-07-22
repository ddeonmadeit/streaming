#!/usr/bin/env bash
# THE persistent encoder. Reads the never-ending FIFO and pushes ONE encoded
# feed to Twitch + Kick + TikTok at once (the "tee" muxer). As long as the FIFO
# has data, this process — and therefore the connection to each platform —
# stays open, so the platforms never see your feed stop.
set -u

FIFO=/tmp/program.ts

# Defaults (overridable from .env)
VIDEO_BITRATE="${VIDEO_BITRATE:-6000k}"
MAXRATE="${MAXRATE:-6000k}"
BUFSIZE="${BUFSIZE:-12000k}"
AUDIO_BITRATE="${AUDIO_BITRATE:-160k}"
WIDTH="${WIDTH:-1280}"
HEIGHT="${HEIGHT:-720}"
FPS="${FPS:-60}"
GOP="${GOP:-120}"

# Build the tee target list, skipping any platform left blank in .env.
# onfail=ignore -> if one platform rejects/drops, the others keep going.
TARGETS=""
add_target() { [ -n "$1" ] && TARGETS="${TARGETS}${TARGETS:+|}[f=flv:onfail=ignore]$1"; }
add_target "${TWITCH_URL:-}"
add_target "${KICK_URL:-}"
add_target "${TIKTOK_URL:-}"

if [ -z "$TARGETS" ]; then
  echo "[output] No platform URLs set in .env — nothing to stream to." >&2
  sleep 10
  exit 1
fi

echo "[output] encoding ${WIDTH}x${HEIGHT}@${FPS} -> $(echo "$TARGETS" | tr '|' '\n' | wc -l) platform(s)"

# -use_wallclock_as_timestamps keeps PTS monotonic across a source switch, so
# the encoder never chokes on the discontinuity between live feed and BRB.
exec ffmpeg -hide_banner -loglevel warning \
  -fflags +genpts+igndts+discardcorrupt -err_detect ignore_err \
  -use_wallclock_as_timestamps 1 \
  -i "$FIFO" \
  -filter_complex "[0:v]scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2,fps=${FPS},format=yuv420p[v]" \
  -map "[v]" -map 0:a? \
  -af "aresample=async=1:first_pts=0" \
  -c:v libx264 -preset veryfast -profile:v high \
  -b:v "$VIDEO_BITRATE" -maxrate "$MAXRATE" -bufsize "$BUFSIZE" \
  -g "$GOP" -keyint_min "$GOP" -sc_threshold 0 \
  -c:a aac -ar 48000 -ac 2 -b:a "$AUDIO_BITRATE" \
  -f tee -flags +global_header "$TARGETS"
