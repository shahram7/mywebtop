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

export DBUS_SESSION_BUS_ADDRESS=$(dbus-launch --sh-syntax \
  | grep DBUS_SESSION_BUS_ADDRESS \
  | cut -d= -f2- \
  | tr -d "'" \
  | tr -d ';') || true


#############################################
# 2. First-run KDE configuration
#    (suppress welcome/wizard screens)
#############################################
mkdir -p /root/.config
cat > /root/.config/plasma-welcomerc <<EOF
[General]
LastSeenVersion=99.0
EOF


#############################################
# 3. Ensure KasmVNC config folder exists
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
# 5. Ensure users.conf exists
#############################################
if [ ! -f /etc/kasmvnc/users.conf ]; then
  mkdir -p /etc/kasmvnc
  cat >/etc/kasmvnc/users.conf <<'EOF'
users:
  - username: root
    permissions:
      - write
EOF
fi


#############################################
# 6. Write xstartup — bypasses KasmVNC DE
#    detection and starts Plasma directly
#############################################
mkdir -p /root/.vnc
cat > /root/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=plasma
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session startplasma-x11
EOF
chmod +x /root/.vnc/xstartup


#############################################
# 7. Pre-create .kasmpasswd so the first-run
#    user wizard never appears.
#    -w = write perms, -o = owner perms,
#    --noauth means the password is never
#    actually checked at login.
#############################################
echo "[Init] Pre-creating KasmVNC user to suppress wizard..."
if [ ! -f /root/.kasmpasswd ]; then
  printf 'headless\nheadless\n' | kasmvncpasswd -u root -w -o 2>/dev/null || true
fi


#############################################
# 8. Clean up stale X11 locks
#############################################
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true


#############################################
# 9. Launch KasmVNC
#    -xstartup explicitly tells vncserver to
#    use our script instead of running
#    select-de.sh or regenerating xstartup.
#    We tail the log file to keep the
#    container alive (replaces broken -fg).
#############################################
echo "Starting KasmVNC on port 8443..."
kasmvncserver :1 \
  --noauth \
  -xstartup /root/.vnc/xstartup \
  -geometry 1920x1080 \
  -depth "${VNC_COL_DEPTH:-24}" \
  -rfbport 8443 \
  -websocketPort 8443 \
  -cert /etc/kasmvnc/certs/self.crt \
  -key /etc/kasmvnc/certs/self.key \
  -FrameRate "${MAX_FRAME_RATE:-60}" \
  2>&1

# Follow the log to keep the container running
LOG=$(ls /root/.vnc/*.log 2>/dev/null | head -1)
if [ -n "$LOG" ]; then
  exec tail -f "$LOG"
else
  # Fallback: wait for the Xvnc process
  wait
fi