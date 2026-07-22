# media/

Put your **BRB clip** here, named exactly `brb.mp4`.

This is the short "be right back / reconnecting…" video the server loops to your
platforms whenever your phone loses signal — so Twitch/Kick/TikTok keep receiving a
valid feed and never end your stream.

Requirements:
- 1280×720, 60 fps (it gets normalized anyway, but matching avoids a hiccup)
- **Must have an audio track** (silent is fine) so the encoder keeps a steady audio stream

Don't have a clip? Make a 10-second card on the server (needs a `bg.jpg`, or swap in a
black background):

```bash
ffmpeg -loop 1 -i bg.jpg -f lavfi -i anullsrc=r=48000:cl=stereo -t 10 \
  -vf "scale=1280:720,fps=60,drawtext=text='Reconnecting…':fontcolor=white:fontsize=64:x=(w-text_w)/2:y=(h-text_h)/2" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest media/brb.mp4
```

> `media/*.mp4` is gitignored on purpose — your clip stays local, not in the repo.
