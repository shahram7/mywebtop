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
# 4. Pre-create KasmVNC user (suppresses
#    the interactive user-creation wizard)
#############################################
echo "[Init] Pre-creating KasmVNC user..."
if [ ! -f /root/.kasmpasswd ]; then
  printf 'headless\nheadless\n' | kasmvncpasswd -u root -w -o 2>/dev/null || true
fi


#############################################
# 5. Write xstartup — starts Plasma directly
#############################################
mkdir -p /root/.vnc
cat > /root/.vnc/xstartup <<'XEOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=plasma
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session startplasma-x11
XEOF
chmod +x /root/.vnc/xstartup


#############################################
# 6. Clean stale X11 locks
#############################################
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true


#############################################
# 7. Launch KasmVNC in the background.
#    -select-de manual = skip DE detection,
#    execute xstartup directly.
#############################################
echo "[Init] Starting KasmVNC on port 8443..."
kasmvncserver :1 \
  --noauth \
  -select-de manual \
  -geometry 1920x1080 \
  -depth "${VNC_COL_DEPTH:-24}" \
  -rfbport 8443 \
  -websocketPort 8443 \
  -cert /etc/kasmvnc/certs/self.crt \
  -key  /etc/kasmvnc/certs/self.key \
  -FrameRate "${MAX_FRAME_RATE:-60}" \
  2>&1 &

# Give Xvnc time to initialise before we start tailing
sleep 3

echo "[Init] KasmVNC started. Tailing log..."
LOG=$(ls /root/.vnc/*.log 2>/dev/null | head -1)
if [ -n "$LOG" ]; then
  exec tail -f "$LOG"
else
  exec sleep infinity
fi