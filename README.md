# 📡 Free IRL Multistream + Never-Drop Server

Stream from your **iPhone (Moblin)** to **Twitch, Kick, and TikTok at the same time** —
for **$0/month**, no watermark — on a cloud server you own. When your phone loses signal,
the server automatically plays a **"be right back" loop** so the platforms **never end your
stream**; when you reconnect, it switches back to your camera.

```
 iPhone (Moblin, SRT out)
        │  SRT · ~2000 ms latency buffer · auto-reconnect
        ▼
 ┌──────────────────────────────────────────────┐
 │   Your free cloud server (Oracle Always-Free) │
 │                                               │
 │   SRT ingest ─► feeder ─► FIFO ─► encoder ─┐  │
 │                   ▲   (live? forward :      │  │
 │   BRB.mp4 loop ───┘    play BRB)            │  │
 │                                             ▼  │
 │        one persistent connection, fanned out via tee
 └──────────────────────────────────────────────┘
        │              │               │
     Twitch          Kick           TikTok
```

## Why it's free (and has no watermark)

Paid services like Restream charge because *their* server duplicates your video. Here **you
run that duplication yourself** on Oracle Cloud's **Always-Free** ARM VM. The FFmpeg `tee`
in [`restreamer/output.sh`](restreamer/output.sh) is the same "send to 3 platforms at once"
that those services sell.

| Piece | Role | Cost |
|-------|------|------|
| [Moblin](https://moblin.mys-lang.org/) | iPhone app, sends SRT | Free / open source |
| Oracle Always-Free ARM VM | Hosts the server 24/7 | **$0 forever** |
| [MediaMTX](https://github.com/bluenviron/mediamtx) + FFmpeg | Ingest, failover, multistream | Free / open source |
| Twitch · Kick · TikTok | Receive the stream | Free to stream to |

## How the "never get dropped" trick works

A named-pipe (FIFO) is **always** fed: your live feed when the phone's connected, the BRB
loop the instant it drops — and the FIFO's write end is held open across the switch, so the
**single persistent encoder** on the other side never sees end-of-file. Because that encoder
keeps one unbroken connection to each platform, the platforms never see your feed stop and
never end the broadcast. Details in [`restreamer/feeder.sh`](restreamer/feeder.sh).

## Quick start

Full, no-prior-knowledge walkthrough: **[SETUP.md](SETUP.md)** — or the visual guide in
[`docs/guide.html`](docs/guide.html).

```bash
# on the server, after installing Docker and uploading this repo:
cp .env.example .env      # paste your stream keys + a publish password
nano .env
# add your BRB clip at media/brb.mp4  (see media/README.md)
docker compose up -d --build
docker compose logs -f
```

Then point Moblin at `srt://SERVER_IP:8890` with Stream ID
`publish:live:publisher:YOUR_PUBLISH_PASS` and go live.

## Daily go-live cheat sheet

Once set up, streaming is two words:

```bash
ssh root@YOUR_SERVER_IP
cd streaming
./golive.sh        # server up + BRB broadcasting to Twitch/Kick
# → open Moblin, tap Go Live (camera replaces the BRB)
# → when finished:
./stop.sh          # fully offline on all platforms
```

Make the scripts runnable once: `chmod +x golive.sh stop.sh`.

> Running `./golive.sh` puts the BRB screen live immediately — only run it when
> you actually intend to stream.

## Repo layout

| Path | What it is |
|------|-----------|
| `docker-compose.yml` | Runs MediaMTX + the restreamer, auto-restart on boot |
| `mediamtx.yml` | SRT ingest + local RTMP config |
| `.env.example` | Template for your keys / publish password (copy to `.env`) |
| `restreamer/feeder.sh` | Live ↔ BRB failover into the FIFO |
| `restreamer/output.sh` | The one persistent encoder + `tee` to all platforms |
| `restreamer/entrypoint.sh` | Supervises both halves |
| `media/` | Drop your `brb.mp4` here |
| `SETUP.md` | Step-by-step guide (Oracle VM → live) |
| `docs/guide.html` | The same guide as a styled page |

## ⚠️ TikTok note

TikTok LIVE needs **1,000+ followers** and separate **third-party (RTMP) access**. Without
it, TikTok won't connect — Twitch and Kick still work regardless. No tool (free or paid) can
bypass this.

## Defaults

720p60 @ ~6000 kbps. Tune resolution/bitrate/FPS in `.env`. On weak cellular, drop to
720p30 and raise Moblin's SRT latency to 3000–5000 ms.
