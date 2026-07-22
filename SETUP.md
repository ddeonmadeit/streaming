# IRL Multi-Stream + Never-Drop Cloud Server (Moblin → Twitch / Kick / TikTok)

A **free** cloud server that takes one SRT feed from **Moblin** on your iPhone and:

- **Multistreams** it to **Twitch, Kick, and TikTok at the same time**, and
- **Plays a "BRB" video automatically** whenever your phone loses signal — so the
  platforms keep receiving a valid feed and **never end your stream**. When your
  phone reconnects, it switches back to your live feed automatically.

**Target quality:** 720p60 @ 6000 kbps (tune in `.env`).

```
 iPhone (Moblin, SRT out)  ──SRT──▶  [ MediaMTX ingest ]
                                          │  local RTMP
                                          ▼
                                   [ feeder: live? → forward : → BRB loop ]
                                          │  one never-ending FIFO
                                          ▼
                                   [ output: single encoder + tee ]
                                     │        │         │
                                  Twitch     Kick     TikTok
```

---

## 0. What you need

- A free **Oracle Cloud** account (card for ID verification; the Always-Free tier isn't charged).
- Your **Twitch**, **Kick**, and **TikTok** stream URLs + keys.
  - ⚠️ **TikTok** requires **LIVE access** (usually 1,000+ followers) **and** third-party/RTMP
    permission. If your account doesn't have it, TikTok won't connect — Twitch and Kick still will.
- A short **BRB video** (`media/brb.mp4`) — "Be right back / reconnecting…". We make one below if you don't have one.

---

## 1. Create the free Oracle Always-Free VM

1. Sign in to Oracle Cloud → **Compute → Instances → Create instance**.
2. **Shape:** click *Change shape* → **Ampere (ARM)** → **VM.Standard.A1.Flex**.
   Set **4 OCPUs** and **12–24 GB RAM** (all inside the Always-Free allowance).
3. **Image:** Ubuntu 22.04 (or newer).
4. **Networking:** create/assign a public IPv4. Download the **SSH private key**.
5. Create the instance. Note its **public IP** (call it `SERVER_IP`).

### Open the SRT port (two places — both are required on Oracle)

**a) Oracle "Security List" (cloud firewall):**
VCN → your subnet → Security List → **Add Ingress Rule**:
- Source CIDR `0.0.0.0/0`, **IP Protocol: UDP**, **Destination port: 8890**.

**b) The VM's own firewall (Ubuntu images ship with iptables closed):**
SSH in (`ssh -i your-key ubuntu@SERVER_IP`) and run:
```bash
sudo iptables -I INPUT 6 -p udp --dport 8890 -j ACCEPT
sudo netfilter-persistent save        # persist across reboots
```
> Only 8890/udp is exposed. Ports 1935 (RTMP) and 9997 (API) stay bound to localhost.

---

## 2. Install Docker on the VM

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
# log out and back in so the group takes effect, then verify:
docker run --rm hello-world
```

---

## 3. Copy this package to the VM

From your computer, in the folder that contains `docker-compose.yml`:
```bash
scp -i your-key -r . ubuntu@SERVER_IP:/home/ubuntu/irl-stream
ssh -i your-key ubuntu@SERVER_IP
cd irl-stream
```

---

## 4. Configure your keys

```bash
cp .env.example .env
nano .env
```
Fill in:
- `PUBLISH_PASS` — a long secret with **no spaces or colons** (your phone uses this).
- `TWITCH_URL`, `KICK_URL`, `TIKTOK_URL` — full ingest URL **with the stream key appended**
  (each dashboard shows the server URL and the key; join them as shown in the file).
  Leave a platform blank to skip it.

---

## 5. Add your BRB video

Put a clip at `media/brb.mp4`. Don't have one? Make a 10-second "reconnecting" card
(needs a background image `bg.jpg`, or swap in `-f lavfi -i color=c=black:s=1280x720`):
```bash
ffmpeg -loop 1 -i bg.jpg -f lavfi -i anullsrc=r=48000:cl=stereo -t 10 \
  -vf "scale=1280:720,fps=60,drawtext=text='Reconnecting…':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=(h-text_h)/2" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest media/brb.mp4
