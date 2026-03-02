FROM ubuntu:latest

LABEL maintainer="your-name"
LABEL description="Ubuntu KDE Desktop with KasmVNC"

ENV DEBIAN_FRONTEND=noninteractive \
    KASM_VNC_PATH=/usr/share/kasmvnc \
    HOME=/root \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DISPLAY=:1 \
    VNC_PORT=8443 \
    VNC_COL_DEPTH=24 \
    MAX_FRAME_RATE=60

# Install dependencies and KDE
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    dbus \
    dbus-x11 \
    fuse \
    gzip \
    locales \
    mesa-utils \
    openssl \
    perl \
    procps \
    psmisc \
    python3 \
    ssl-cert \
    sudo \
    wget \
    xauth \
    xdg-utils \
    xfonts-base \
    xinit \
    xorg \
    # # KDE Plasma (minimal but functional)
    # kde-plasma-desktop \
    # plasma-workspace \
    # plasma-nm \
    konsole \
    dolphin \
    kate \
    ark \
    gwenview \
    okular \
    pulseaudio \
    pavucontrol \
    fonts-noto \
    fonts-liberation \
    language-pack-en \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales dbus dbus-x11 sudo wget curl ca-certificates gnupg2 openssl \
    xauth xorg xinit x11-xserver-utils \
    kde-plasma-desktop plasma-desktop plasma-workspace sddm \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 1) Install KasmVNC
RUN KASMVNC_VER=$(curl -sX GET "https://api.github.com/repos/kasmtech/KasmVNC/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/') \
    && UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$(lsb_release -cs 2>/dev/null || echo noble)}") \
    && echo "Installing KasmVNC ${KASMVNC_VER} for ${UBUNTU_CODENAME}" \
    && wget -qO /tmp/kasmvnc.deb \
        "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VER}/kasmvncserver_${UBUNTU_CODENAME}_${KASMVNC_VER}_amd64.deb" \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/kasmvnc.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/kasmvnc.deb

# 2) Hard-disable any auto-starting service units or init scripts (defensive)
RUN rm -f /lib/systemd/system/kasmvncserver.service /etc/systemd/system/kasmvncserver.service /etc/init.d/kasmvncserver || true
# Remove TigerVNC / generic vncserver wrapper (causes wizard)
RUN rm -f /usr/bin/vncserver /bin/vncserver /usr/local/bin/vncserver /etc/alternatives/vncserver || true

# Disable ALL KasmVNC autostart hooks
RUN rm -f /etc/X11/Xsession.d/99kasmvnc \
       /etc/xdg/autostart/kasmvnc.desktop \
       /etc/profile.d/kasmvnc.sh \
       /usr/lib/kasmvnc/kasmvncdesktop \
       /usr/bin/kasmvncserver-root \
       || true

# 3) Generate self-signed SSL certificate
RUN mkdir -p /etc/kasmvnc/certs \
    && openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
        -keyout /etc/kasmvnc/certs/self.key \
        -out /etc/kasmvnc/certs/self.crt \
        -subj "/C=US/ST=State/L=City/O=KasmVNC/OU=Desktop/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

# 4) Copy server config and create users.conf at build time
RUN mkdir -p /root/.vnc /etc/kasmvnc
COPY kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml
RUN cat >/etc/kasmvnc/users.conf <<'EOF'
users:
  - username: root
    permissions:
      - write
EOF
RUN chmod 644 /etc/kasmvnc/kasmvnc.yaml /etc/kasmvnc/users.conf

# Startup script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8443

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -fk https://localhost:8443/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]