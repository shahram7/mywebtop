# Ubuntu Noble (24.04) + KDE + KasmVNC
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    USERNAME=abc \
    USER_UID=1000 \
    USER_GID=1000 \
    VNC_USER=owner \
    VNC_PASSWORD=changeit \
    RESOLUTION=1920x1080 \
    KASMVNC_VERSION=1.4.0 \
    KASMVNC_DISTRO=noble   # 24.04

# Base tools and KDE Plasma
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget sudo locales tzdata \
      dbus-x11 pulseaudio mesa-utils x11-xserver-utils \
      plasma-desktop konsole dolphin \
      fonts-dejavu fonts-liberation \
      nano vim less \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Non-root user with passwordless sudo (convenience for customizing inside the container)
RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd  --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-${USERNAME} \
 && chmod 0440 /etc/sudoers.d/99-${USERNAME}

# Install KasmVNC from official release packages
# Docs: select package for your distro, apt install it, and add user to ssl-cert. [2](https://docs.linuxserver.io/images/docker-kasm/)
RUN set -eux; \
    ARCH=amd64; \
    DEB_URL="https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_${KASMVNC_DISTRO}_${KASMVNC_VERSION}_${ARCH}.deb"; \
    apt-get update; \
    apt-get install -y --no-install-recommends openssl; \
    wget -O /tmp/kasmvnc.deb "$DEB_URL"; \
    apt-get install -y /tmp/kasmvnc.deb; \
    rm -f /tmp/kasmvnc.deb; \
    adduser ${USERNAME} ssl-cert; \
    rm -rf /var/lib/apt/lists/*

# KasmVNC server configuration
# We'll run HTTP (no TLS) in the container and terminate TLS at Cloudflare.
# This is supported via network.ssl.require_ssl=false. [1](https://kasm.com/downloads)
COPY kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml

# KDE Plasma startup for KasmVNC sessions (dbus-launch -> startplasma-x11). [3](https://kasmweb.com/kasmvnc/docs/latest/install.html)[4](https://hub.docker.com/r/lsiobase/kasmvnc)
COPY xstartup.plasma /opt/kasmvnc/xstartup.plasma
RUN chmod +x /opt/kasmvnc/xstartup.plasma \
    && mkdir -p /home/${USERNAME}/.vnc \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.vnc /opt/kasmvnc

# Entrypoint: create VNC user, set password, run server in foreground
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8444
USER ${USERNAME}
WORKDIR /home/${USERNAME}
CMD ["/usr/local/bin/entrypoint.sh"]
