#!/bin/bash
set -e

# Resolve bind address: HYTALE_BIND_ADDR wins, else HYTALE_PORT, else 0.0.0.0:5520
if [ -n "${HYTALE_BIND_ADDR}" ]; then
  BIND_ADDR="${HYTALE_BIND_ADDR}"
elif [ -n "${HYTALE_PORT}" ]; then
  BIND_ADDR="0.0.0.0:${HYTALE_PORT}"
else
  BIND_ADDR="0.0.0.0:5520"
fi

# Ensure directories exist
mkdir -p /app/server /app/data/universe/worlds /app/data/logs /app/data/mods /app/config /app/bundle

# --- Acquire server files ---
MODE="${HYTALE_DOWNLOAD_MODE:-downloader}"

if [ "$MODE" = "manual" ]; then
  BUNDLE="${HYTALE_SERVER_BUNDLE_PATH:-/app/bundle}"
  if [ ! -f "${BUNDLE}/Assets.zip" ] || [ ! -f "${BUNDLE}/Server/HytaleServer.jar" ]; then
    echo "Manual mode: missing server bundle. Ensure ${BUNDLE} contains Assets.zip and Server/HytaleServer.jar (mount with -v host_path:${BUNDLE})"
    exit 1
  fi
  echo "Using manual bundle at ${BUNDLE}"
  cp -a "${BUNDLE}/Assets.zip" /app/server/ 2>/dev/null || true
  cp -a "${BUNDLE}/Server" /app/server/ 2>/dev/null || true
  if [ ! -f /app/server/Assets.zip ]; then
    ln -sf "${BUNDLE}/Assets.zip" /app/server/Assets.zip 2>/dev/null || cp -a "${BUNDLE}/Assets.zip" /app/server/
  fi
  if [ ! -f /app/server/Server/HytaleServer.jar ]; then
    ln -sf "${BUNDLE}/Server" /app/server/Server 2>/dev/null || cp -a "${BUNDLE}/Server" /app/server/
  fi
else
  # Downloader mode
  if [ ! -f /app/server/Server/HytaleServer.jar ] || [ ! -f /app/server/Assets.zip ] || [ -n "${HYTALE_FORCE_DOWNLOAD}" ]; then
    DOWNLOAD_PATH="${HYTALE_DOWNLOAD_PATH:-/app/server/game.zip}"
    OPTS=()
    [ -n "${HYTALE_PATCHLINE}" ] && OPTS+=( -patchline "${HYTALE_PATCHLINE}" )
    [ "${HYTALE_SKIP_UPDATE_CHECK}" = "true" ] && OPTS+=( -skip-update-check )
    echo "Downloading server files..."
    if ! /app/bin/hytale-downloader -download-path "${DOWNLOAD_PATH}" "${OPTS[@]}"; then
      echo "Download failed. Use HYTALE_DOWNLOAD_MODE=manual and mount a bundle (see README)."
      exit 1
    fi
    echo "Extracting..."
    unzip -o -q "${DOWNLOAD_PATH}" -d /app/server
    rm -f "${DOWNLOAD_PATH}"
    # If zip had a single top-level dir (e.g. game/), move contents up
    for dir in /app/server/*/; do
      if [ -d "$dir" ] && [ -f "${dir}Assets.zip" ] && [ -d "${dir}Server" ]; then
        mv "${dir}"* /app/server/ 2>/dev/null || true
        rmdir "$dir" 2>/dev/null || true
        break
      fi
    done
  fi
fi

if [ ! -f /app/server/Server/HytaleServer.jar ] || [ ! -f /app/server/Assets.zip ]; then
  echo "Missing HytaleServer.jar or Assets.zip in /app/server. Check download or manual bundle."
  exit 1
fi

# --- World config overrides (optional) ---
OVERRIDE_FILE="${HYTALE_WORLD_CONFIG_OVERRIDE_FILE}"
ALLOW_ID_OVERRIDE="${HYTALE_WORLD_CONFIG_ALLOW_ID_OVERRIDE:-false}"

if [ -n "${OVERRIDE_FILE}" ] && [ -f "${OVERRIDE_FILE}" ]; then
  WORLDS_DIR="/app/data/universe/worlds"
  for world_config in "${WORLDS_DIR}"/*/config.json; do
    [ -f "$world_config" ] || continue
    world_name=$(basename "$(dirname "$world_config")")
    tmp_config="${world_config}.tmp.$$"
    if [ "$ALLOW_ID_OVERRIDE" = "true" ]; then
      jq -s '.[0] * .[1]' "$world_config" "$OVERRIDE_FILE" > "$tmp_config"
    else
      jq -s '.[0] as $orig | (.[0] * .[1]) | .UUID = $orig.UUID | .Seed = $orig.Seed' "$world_config" "$OVERRIDE_FILE" > "$tmp_config"
    fi
    if [ -s "$tmp_config" ]; then
      mv "$tmp_config" "$world_config"
      echo "Applied world config overrides to $world_name"
    else
      rm -f "$tmp_config"
    fi
  done
fi

# --- Build Java command ---
JAVA_OPTS=(
  -Xms"${HYTALE_JAVA_XMS:-2G}"
  -Xmx"${HYTALE_JAVA_XMX:-4G}"
)
[ -f /app/server/HytaleServer.aot ] && JAVA_OPTS+=( -XX:AOTCache=/app/server/HytaleServer.aot )
[ -f /app/server/Server/HytaleServer.aot ] && JAVA_OPTS+=( -XX:AOTCache=/app/server/Server/HytaleServer.aot )

SERVER_OPTS=(
  -jar /app/server/Server/HytaleServer.jar
  --assets /app/server/Assets.zip
  --bind "$BIND_ADDR"
  --auth-mode "${HYTALE_AUTH_MODE:-authenticated}"
)

# Run from data dir so config.json, universe/, etc. are in CWD (per Hytale expectations)
cd /app/data
exec java "${JAVA_OPTS[@]}" "${SERVER_OPTS[@]}" ${HYTALE_EXTRA_ARGS:+ $HYTALE_EXTRA_ARGS}
