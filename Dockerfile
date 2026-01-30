# Hytale dedicated server - non-root, configurable port, downloader or manual bundle
# See README.md and https://support.hytale.com/hc/en-us/articles/45326769420827

FROM debian:bookworm-slim

ARG JAVA_VERSION=25
ENV LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Install base tools and Adoptium repo (as root)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    jq \
    gnupg \
    apt-transport-https \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends temurin-${JAVA_VERSION}-jdk \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user and app layout under /app
RUN useradd -m -d /app -s /bin/bash -u 1000 appuser \
    && mkdir -p /app/bin /app/server /app/data /app/config /app/bundle \
    && chown -R appuser:appuser /app

# Download official Hytale downloader (Linux binary)
RUN curl -fsSL -o /tmp/hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip \
    && unzip -o /tmp/hytale-downloader.zip -d /tmp/hytale-downloader \
    && ( cp /tmp/hytale-downloader/hytale-downloader /app/bin/hytale-downloader || cp /tmp/hytale-downloader/hytale-downloader-linux-amd64 /app/bin/hytale-downloader ) \
    && chmod +x /app/bin/hytale-downloader \
    && rm -rf /tmp/hytale-downloader.zip /tmp/hytale-downloader \
    && chown appuser:appuser /app/bin/hytale-downloader

WORKDIR /app
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh && chown appuser:appuser /app/docker-entrypoint.sh

USER appuser
ENV HOME=/app

VOLUME ["/app/data"]
EXPOSE 5520/udp

ENTRYPOINT ["/app/docker-entrypoint.sh"]
