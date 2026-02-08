# Ubuntu 24.04 (Noble) + KDE Plasma + KasmVNC
# KasmVNC install method follows upstream docs: download the proper .deb from Releases and apt-install it.  [1](https://www.reddit.com/r/kasmweb/comments/15nl1d6/lsio_images_stuck_on/)
FROM ubuntu:24.04

# ------------ Base environment ------------
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# ------------ Build-time args ------------
# Your workflow should set KASMVNC_DEB_URL dynamically by querying the latest release assets.
# See: /repos/kasmtech/KasmVNC/releases (pick kasmvncserver_noble_*_amd64.deb).  [1](https://www.reddit.com/r/kasmweb/comments/15nl1d6/lsio_images_stuck_on/)
ARG KASMVNC_DEB_URL
ARG USERNAME=abc
ARG USER_UID=1000
ARG USER_GID=1000

# ------------ OS packages & KDE Plasma ------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget jq sudo locales tzdata \
      dbus-x11 pulseaudio mesa-utils x11-xserver-utils \
      plasma-desktop konsole dolphin \
      fonts-dejavu fonts-liberation \
      nano vim less; \
    locale-gen en_US.UTF-8; \
    rm -rf /var/lib/apt/lists/*

# ------------ Idempotent user/group creation (avoids GID 1000 collision) ------------
RUN set -eux; \
  if getent group "${USER_GID}" >/dev/null; then \
    EXISTING_GROUP="$(getent group "${USER_GID}" | cut -d: -f1)"; \
  else \
    groupadd --gid "${USER_GID}" "${USERNAME}"; \
    EXISTING_GROUP="${USERNAME}"; \
  fi; \
  if id -u "${USERNAME}" >/dev/null 2>&1; then \
    usermod -g "${USER_GID}" "${USERNAME}" || true; \
  else \
    useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}"; \
  fi; \
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-${USERNAME}; \
  chmod 0440 /etc/sudoers.d/99-${USERNAME}

# ------------ Install KasmVNC from upstream release ------------
# Official doc flow (Debian/Ubuntu): wget the .deb from Releases and apt-get install it, then add the user to ssl-cert.  [1](https://www.reddit.com/r/kasmweb/comments/15nl1d6/lsio_images_stuck_on/)
RUN set -eux; \
    test -n "$KASMVNC_DEB_URL"; \
    apt-get update; \
    apt-get install -y --no-install-recommends openssl; \
    wget -O /tmp/kasmvnc.deb "$KASMVNC_DEB_URL"; \
    apt-get install -y /tmp/kasmvnc.deb; \
    rm -f /tmp/kasmvnc.deb; \
    adduser ${USERNAME} ssl-cert; \
    rm -rf /var/lib/apt/lists/*

# ------------ KasmVNC server config ------------
# KasmVNC is YAML-configured; server-level file lives at /etc/kasmvnc/kasmvnc.yaml.  [4](https://proot-me.github.io/)
# We keep TLS enabled (require_ssl: true). On Ubuntu, default "snakeoil" certs are used automatically.
COPY kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml

# ------------ KDE Plasma xstartup (dbus-launch -> startplasma-x11) ------------
# Starting Plasma this way is reliable in VNC/Xvnc headless sessions.  [2](https://www.kasmweb.com/kasmvnc/docs/master/index.html)
COPY xstartup.plasma /opt/kasmvnc/xstartup.plasma
RUN chmod +x /opt/kasmvnc/xstartup.plasma \
    && mkdir -p /home/${USERNAME}/.vnc \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.vnc /opt/kasmvnc

# ------------ Entrypoint: create KasmVNC user + run vncserver -fg ------------
# vncserver -fg keeps the server in the foreground, ideal for containers.  [3](https://github.com/kasmtech/KasmVNC)
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8444
USER ${USERNAME}
WORKDIR /home/${USERNAME}
CMD ["/usr/local/bin/entrypoint.sh"]
