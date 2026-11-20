#!/bin/sh
set -e

SERVER="${1:-}"
TOKEN="${2:-}"
INTERVAL="${3:-1}"
LOG="${4:-no}"
BIN_NAME="${BIN_NAME:-monitor-agent}"
SVC_NAME="${SVC_NAME:-$BIN_NAME}"
INSTALL_DIR="${INSTALL_DIR:-/opt/monitor}"

if [ -z "$SERVER" ] || [ -z "$TOKEN" ]; then
  echo "usage: sh install.sh <server> <token> [interval] [log:yes|no]"
  echo "  env: BIN_NAME=... SVC_NAME=... INSTALL_DIR=..."
  exit 1
fi

case "$(uname -m)" in
  x86_64)  BIN_ARCH="x86_64" ;;
  aarch64) BIN_ARCH="aarch64" ;;
  *) echo "unsupported arch: $(uname -m)"; exit 1 ;;
esac

mkdir -p "$INSTALL_DIR"
TMP_BIN="${INSTALL_DIR}/.${BIN_NAME}.download"
trap 'rm -f "$TMP_BIN"' EXIT INT TERM

if [ -n "$BINARY" ]; then
  cp "$BINARY" "$TMP_BIN"
else
  echo "Downloading agent ..."
  curl -fsSL "${SERVER%/}/agent/${BIN_ARCH}" -o "$TMP_BIN"
fi
chmod +x "$TMP_BIN"
mv -f "$TMP_BIN" "${INSTALL_DIR}/${BIN_NAME}"
trap - EXIT INT TERM

cat > "${INSTALL_DIR}/agent.env" <<EOF
MONITOR_SERVER=${SERVER}
MONITOR_TOKEN=${TOKEN}
EOF
chmod 600 "${INSTALL_DIR}/agent.env"

# 停掉旧的（有就停，没有就跳过）
[ -f "/run/${SVC_NAME}.pid" ] && kill "$(cat /run/${SVC_NAME}.pid)" 2>/dev/null || true

set -a; . "${INSTALL_DIR}/agent.env"; set +a
if [ "$LOG" = "yes" ]; then
  nohup setsid "${INSTALL_DIR}/${BIN_NAME}" --interval "$INTERVAL" \
    >>"/var/log/${BIN_NAME}.log" 2>&1 &
else
  nohup setsid "${INSTALL_DIR}/${BIN_NAME}" --interval "$INTERVAL" \
    >/dev/null 2>&1 &
fi
echo $! > "/run/${SVC_NAME}.pid"

echo "Done. pid $(cat /run/${SVC_NAME}.pid)"
