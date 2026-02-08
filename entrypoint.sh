#!/usr/bin/env bash
set -euo pipefail

: "${VNC_USER:=owner}"
: "${VNC_PASSWORD:=changeit}"
: "${RESOLUTION:=1920x1080}"

VNC_HOME="${HOME}/.vnc"
mkdir -p "${VNC_HOME}"

# Create a KasmVNC user (HTTP Basic Auth user KasmVNC uses internally)
# Permissions: -w (write) implies read; owner perms are API-level. [5](https://codesandbox.io/p/github/Cdaprod/KasmVNC)
if ! grep -q "^${VNC_USER}:" "${VNC_HOME}/.kasmpasswd" 2>/dev/null; then
  echo "Creating KasmVNC user '${VNC_USER}'..."
  printf '%s\n' "${VNC_PASSWORD}" | vncpasswd -u "${VNC_USER}" -w -r
fi

# Ensure xstartup is our Plasma script
install -m 0755 /opt/kasmvnc/xstartup.plasma "${VNC_HOME}/xstartup"

# Optional per-user resolution override
cat > "${VNC_HOME}/kasmvnc.yaml" <<EOF
desktop:
  resolution:
    width: ${RESOLUTION%x*}
    height: ${RESOLUTION#*x}
EOF

echo "Starting KasmVNC at ${RESOLUTION}..."
exec vncserver -geometry "${RESOLUTION}" -fg
