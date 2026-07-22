FROM debian:stable-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg curl ca-certificates bash \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh feeder.sh output.sh /app/
RUN chmod +x /app/*.sh

ENTRYPOINT ["/app/entrypoint.sh"]
