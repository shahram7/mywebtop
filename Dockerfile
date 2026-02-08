# Ubuntu 24.04 (Noble) + KDE Plasma + KasmVNC (TLS enabled)
# KasmVNC install method follows upstream docs: download the proper .deb from Releases, then apt-install it.

FROM ubuntu:24.04

# ------------ Base environment ------------
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# ------------ Build-time args ------------
# Your workflow resolves KASMVNC_DEB_URL dynamically (latest noble/amd64 .deb).
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

# ------------ Idempotent user/group creation (handles occupied UID/GID) ------------
# - Reuse existing group for desired GID or create it.
# - If desired UID is taken, pick the first free UID >=1000.
# - Create (or adjust) the user accordingly and enable passwordless sudo.
RUN set -eux; \
  desired_gid="${USER_GID}"; \
  desired_uid="${USER_UID}"; \
  # Ensure a group exists with desired GID (reuse its name if it already exists)
  if getent group "${desired_gid}" >/dev/null; then \
    group_name="$(getent group "${desired_gid}" | cut -d: -f1)"; \
  else \
    group_name="${USERNAME}"; \
    if ! groupadd --gid "${desired_gid}" "${group_name}"; then \
      # If GID is taken but getent failed for some reason, fall back to creating group without a fixed GID
      group_name="${USERNAME}"; \
      groupadd "${group_name}"; \
      desired_gid="$(getent group "${group_name}" | cut -d: -f3)"; \
    fi; \
  fi; \
  # If the desired UID exists, find the first free UID >=1000
  if getent passwd "${desired_uid}" >/dev/null; then \
    free_uid="$(awk -F: 'BEGIN{min=1000} $3>=min{u[$3]=1} END{for(i=min;i<65534;i++){if(!u[i]){print i; exit}}}' /etc/passwd)"; \
    desired_uid="${free_uid}"; \
  fi; \
  # Create or modify the user to match desired uid/gid
  if id -u "${USERNAME}" >/dev/null 2>&1; then \
    usermod -u "${desired_uid}" -g "${desired_gid}" "${USERNAME}" || true; \
    # Ensure home exists and ownership is correct
    mkdir -p "/home/${USERNAME}" && chown -R "${desired_uid}:${desired_gid}" "/home/${USERNAME}"; \
  else \
    useradd --uid "${desired_uid}" --gid "${desired_gid}" --create-home --shell /bin/bash "${USERNAME}"; \
  fi; \
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/99-${USERNAME}"; \
  chmod 0440 "/etc/sudoers.d/99-${USERNAME}"; \
  # Debug info (optional): show resulting ids
  echo "Created/updated user: ${USERNAME} (uid=$(id -u ${USERNAME}), gid=$(id -g ${USERNAME}))"

# ------------ Install KasmVNC from upstream release ------------
# Official doc flow (Debian/Ubuntu): download the .deb for your distro from Releases and apt-install it.
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
# TLS stays enabled. On Ubuntu, default "snakeoil" certs are used if you don't supply your own.
COPY kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml

# ------------ KDE Plasma xstartup (dbus-launch -> startplasma-x11) ------------
COPY xstartup.plasma /opt/kasmvnc/xstartup.plasma
RUN set -eux; \
    chmod +x /opt/kasmvnc/xstartup.plasma; \
    mkdir -p /home/${USERNAME}/.vnc; \
    uid="$(id -u ${USERNAME})"; \
    gid="$(id -g ${USERNAME})"; \
    chown -R "${uid}:${gid}" /home/${USERNAME}/.vnc /opt/kasmvnc

# ------------ Entrypoint: create KasmVNC user + run vncserver -fg ------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8444
USER ${USERNAME}
WORKDIR /home/${USERNAME}
CMD ["/usr/local/bin/entrypoint.sh"]
