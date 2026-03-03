#!/bin/bash
set -e

echo "===== KasmVNC Docker Entrypoint ====="

# 1. System DBus
if [ ! -e /run/dbus/pid ]; then
  echo "[Init] Starting system DBus..."
  mkdir -p /run/dbus
  dbus-daemon --system --fork || true
fi

# 2. Suppress KDE first-run wizards
mkdir -p /root/.config
printf '[General]\nLastSeenVersion=99.0\n' > /root/.config/plasma-welcomerc

# 3. SSL certificate
if [ ! -f /etc/kasmvnc/certs/self.crt ]; then
  echo "[Init] Generating self-signed TLS cert..."
  mkdir -p /etc/kasmvnc/certs
  openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
    -keyout /etc/kasmvnc/certs/self.key \
    -out    /etc/kasmvnc/certs/self.crt \
    -subj "/C=US/ST=NA/L=NA/O=KasmVNC/OU=Desktop/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
fi

# 4. Pre-create KasmVNC user (suppresses the interactive wizard)
echo "[Init] Pre-creating KasmVNC user..."
mkdir -p /root/.vnc
if [ ! -f /root/.kasmpasswd ]; then
  printf 'headless\nheadless\n' | kasmvncpasswd -u root -w -o 2>/dev/null || true
fi

# 5. Clean stale X11 locks
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# 6. Launch KasmVNC via vncserver with -noxstartup.
#    This runs Xvnc using settings from /etc/kasmvnc/kasmvnc.yaml
#    (which sets websocket_port: 8443 and SSL cert paths).
#    -noxstartup means vncserver starts Xvnc but does NOT try to
#    launch a DE — we do that ourselves below.
echo "[Init] Starting KasmVNC via vncserver -noxstartup..."
vncserver :1 -noxstartup -depth 24 -geometry 1920x1080 --noauth 2>&1 | tee /root/.vnc/vncserver-init.log || true

# Wait for the Xvnc display socket to appear
echo "[Init] Waiting for display :1..."
for i in $(seq 1 30); do
  if [ -S /tmp/.X11-unix/X1 ]; then
    echo "[Init] Display :1 is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "[ERROR] Timed out waiting for display :1. Init log:"
    cat /root/.vnc/vncserver-init.log
    exit 1
  fi
  sleep 1
  echo "[Init] ...waiting ($i/30)"
done

# 7. Start KDE Plasma on display :1
echo "[Init] Starting KDE Plasma..."
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=plasma
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

dbus-launch --exit-with-session startplasma-x11 >> /root/.vnc/plasma.log 2>&1 &
PLASMA_PID=$!
echo "[Init] Plasma PID: $PLASMA_PID"

# 8. Tail logs to keep container alive
sleep 2
echo "[Init] All services started. Tailing logs..."
LOG=$(ls /root/.vnc/*.log 2>/dev/null | grep -v plasma | head -1)
tail -f /root/.vnc/plasma.log &
if [ -n "$LOG" ]; then
  exec tail -f "$LOG"
else
  exec sleep infinity
fi