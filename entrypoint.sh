#!/bin/bash
set -e

# Allow custom VNC password via environment variable
if [ -n "${VNC_PASSWORD}" ]; then
    echo "Setting custom VNC password..."
    echo "${VNC_PASSWORD}" | vncpasswd -u root -w -r 2>/dev/null || \
    printf "${VNC_PASSWORD}\n${VNC_PASSWORD}\n" | vncpasswd /root/.vnc/passwd
fi

# Set resolution from env
RESOLUTION="${VNC_RESOLUTION:-1920x1080}"

# Clean up any stale lock files
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# Configure KDE to not show first-run wizard
mkdir -p /root/.config
cat > /root/.config/plasma-welcomerc <<EOF
[General]
LastSeenVersion=99.0
EOF

# Ensure dbus is running
if [ ! -e /run/dbus/pid ]; then
    mkdir -p /run/dbus
    dbus-daemon --system --fork 2>/dev/null || true
fi

export DBUS_SESSION_BUS_ADDRESS=$(dbus-launch --sh-syntax 2>/dev/null | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2- | tr -d "'" | tr -d ';') || true

echo "Starting KasmVNC on port 8443 with resolution ${RESOLUTION}..."

exec vncserver :1 \
    -select-de kde \
    -geometry "${RESOLUTION}" \
    -depth "${VNC_COL_DEPTH:-24}" \
    -rfbport 8443 \
    -websocketPort 8443 \
    -cert /etc/kasmvnc/certs/self.crt \
    -key /etc/kasmvnc/certs/self.key \
    -FrameRate "${MAX_FRAME_RATE:-60}" \
    ${VNCOPTIONS} \
    -fg \
    2>&1
