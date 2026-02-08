#!/usr/bin/env bash
set -euo pipefail

: "${VNC_USER:=owner}"
: "${VNC_PASSWORD:=}"
: "${RESOLUTION:=1920x1080}"

if [ -z "${VNC_PASSWORD}" ]; then
  echo "ERROR: VNC_PASSWORD is not set. Pass -e VNC_PASSWORD=... at runtime." >&2
  exit 1
fi

VNC_HOME="${HOME}/.vnc"
mkdir -p "${VNC_HOME}"

# Create KasmVNC user (HTTP Basic Auth) if missing; grant read+write (-w -r).
if ! grep -q "^${VNC_USER}:" "${VNC_HOME}/.kasmpasswd" 2>/dev/null; then
  printf '%s\n' "${VNC_PASSWORD}" | vncpasswd -u "${VNC_USER}" -w -r
fi

# Ensure our KDE startup is used
install -m 0755 /opt/kasmvnc/xstartup.plasma "${VNC_HOME}/xstartup"

# Optional per-user resolution override
cat > "${VNC_HOME}/kasmvnc.yaml" <<EOF
desktop:
  resolution:
    width: ${RESOLUTION%x*}
    height: ${RESOLUTION#*x}
EOF

echo "Starting KasmVNC at ${RESOLUTION} (TLS enabled)..."
exec vncserver -geometry "${RESOLUTION}" -fg
