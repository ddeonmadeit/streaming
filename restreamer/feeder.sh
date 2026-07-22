#!/usr/bin/env bash
# Keeps the FIFO fed at ALL times so the output encoder never sees end-of-file:
#   - When your phone's feed is live  -> copy it into the FIFO
#   - When it drops                   -> loop the BRB video into the FIFO
# The write end of the FIFO is held open by this shell (fd 3), so the encoder
# on the other side never gets EOF across a switch — that's the whole trick.
set -u

FIFO=/tmp/program.ts
BRB=/media/brb.mp4
API="http://127.0.0.1:9997/v3/paths/get/live"
SRC="rtmp://127.0.0.1:1935/live"

[ -p "$FIFO" ] || mkfifo "$FIFO"

# Hold the FIFO's write end open for the lifetime of this script.
exec 3>"$FIFO"

live_ready() {
  curl -sf --max-time 2 "$API" 2>/dev/null | grep -Eq '"ready"[[:space:]]*:[[:space:]]*true'
}

# Common MPEG-TS muxer flags: resend PAT/PMT often so the encoder can resync
# quickly after a source switch.
TS_FLAGS=(-mpegts_flags +resend_headers -pat_period 0.2 -flush_packets 1)

while true; do
  if live_ready; then
    echo "[feeder] LIVE present -> forwarding phone feed"
    # Copy the live H.264/AAC straight through; the output stage does the encoding.
    ffmpeg -hide_banner -loglevel warning \
      -fflags +genpts -i "$SRC" \
      -c copy -f mpegts "${TS_FLAGS[@]}" pipe:1 >&3
    echo "[feeder] live feed ended"
  else
    echo "[feeder] NO live -> playing BRB loop"
    # Loop the BRB clip, normalized to the target format, until the phone returns.
    ffmpeg -hide_banner -loglevel warning \
      -re -stream_loop -1 -i "$BRB" \
      -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,fps=60,format=yuv420p" \
      -c:v libx264 -preset veryfast -profile:v high -g 120 -keyint_min 120 \
      -b:v 6000k -maxrate 6000k -bufsize 12000k \
      -c:a aac -ar 48000 -ac 2 -b:a 160k \
      -f mpegts "${TS_FLAGS[@]}" pipe:1 >&3 &
    BRB_PID=$!
    # Poll until the phone reconnects, then stop the BRB and switch back.
    while ! live_ready; do
      if ! kill -0 "$BRB_PID" 2>/dev/null; then break; fi   # BRB ffmpeg died -> restart it
      sleep 1
    done
    kill "$BRB_PID" 2>/dev/null
    wait "$BRB_PID" 2>/dev/null
    echo "[feeder] switching back to live"
  fi
  sleep 0.3
done
