FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Install dependencies + KDE Plasma + required session binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales dbus dbus-x11 sudo wget curl ca-certificates gnupg2 openssl \
    xauth xorg xinit x11-xserver-utils \
    kde-plasma-desktop plasma-desktop plasma-workspace sddm-theme-debian-maui \
    startplasma-x11 \
    && locale-gen en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install KasmVNC from GitHub Releases
RUN KASMVNC_VER=$(curl -s https://api.github.com/repos/kasmtech/KasmVNC/releases/latest \
        | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/') \
    && UBUNTU_CODENAME=$(. /etc/os-release && echo "$UBUNTU_CODENAME") \
    && echo "Installing KasmVNC ${KASMVNC_VER} for ${UBUNTU_CODENAME}" \
    && wget -qO /tmp/kasmvnc.deb \
        "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VER}/kasmvncserver_${UBUNTU_CODENAME}_${KASMVNC_VER}_amd64.deb" \
    && apt-get update && apt-get install -y --no-install-recommends \
        /tmp/kasmvnc.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/kasmvnc.deb

# Remove ALL auto-start hooks from KasmVNC + any wrapper VNC server
RUN rm -f \
      /usr/bin/vncserver /bin/vncserver /usr/local/bin/vncserver /etc/alternatives/vncserver \
      /lib/systemd/system/kasmvncserver.service \
      /etc/systemd/system/kasmvncserver.service \
      /etc/init.d/kasmvncserver \
      /etc/X11/Xsession.d/99kasmvnc \
      /etc/xdg/autostart/kasmvnc.desktop \
      /etc/profile.d/kasmvnc.sh \
      /usr/lib/kasmvnc/kasmvncdesktop \
      /usr/bin/kasmvncserver-root \
      || true

# Create directories and copy config
RUN mkdir -p /etc/kasmvnc /etc/kasmvnc/certs /root/.vnc

# Self-signed certificate for WebSocket TLS (CF Tunnel safe)
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
    -keyout /etc/kasmvnc/certs/self.key \
    -out /etc/kasmvnc/certs/self.crt \
    -subj "/C=US/ST=NA/L=NA/O=KasmVNC/OU=Desktop/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

# Copy KasmVNC YAML (valid for KasmVNC 1.4.0)
COPY kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml

# Pre-create users.conf to avoid wizard forever
RUN cat >/etc/kasmvnc/users.conf <<EOF
users:
  - username: root
    permissions:
      - write
EOF

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8443

ENTRYPOINT ["/entrypoint.sh"]