#!/bin/bash
set -e

echo "===== KasmVNC Docker Entrypoint ====="

#############################################
# 1. Ensure DBus is available
#############################################
if [ ! -e /run/dbus/pid ]; then
  echo "[Init] Starting system DBus..."
  mkdir -p /run/dbus
  dbus-daemon --system --fork || true
fi

# Create a DBus session address
export DBUS_SESSION_BUS_ADDRESS=$(dbus-launch --sh-syntax \
  | grep DBUS_SESSION_BUS_ADDRESS \
  | cut -d= -f2- \
  | tr -d "'" \
  | tr -d ';') || true


#############################################
# 2. First-run KDE configuration
#############################################
mkdir -p /root/.config
cat > /root/.config/plasma-welcomerc <<EOF
[General]
LastSeenVersion=99.0
EOF


#############################################
# 3. Ensure KasmVNC config folder exists
#    (important if /etc/kasmvnc is a Docker volume)
#############################################
if [ ! -d /etc/kasmvnc ]; then
  echo "[Init] Creating /etc/kasmvnc directory..."
  mkdir -p /etc/kasmvnc
fi


#############################################
# 4. Auto-generate SSL certificate if missing
#############################################
if [ ! -f /etc/kasmvnc/certs/self.crt ]; then
  echo "[Init] No SSL certificate detected — generating self-signed cert..."
  mkdir -p /etc/kasmvnc/certs

  openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
    -keyout /etc/kasmvnc/certs/self.key \
    -out /etc/kasmvnc/certs/self.crt \
    -subj "/C=US/ST=State/L=City/O=KasmVNC/OU=Desktop/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
fi


#############################################
# 5. Disable KasmVNC user wizard forever
#############################################
if [ ! -f /etc/kasmvnc/users.conf ]; then
  echo "[Init] Creating default users.conf to prevent interactive wizard..."
  cat > /etc/kasmvnc/users.conf <<EOF
users:
  - username: root
    permissions:
      - write
EOF
fi


#############################################
# 6. Disable KasmVNC password authentication
#    (Cloudflare Zero Trust handles auth)
#############################################
echo "[Init] Disabling VNC password authentication..."
mkdir -p /root/.vnc
touch /root/.vnc/passwd
chmod 600 /root/.vnc/passwd


#############################################
# 7. Clean up stale X11 locks
#############################################
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true


#############################################
# 8. Launch KasmVNC server
#############################################
echo "Starting KasmVNC on port 8443 with auth disabled..."

exec kasmvncserver :1 \
  --noauth \
  --skipConfigWizard \
  --skipUserAuth \
  -select-de kde \
  -geometry 1920x1080 \
  -depth "${VNC_COL_DEPTH:-24}" \
  -rfbport 8443 \
  -websocketPort 8443 \
  -cert /etc/kasmvnc/certs/self.crt \
  -key /etc/kasmvnc/certs/self.key \
  -FrameRate "${MAX_FRAME_RATE:-60}" \
  -fg \
  2>&1