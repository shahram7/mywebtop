#!/bin/bash

# ── Fix XDG runtime dir permissions ──────────────────────────────
# KDE/Qt requires 0700, linuxserver base creates it as 0755
XDG_RUNTIME="${XDG_RUNTIME_DIR:-/config/.XDG}"
mkdir -p "${XDG_RUNTIME}"
chmod 0700 "${XDG_RUNTIME}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME}"

# ── Fix /tmp directories needed by ICE / X session ───────────────
mkdir -p /tmp/.ICE-unix /tmp/.X11-unix
chmod 1777 /tmp/.ICE-unix /tmp/.X11-unix

# ── Disable KWin compositing (not useful inside VNC) ─────────────
KWINRC="${HOME}/.config/kwinrc"
if [ -f "${KWINRC}" ]; then
    sed -i '/Enabled=/c Enabled=false' "${KWINRC}"
else
    mkdir -p "${HOME}/.config"
    printf '[Compositing]\nEnabled=false\n' > "${KWINRC}"
fi

# ── Disable Baloo file indexer (not needed, wastes resources) ────
mkdir -p "${HOME}/.config"
cat > "${HOME}/.config/baloofilerc" << 'BALOO'
[Basic Settings]
Indexing-Enabled=false
BALOO

# ── Ensure DBus session is running ───────────────────────────────
if [ -z "${DBUS_SESSION_BUS_ADDRESS}" ]; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)"
    export DBUS_SESSION_BUS_ADDRESS
fi

# ── Start KDE Plasma ─────────────────────────────────────────────
exec /usr/bin/startplasma-x11
