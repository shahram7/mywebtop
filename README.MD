# webtop-ubuntu-kde

A self-hosted Docker image providing an **Ubuntu 24.04 LTS + KDE Plasma** desktop
accessible in any browser via **KasmVNC** – the same stack the original
[linuxserver/webtop](https://github.com/linuxserver/docker-webtop) used before
they switched to Selkies.

---

## Quick start

```bash
# Pull the latest image (replace with your GitHub username)
docker pull ghcr.io/shahram7/mywebtop:latest

# Or run directly with compose
docker compose up -d
```

Open **http://localhost:3000** in your browser.  
Default credentials: no password (set one via the KasmVNC settings icon, or add
`-e CUSTOM_USER=abc -e PASSWORD=abc` to override).

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PUID` | `1000` | User ID for the desktop user |
| `PGID` | `1000` | Group ID |
| `TZ` | `Etc/UTC` | Timezone |
| `TITLE` | `Ubuntu KDE` | Browser tab title |
| `SUBFOLDER` | `/` | URL subfolder for reverse-proxy setups |
| `CUSTOM_USER` | `abc` | VNC username |
| `PASSWORD` | *(none)* | VNC password |

---

## Automatic updates

This repo is set up with **GitHub Actions** (`.github/workflows/build.yml`) to
rebuild and push automatically when:

1. **The upstream KasmVNC base image changes** – checked weekly (Monday 04:00 UTC).  
   The workflow compares the upstream manifest digest; if it changed, a new image is built.
2. **Ubuntu packages are updated** – because we run `apt-get update` inside the
   `RUN` layer during every build, a weekly rebuild always pulls the latest package
   versions.
3. **You push changes** to `Dockerfile`, `root/`, or the workflow file itself.
4. **You trigger a manual run** from the GitHub Actions UI.

### Switching Ubuntu version

Change the `FROM` line in `Dockerfile`:

```dockerfile
# Ubuntu 24.04 (Noble)
FROM ghcr.io/linuxserver/baseimage-kasmvnc:ubuntunoble

# Ubuntu 22.04 (Jammy)
FROM ghcr.io/linuxserver/baseimage-kasmvnc:ubuntujammy
```

---

## Building locally

```bash
docker build -t webtop-ubuntu-kde .
docker run -d \
  -p 3000:3000 \
  -v ./config:/config \
  --shm-size=1g \
  --security-opt seccomp=unconfined \
  webtop-ubuntu-kde
```

---

## Adding more apps

Edit `Dockerfile` and append packages to the `apt-get install` block, then push.
The CI pipeline will rebuild and push a new image automatically.

```dockerfile
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  vlc \
  gimp \
  ...
```

---

## Credits

- [LinuxServer.io](https://www.linuxserver.io/) for the excellent `baseimage-kasmvnc` base images
- [KasmVNC](https://github.com/kasmtech/KasmVNC) for the web-based VNC implementation
- [KDE](https://kde.org/) for the Plasma desktop
