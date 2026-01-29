# 🔍 Web Server Interceptor

> **Full English docs:** [docs/en/](docs/en/) · **Russian manual:** [README_ru.md](README_ru.md)

Web server interceptor for collecting client information with Tor anonymization. Educational cybersecurity project. **Runs via Docker.**

---

## 🚀 Quick Start (Docker)

### Requirements

- **Docker** and **Docker Compose**
- macOS, Linux, or Windows (with Docker Desktop)

### 1. Start Docker

- **macOS:** Start Docker Desktop or OrbStack  
- **Linux:** `sudo systemctl start docker`  
- **Windows:** Start Docker Desktop  

### 2. Build and run

From the project root:

```bash
git https://github.com/Gr3y-foX/web-interogatter
cd web-server-intercepter

./docker-build-and-run.sh
```

The script will:

- Check Docker and Docker Compose
- Create `data/`, `reports/`, `logs/`
- Build the image and start the container
- Print access URLs and (after ~1–2 min) the .onion address

### 3. Open in browser

- **Main / mask site:** http://localhost:5000  
- **Admin panel:** http://localhost:5000/admin/reports  
- **Intercept page:** http://localhost:5000/intercept  

**.onion address** (after Tor is ready):

```bash
docker exec web-interceptor cat /var/lib/tor-interceptor/hidden_service/hostname
```

---

## 🎮 Usage (Docker)

| Action        | Command |
|---------------|--------|
| Start         | `./docker-build-and-run.sh` or `docker-compose -f docker-compose.optimized.yml up -d` |
| Stop          | `docker stop web-interceptor` |
| Restart       | `docker restart web-interceptor` |
| Logs          | `docker logs -f web-interceptor` |
| Get .onion    | `docker exec web-interceptor cat /var/lib/tor-interceptor/hidden_service/hostname` |

**Optional:** from project root, run `./scripts/check-docker-files.sh` to verify Docker-related files.

---

## 🎯 Features

- **Mask site** – Looks like a news site, redirects to intercept
- **Intercept report** – “Hacker-style” report page with collected data
- **Data collection** – IP, User-Agent, OS, device, language, fingerprint, etc.
- **Tor** – SOCKS proxy, hidden service (.onion)
- **Admin panel** – http://localhost:5000/admin/reports
- **Multi-language** – English (default), Russian (`?lang=ru`)

---

## 📁 Project structure (paths)

What you need for Docker:

| Path | Purpose |
|------|--------|
| **Root** | |
| `docker-build-and-run.sh` | Main script: build + run (use this) |
| `Dockerfile` | Image definition |
| `docker-compose.yml` | Default Compose |
| `docker-compose.optimized.yml` | Recommended Compose (security, limits) |
| `app.py`, `requirements.txt` | Application (used inside image) |
| `docker/` | `entrypoint.sh`, `torrc`, `nginx.conf` |
| `templates/`, `locales/` | App templates and translations |
| **Data (created at runtime)** | |
| `data/` | SQLite DB, onion env (persistent) |
| `logs/` | App and Tor logs |
| `reports/` | Exported reports |
| **Documentation** | |
| `docs/en/` | **English docs** – [README](docs/en/README.md), [Quick Docker Start](docs/en/QUICK_DOCKER_START.md), [Structure](docs/en/STRUCTURE.md), [Docker Guide](docs/en/DOCKER_OPTIMIZED_GUIDE.md) |
| `docs/QUICK_DOCKER_START.md` | Short Docker quick start (other language) |
| `docs/internal/` | Internal/developer notes (e.g. bugfix notes) |
| `README_ru.md` | Full Russian manual |
| **Scripts** | |
| `scripts/check-docker-files.sh` | Optional: check Docker files (run from project root) |
| **Platform-specific (optional)** | |
| `kali-local/` | Kali Linux – see [kali-local/README.md](kali-local/README.md) |
| `raspberry-production/` | Raspberry Pi – see [raspberry-production/README.md](raspberry-production/README.md) |
| `gu/information/` | Extra guides (external access, logging, etc.) |

You don’t need to edit anything under `docker/`, `docs/internal/`, or platform folders unless you’re customizing or debugging.

---

## 📋 Requirements (Docker only)

- Docker (20.10+)
- Docker Compose (v2 or `docker-compose` v1.29+)
- ~500 MB disk for image, ~256 MB RAM for container

No need to install Python, Tor, or SQLite on the host; they run inside the container.

---

## 🔒 Security and legal

- Use only in an **isolated environment** (e.g. VM).
- **Educational use only.** Comply with your local laws.
- Do not collect data without consent; do not use against real users without permission.

---

## 📝 License

MIT, educational use.

---

**🎓 Educational Cybersecurity Project** — use responsibly.
