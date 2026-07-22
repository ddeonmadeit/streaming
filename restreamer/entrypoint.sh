#!/usr/bin/env bash
# Supervises the two halves of the pipeline:
#   feeder.sh  -> keeps a continuous MPEG-TS stream flowing into the FIFO
#                 (your live feed when present, the BRB loop when it drops)
#   output.sh  -> ONE persistent encoder reading the FIFO, pushing to all
#                 platforms. It must never exit, or Twitch would drop you.
set -u

FIFO=/tmp/program.ts
[ -p "$FIFO" ] || mkfifo "$FIFO"

echo "[entrypoint] starting persistent output encoder..."
/app/output.sh &
OUT_PID=$!

echo "[entrypoint] starting failover feeder..."
/app/feeder.sh &
FEED_PID=$!

# If either half dies, restart just that half. The output encoder restarting is
# the only case that briefly drops the platform connections, so it's last-resort.
while true; do
  if ! kill -0 "$OUT_PID" 2>/dev/null; then
    echo "[entrypoint] output encoder exited — restarting"
    /app/output.sh &
    OUT_PID=$!
  fi
  if ! kill -0 "$FEED_PID" 2>/dev/null; then
    echo "[entrypoint] feeder exited — restarting"
    /app/feeder.sh &
    FEED_PID=$!
  fi
  sleep 2
done
