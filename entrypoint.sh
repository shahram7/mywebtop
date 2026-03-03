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
# 5. Clean stale X11 locks
#############################################
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true

#############################################
# 6. Diagnose what is already on the ports
#############################################
echo "[Init] Checking ports before launch..."
ss -tlnp | grep -E '5901|8443' || echo "[Init] Ports 5901 and 8443 are free."

#############################################
# 7. Launch Xvnc with verbose logging
#############################################
echo "[Init] Starting Xvnc on :1, websocket 8443, rfb 5901..."
Xvnc :1 \
  -geometry 1920x1080 \
  -depth "${VNC_COL_DEPTH:-24}" \
  -rfbport 5901 \
  -websocketPort 8443 \
  -cert /etc/kasmvnc/certs/self.crt \
  -key  /etc/kasmvnc/certs/self.key \
  -FrameRate "${MAX_FRAME_RATE:-60}" \
  -PlainUsers root \
  -SecurityTypes TLSPlain \
  -Log "*:stderr:100" \
  2>&1 | tee /root/.vnc/Xvnc.log &

XVNC_PID=$!
echo "[Init] Xvnc PID: $XVNC_PID"

# Wait for Xvnc socket
echo "[Init] Waiting for Xvnc to be ready..."
for i in $(seq 1 20); do
  if [ -S /tmp/.X11-unix/X1 ]; then
    echo "[Init] Xvnc is ready."
    break
  fi
  sleep 1
  echo "[Init] ...waiting ($i/20)"
done

# Check if Xvnc actually started
if ! kill -0 $XVNC_PID 2>/dev/null; then
  echo "[ERROR] Xvnc exited prematurely. Log:"
  cat /root/.vnc/Xvnc.log
  exit 1
fi

#############################################
# 8. Start KDE Plasma against :1
#############################################
echo "[Init] Starting KDE Plasma..."
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=plasma
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

dbus-launch --exit-with-session startplasma-x11 &>/root/.vnc/plasma.log &

echo "[Init] Plasma started. Tailing logs..."
tail -f /root/.vnc/plasma.log &
exec tail -f /root/.vnc/Xvnc.log