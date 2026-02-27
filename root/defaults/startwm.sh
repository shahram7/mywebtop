#!/bin/bash
# startwm.sh – called by the linuxserver KasmVNC baseimage to start the WM

# Disable KWin compositing (not useful inside VNC/KasmVNC)
if [ -f "${HOME}/.config/kwinrc" ]; then
  sed -i '/Enabled=/c Enabled=false' "${HOME}/.config/kwinrc"
else
  mkdir -p "${HOME}/.config"
  printf '[Compositing]\nEnabled=false\n' > "${HOME}/.config/kwinrc"
fi

# Ensure DBus session is running (baseimage may already provide it)
if [ -z "${DBUS_SESSION_BUS_ADDRESS}" ]; then
  eval "$(dbus-launch --sh-syntax --exit-with-session)"
  export DBUS_SESSION_BUS_ADDRESS
fi

# Start KDE Plasma session
exec /usr/bin/startplasma-x11
