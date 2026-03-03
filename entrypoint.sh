#!/bin/bash
set -e

echo "===== KasmVNC Docker Entrypoint ====="

#############################################
# 1. System DBus
#############################################
if [ ! -e /run/dbus/pid ]; then
  echo "[Init] Starting system DBus..."
  mkdir -p /run/dbus
  dbus-daemon --system --fork || true
fi

#############################################
# 2. Suppress KDE first-run wizards
#############################################
mkdir -p /root/.config
cat > /root/.config/plasma-welcomerc <<EOF
[General]
LastSeenVersion=99.0
EOF

#############################################
# 3. SSL certificate
#############################################
if [ ! -f /etc/kasmvnc/certs/self.crt ]; then
  echo "[Init] Generating self-signed TLS cert..."
  mkdir -p /etc/kasmvnc/certs
  openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
    -keyout /etc/kasmvnc/certs/self.key \
    -out    /etc/kasmvnc/certs/self.crt \
    -subj "/C=US/ST=NA/L=NA/O=KasmVNC/OU=Desktop/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
fi

#############################################
# 4. Pre-create KasmVNC user
#############################################
echo "[Init] Pre-creating KasmVNC user..."
mkdir -p /root/.vnc
if [ ! -f /root/.kasmpasswd ]; then
  printf 'headless\nheadless\n' | kasmvncpasswd -u root -w -o 2>/dev/null || true
fi

#############################################
# 5. Clean ALL stale X11 locks and sockets
#    Use :99 to avoid any host display clash
#############################################
DISPLAY_NUM=99
echo "[Init] Cleaning stale locks for display :${DISPLAY_NUM}..."
rm -f /tmp/.X${DISPLAY_NUM}-lock
rm -f /tmp/.X11-unix/X${DISPLAY_NUM}
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

#############################################
# 6. Launch Xvnc on :99
#############################################
echo "[Init] Starting Xvnc on :${DISPLAY_NUM}, websocket 8443, rfb 5901..."
Xvnc :${DISPLAY_NUM} \
  -geometry 1920x1080 \
  -depth "${VNC_COL_DEPTH:-24}" \
  -rfbport 5901 \
  -websocketPort 8443 \
  -cert /etc/kasmvnc/certs/self.crt \
  -key  /etc/kasmvnc/certs/self.key \
  -FrameRate "${MAX_FRAME_RATE:-60}" \
  -PlainUsers root \
  -SecurityTypes TLSPlain \
  2>/root/.vnc/Xvnc.log &

XVNC_PID=$!
echo "[Init] Xvnc PID: $XVNC_PID"

# Wait for Xvnc Unix socket to appear
echo "[Init] Waiting for Xvnc to be ready..."
for i in $(seq 1 30); do
  if [ -S /tmp/.X11-unix/X${DISPLAY_NUM} ]; then
    echo "[Init] Xvnc is ready."
    break
  fi
  # Bail early if Xvnc already died
  if ! kill -0 $XVNC_PID 2>/dev/null; then
    echo "[ERROR] Xvnc exited prematurely. Log:"
    cat /root/.vnc/Xvnc.log
    exit 1
  fi
  sleep 1
  echo "[Init] ...waiting ($i/30)"
done

#############################################
# 7. Start KDE Plasma against :99
#############################################
echo "[Init] Starting KDE Plasma..."
export DISPLAY=:${DISPLAY_NUM}
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=plasma
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

dbus-launch --exit-with-session startplasma-x11 &>/root/.vnc/plasma.log &

echo "[Init] Plasma started. Tailing logs..."
tail -f /root/.vnc/plasma.log &
exec tail -f /root/.vnc/Xvnc.log