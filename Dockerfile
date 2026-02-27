# ============================================================
# mywebtop – Ubuntu 24.04 (Noble) + KDE Plasma + KasmVNC
# Based on linuxserver/baseimage-kasmvnc (Ubuntu flavor)
# ============================================================

# Available tags: ubuntunoble (24.04), ubuntujammy (22.04)
# See: https://github.com/linuxserver/docker-baseimage-kasmvnc
FROM ghcr.io/linuxserver/baseimage-kasmvnc:ubuntunoble

# --------------- labels ---------------
ARG BUILD_DATE
ARG VERSION
LABEL build_version="mywebtop version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="you"

# --------------- window manager title shown in browser tab ---------------
ENV TITLE="Ubuntu KDE"

RUN \
  echo "**** add custom webtop icon ****" && \
  curl -fsSL -o /kclient/public/icon.png \
    https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/webtop-logo.png && \
  \
  echo "**** update apt cache ****" && \
  apt-get update && \
  \
  echo "**** install KDE Plasma desktop ****" && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    kde-plasma-desktop \
    plasma-workspace \
    kwin-x11 \
    konsole \
    dolphin \
    kate \
    ark \
    plasma-nm \
    plasma-pa \
    kscreen \
    plasma-systemmonitor \
    khotkeys \
    kinfocenter \
    breeze \
    breeze-icon-theme \
    sddm-theme-breeze \
    fonts-noto \
    fonts-noto-cjk \
    dbus-x11 \
    x11-xserver-utils \
    xdg-utils \
    xdg-user-dirs && \
  \
  echo "**** optional apps ****" && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    chromium-browser \
    wget \
    curl \
    nano \
    less && \
  \
  echo "**** pre-create tmp session dirs with sticky-bit permissions ****" && \
  mkdir -p /tmp/.ICE-unix /tmp/.X11-unix && \
  chmod 1777 /tmp/.ICE-unix /tmp/.X11-unix && \
  \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/* /var/tmp/*

# add local config / startup files
COPY root/ /

# KasmVNC web UI + audio
EXPOSE 3000
EXPOSE 3001

VOLUME /config
