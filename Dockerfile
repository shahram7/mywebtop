# ============================================================
# webtop-ubuntu-kde
# Ubuntu LTS + KDE Plasma + KasmVNC
# Based on linuxserver/baseimage-kasmvnc (Ubuntu flavor)
# ============================================================

# Track the latest Ubuntu LTS base from linuxserver
# Available tags: ubuntu2404, ubuntu2204 – change here to upgrade
FROM ghcr.io/linuxserver/baseimage-kasmvnc:ubuntu2404

# --------------- labels ---------------
ARG BUILD_DATE
ARG VERSION
LABEL build_version="webtop-ubuntu-kde version:- ${VERSION} Build-date:- ${BUILD_DATE}"
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
  echo "**** install KDE Plasma desktop (minimal, no heavy extras) ****" && \
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
    ksysguard \
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
  echo "**** optional but handy apps ****" && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    chromium-browser \
    wget \
    curl \
    nano \
    less && \
  \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# add local config / startup files
COPY root/ /

# KasmVNC web UI + audio
EXPOSE 3000
EXPOSE 3001

VOLUME /config
