# Hytale Server (Docker Compose)

Run a dedicated [Hytale](https://hytale.com) server with Docker Compose. Designed to run as a **non-root user** from any Linux account; all persistent data lives in the same directory as `docker-compose.yml` (e.g. `~/hytale-server`). Supports automatic download of server files or a manual bundle, configurable port, and optional world config overrides.

- **Reference:** [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)

---

## Prerequisites

- **Docker** with Compose (or **Podman** with `podman-compose`). Install for your OS:
  - **Windows:** [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/) (includes Compose; WSL2 required)
  - **macOS:** [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
  - **Linux:** [Install Docker Engine](https://docs.docker.com/engine/install/) then [Install the Compose plugin](https://docs.docker.com/compose/install/linux/) (e.g. `sudo apt install docker.io docker-compose-plugin` on Debian/Ubuntu)
- Your **administrators** must expose/forward the **UDP port** you use (default `5520`) on the host and firewall

Verify Compose is available: `docker compose version`

---

## I have nothing installed

Minimal steps from a clean machine:

1. **Install Docker** (with Compose) for your OS using the links under [Prerequisites](#prerequisites).
2. **Get this project:** `git clone <repo-url> && cd hytale-server` (or download the repo as a ZIP and extract it, then `cd` into that folder).
3. **Create dirs and start:** `mkdir -p data config && docker compose up -d --build`
4. **First-time auth:** `docker compose logs -f`, then in the Hytale console run `/auth login device` and complete the browser flow.

Ensure your host/router allows **UDP port 5520** (or whatever port you configure).

---

## Quick setup

From the directory that contains `docker-compose.yml` (e.g. `~/hytale-server`):

```bash
mkdir -p data config
docker compose up -d
```

Build and run in one step:

```bash
docker compose up -d --build
```

Edit `docker-compose.yml` to set a custom port, manual mode, or world overrides (see below).

---

## Directory layout

Run `docker compose` from the project directory. Relative paths in `docker-compose.yml` refer to that directory:

| Host path (relative to project) | Container path | Purpose |
|--------------------------------|----------------|---------|
| `./data` | `/app/data` | Worlds, logs, mods, auth, server config (read-write) |
| `./config` | `/app/config` | Optional world overrides file (read-only) |
| `./bundle` | `/app/bundle` | Manual mode: pre-downloaded `Server/` and `Assets.zip` |

---

## Environment variables

Set these under `environment` in `docker-compose.yml`. Only uncomment and change what you need.

### Acquisition mode

| Variable | Default | Description |
|----------|---------|-------------|
| `HYTALE_DOWNLOAD_MODE` | `downloader` | `downloader` = use hytale-downloader; `manual` = use mounted bundle |
| `HYTALE_FORCE_DOWNLOAD` | (unset) | If set, re-download in downloader mode even if files exist |
| `HYTALE_PATCHLINE` | (unset) | e.g. `pre-release` for hytale-downloader |
| `HYTALE_SKIP_UPDATE_CHECK` | (unset) | Set to `true` to skip downloader update check |
| `HYTALE_SERVER_BUNDLE_PATH` | `/app/bundle` | Path to manual bundle (must contain `Assets.zip` and `Server/HytaleServer.jar`) |

### Networking (port)

| Variable | Default | Description |
|----------|---------|-------------|
| `HYTALE_BIND_ADDR` | (see below) | Full `host:port` (e.g. `0.0.0.0:6000`) |
| `HYTALE_PORT` | `5520` | Port only; bind is `0.0.0.0:${HYTALE_PORT}`. Must match `ports` in `docker-compose.yml`. |

### Java & server

| Variable | Default | Description |
|----------|---------|-------------|
| `HYTALE_JAVA_XMS` | `2G` | JVM initial heap |
| `HYTALE_JAVA_XMX` | `4G` | JVM max heap |
| `HYTALE_AUTH_MODE` | `authenticated` | `authenticated` or `offline` |
| `HYTALE_EXTRA_ARGS` | (unset) | Extra args for HytaleServer.jar (e.g. `--disable-sentry --backup --backup-dir /app/data/backups`) |

### World config overrides

| Variable | Default | Description |
|----------|---------|-------------|
| `HYTALE_WORLD_CONFIG_OVERRIDE_FILE` | (unset) | Path to JSON file; keys override existing world `config.json` (e.g. `/app/config/world-config.override.json`) |
| `HYTALE_WORLD_CONFIG_ALLOW_ID_OVERRIDE` | `false` | Set to `true` to allow overriding `UUID` and `Seed` (not recommended) |

Only keys present in the override file are applied; all other values keep the server-generated defaults. Overrides run at container startup for every world under `/app/data/universe/worlds/`. New worlds get overrides on the next restart.

---

## Customisation (docker-compose.yml)

### Custom port

1. In `docker-compose.yml`, set `ports` to e.g. `"6000:6000/udp"`.
2. Under `environment`, uncomment and set: `HYTALE_PORT: "6000"`.

### Manual mode (when hytale-downloader is not usable)

1. On a machine that can run the downloader, copy `Server/` and `Assets.zip` into `bundle/`.
2. In `docker-compose.yml`, uncomment the volume: `- ./bundle:/app/bundle:ro`.
3. Under `environment`, set: `HYTALE_DOWNLOAD_MODE: manual`, `HYTALE_SERVER_BUNDLE_PATH: /app/bundle`.

### World config overrides

1. Create e.g. `config/world-config.override.json` with only the keys you want to change (e.g. `{"IsPvpEnabled": true, "IsFallDamageEnabled": false}`).
2. Under `environment`, set: `HYTALE_WORLD_CONFIG_OVERRIDE_FILE: /app/config/world-config.override.json`.

---

## First-time authentication

With `HYTALE_AUTH_MODE=authenticated` (default), the server must be authenticated once:

1. Start: `docker compose up -d`
2. Attach to logs or the server console: `docker compose logs -f` (or use your tooling to access the Hytale console).
3. In the Hytale console, run: `/auth login device`
4. Complete the device code flow in your browser.
5. Auth data is stored in `./data`, so it persists across restarts.

---

## Building

From the project directory:

```bash
docker compose build
```

Or build and start:

```bash
docker compose up -d --build
```

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| Download fails (unsupported arch, network) | Use **manual mode**: put `Server/` and `Assets.zip` in `bundle/`, add volume `./bundle:/app/bundle:ro`, and set `HYTALE_DOWNLOAD_MODE: manual`, `HYTALE_SERVER_BUNDLE_PATH: /app/bundle` in `docker-compose.yml`. |
| Port not working | Ensure `ports` in `docker-compose.yml` matches `HYTALE_PORT` (e.g. `"6000:6000/udp"` and `HYTALE_PORT: "6000"`), and that the host firewall/router forwards that **UDP** port. |
| Auth lost after restart | Use the same project directory and `./data` volume; do not remove or replace the `data` folder. |
| World overrides not applied | Put the override file in `config/` and set `HYTALE_WORLD_CONFIG_OVERRIDE_FILE: /app/config/world-config.override.json`. Overrides run only at startup for worlds that already exist. |

---

## License / Hytale

Hytale and related assets are property of Hypixel Studios. This image is an unofficial way to run the official server in Docker; follow the [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827) and Hypixel's terms.

---

*Disclaimer: This repository is developed using [Cursor](https://cursor.com), and it is intended for personal and private use by me.*
