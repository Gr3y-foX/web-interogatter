# 🐳 Optimized Docker Guide

## 📋 What Was Fixed

### ✅ Critical security and permissions fixes

1. **Multi-stage build** - Reduced image size by ~40%
2. **Correct COPY sequence** - All files copied with proper permissions
3. **Added `locales/` directory** - Fixed i18n issue
4. **Improved entrypoint.sh** - Added permission checks
5. **Optimized Tor configuration** - Better security and performance
6. **`.dockerignore`** - Excluded unnecessary files for faster builds
7. **Health check** - Increased `start-period` to 60s for Tor initialization

### 🔒 Security improvements

- Non-privileged user with explicit UID/GID
- `no-new-privileges:true`, `cap_drop: ALL`, `cap_add: NET_BIND_SERVICE`
- Resource limits (CPU/RAM)

### ⚡ Performance optimization

- Multi-stage build
- Resource limits
- Optimized volumes (bind mount)

## 🚀 Quick Start

### Option 1: Automatic (recommended)
```bash
./docker-build-and-run.sh
```

### Option 2: Manual
```bash
mkdir -p data reports logs
docker build -t web-interceptor:latest .
docker-compose -f docker-compose.optimized.yml up -d
docker logs -f web-interceptor
```

## 🖥️ Cross-platform build

- **macOS (Intel):** `docker build --platform linux/amd64 -t web-interceptor:latest .`
- **macOS (Apple Silicon):** `docker build --platform linux/arm64 -t web-interceptor:latest .`
- **Linux x86_64:** `docker build --platform linux/amd64 -t web-interceptor:latest .`
- **Raspberry Pi 4:** `docker build --platform linux/arm64 -t web-interceptor:latest .`
- **Raspberry Pi 3:** `docker build --platform linux/arm/v7 -t web-interceptor:latest .`

## 📊 File structure

- **Dockerfile** - Optimized multi-stage Dockerfile
- **.dockerignore** - Build context exclusions
- **docker-compose.optimized.yml** - Optimized compose config
- **docker-build-and-run.sh** - Automatic build and run script
- **docker/entrypoint.sh** - Entrypoint with checks
- **docker/torrc** - Tor configuration

## 🔧 Container management

```bash
docker-compose -f docker-compose.optimized.yml up -d    # Start
docker-compose -f docker-compose.optimized.yml down      # Stop
docker logs -f web-interceptor                           # Logs
docker exec -it web-interceptor /bin/bash               # Shell
docker exec web-interceptor cat /var/lib/tor-interceptor/hidden_service/hostname  # .onion
```

## 📚 Full documentation

See project root for:
- **DOCKER_OPTIMIZED_GUIDE.md** (Russian, full version)
- **CHANGELOG_DOCKER.md**
- **README.md** / **README_EN.md**

---

**🎓 Educational Cybersecurity Project**
