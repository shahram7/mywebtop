FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales dbus dbus-x11 sudo wget curl ca-certificates gnupg2 openssl \
    xauth xorg xinit x11-xserver-utils x11-utils \
    kde-plasma-desktop kde-standard sddm \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN KASMVNC_VER=$(curl -s https://api.github.com/repos/kasmtech/KasmVNC/releases/latest \
        | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/') \
    && UBUNTU_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME") \
    && echo "Installing KasmVNC ${KASMVNC_VER} for ${UBUNTU_CODENAME}" \
    && wget -qO /tmp/kasmvnc.deb \
        "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VER}/kasmvncserver_${UBUNTU_CODENAME}_${KASMVNC_VER}_amd64.deb" \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/kasmvnc.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/kasmvnc.deb

RUN rm -f \
      /lib/systemd/system/kasmvncserver.service \
      /etc/systemd/system/kasmvncserver.service \
      /etc/init.d/kasmvncserver \
      /etc/X11/Xsession.d/99kasmvnc \
      /etc/xdg/autostart/kasmvnc.desktop \
      /etc/profile.d/kasmvnc.sh \
      || true

# Patch select-de.sh to a no-op — vncserver calls it unconditionally
RUN printf '#!/bin/sh\nexit 0\n' > /usr/lib/kasmvncserver/select-de.sh \
    && chmod +x /usr/lib/kasmvncserver/select-de.sh

RUN mkdir -p /etc/kasmvnc /etc/kasmvnc/certs /root/.vnc

COPY kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8443
ENTRYPOINT ["/entrypoint.sh"]