# Ubuntu KDE KasmVNC Docker Image

A lightweight alternative to LinuxServer's Webtop — Ubuntu latest + KDE Plasma + KasmVNC, exposed on a single HTTPS port with a self-signed certificate.

## 🚀 Quick Start

```bash
docker run -d \
  --name kde-desktop \
  -p 8443:8443 \
  -e VNC_PASSWORD=changeme \
  --shm-size=1g \
  --restart unless-stopped \
  your-dockerhub-username/ubuntu-kde-kasmvnc:latest
```

Then open your browser: **https://localhost:8443**

> Accept the self-signed certificate warning — it's expected.

---

## 🐳 Docker Compose

```yaml
services:
  kde-desktop:
    image: shahram7/ubuntu-kde-kasmvnc:latest
    container_name: kde-desktop
    ports:
      - "8443:8443"
    environment:
      - VNC_PASSWORD=changeme
    shm_size: '1gb'
    restart: unless-stopped
```

---

## ⚙️ Environment Variables

| Variable | Default | Description |
|---|---|---|
| `VNC_PASSWORD` | `vncpassword` | Password for VNC web access |
| `VNC_RESOLUTION` | `1920x1080` | Desktop resolution |
| `VNC_COL_DEPTH` | `24` | Color depth (16 or 24) |
| `MAX_FRAME_RATE` | `60` | Max framerate |

---

## 🔐 Ports

| Port | Protocol | Description |
|---|---|---|
| `8443` | HTTPS/WSS | KasmVNC web interface (only exposed port) |

---

## 🔧 GitHub Actions Setup

Add these secrets to your repository (`Settings → Secrets → Actions`):

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token (not password) |

`GITHUB_TOKEN` is provided automatically by GitHub Actions.

### Build Triggers

The image rebuilds automatically when:
- You push to `main`/`master`
- Ubuntu base image gets a new digest
- KasmVNC releases a new version
- KDE Plasma gets a package update in Ubuntu
- You trigger it manually via `workflow_dispatch`

---

## 📦 What's Included

- **Base**: `ubuntu:latest`
- **Desktop**: KDE Plasma (full)
- **VNC Server**: KasmVNC (latest release)
- **Apps**: Konsole, Dolphin, Kate, Ark, Gwenview, Okular
- **SSL**: Self-signed 10-year RSA-4096 certificate