```
> The BRB **must have an audio track** (the command above adds silent audio) so the
> encoder keeps a consistent audio stream across switches.

---

## 6. Start it

```bash
docker compose up -d --build
docker compose logs -f          # watch it come up; Ctrl-C to stop watching
```
The BRB should start looping to your platforms immediately (you're "live" with the
BRB card). Now connect your phone.

---

## 7. Moblin settings (iPhone)

In Moblin, add a stream with:

| Setting        | Value |
|----------------|-------|
| **Protocol**   | SRT (or SRTLA if you bond connections) |
| **URL**        | `srt://SERVER_IP:8890` |
| **Stream ID**  | `publish:live:publisher:YOUR_PUBLISH_PASS` |
| **Latency**    | `2000` ms (raise to 3000–5000 on shaky cellular) |
| **Resolution / FPS** | 1280×720 · 60 fps |
| **Bitrate**    | ~6000 kbps (enable adaptive bitrate for IRL) |

> If you enabled `srtPublishPassphrase` in `mediamtx.yml`, also set the matching
> **Passphrase** in Moblin.

Go live in Moblin → the server switches from BRB to your feed within ~1–2 s.
Lose signal → it flips back to BRB automatically. **Twitch/Kick/TikTok never drop.**

---

## 8. Everyday use

```bash
docker compose restart restreamer   # after changing .env or the BRB
docker compose down                 # stop everything
docker compose up -d                # start again
docker compose logs -f restreamer   # see live/BRB switches
```

---

## 9. Seeing ALL your chats in one place (you + your friend)

Two free, mobile-friendly options — use both together:

### On your (the streamer's) phone — Moblin's built-in chat
Moblin can pull **multiple platforms' chat into one merged list** inside the app.
Add each platform under Moblin's chat settings (Twitch, Kick, YouTube, etc.) and it
overlays a single combined chat while you stream. (TikTok chat support in Moblin is
limited/varies by version — use option 2 to be sure you catch it.)

### On both phones — Social Stream Ninja (free, web-based)  → **social-stream.ninja**
This is the best free way to share **one combined chat across two phones**:
1. On any browser, open **https://socialstream.ninja** and create a session (you get a
   session ID / links).
2. Connect each platform's chat (Twitch, Kick, TikTok, YouTube) via its per-platform
   instructions — usually you open that platform's live chat page with a Social Stream
   link/extension, or paste your channel. TikTok and Kick are both supported.
3. Open the **"dock"/dashboard** view URL in a mobile browser. It merges every
   platform's messages into one feed, labeled by platform.
4. **Share that same dashboard URL with your friend** — you both open it on your phones
   and see the identical combined chat in real time. No install, no watermark, free.

> Tip: bookmark the Social Stream dashboard link and add it to your phone's home screen
> so it opens like an app. It also has a "featured message" overlay you could add to the
> stream later if you want.

---

## Troubleshooting

- **Phone won't connect:** re-check both firewalls (Oracle Security List *and* iptables),
  and that Stream ID matches `publish:live:publisher:<PUBLISH_PASS>` exactly.
- **A platform is black but others work:** wrong URL/key for that platform, or (TikTok)
  no LIVE access. `onfail=ignore` keeps the others running.
- **Choppy on cellular:** raise Moblin **Latency** to 3000–5000 ms and enable adaptive
  bitrate; drop to 720p30 in `.env` (`FPS=30`, `GOP=60`, `VIDEO_BITRATE=4500k`).
- **CPU maxed on the VM:** lower to 720p30 or use `-preset ultrafast` in `output.sh`.
