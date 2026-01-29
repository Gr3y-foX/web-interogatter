# 🚀 Quick Docker Start (5 minutes)

## Before You Start

**1. Start Docker daemon:**
   - **macOS:** Start Docker Desktop or OrbStack
   - **Linux:** `sudo systemctl start docker`
   - **Windows:** Start Docker Desktop

**2. Check Docker:**
```bash
docker --version
docker-compose --version
```

## Launch (3 simple steps)

### Step 1: Automatic build and run
```bash
cd web-server-intercepter
./docker-build-and-run.sh
```

### Step 2: Wait for completion
The script will automatically:
- ✅ Check dependencies
- ✅ Create required directories
- ✅ Build optimized Docker image (~2-3 minutes)
- ✅ Start the container
- ✅ Verify it's working
- ✅ Print access information

### Step 3: Open in browser
```
http://localhost:5000
```

## Alternative (manual) launch

If the automatic script doesn't work:

```bash
# 1. Create directories
mkdir -p data reports logs

# 2. Build image
docker build -t web-interceptor:latest .

# 3. Start container
docker-compose -f docker-compose.optimized.yml up -d

# 4. Check logs
docker logs -f web-interceptor
```

## Verify it's working

### Quick check
```bash
# Check Flask
curl http://localhost:5000/

# Check container
docker ps | grep web-interceptor

# View logs
docker logs web-interceptor --tail 20
```

### Get .onion address
```bash
# Wait 1-2 minutes after start, then:
docker exec web-interceptor cat /var/lib/tor-interceptor/hidden_service/hostname
```

## Available interfaces

After launch:

- **Main page:** http://localhost:5000
- **Admin panel:** http://localhost:5000/admin/reports
- **Mask site:** http://localhost:5000/mask
- **Intercept page:** http://localhost:5000/intercept

## Management

```bash
# Stop
docker stop web-interceptor

# Start again
docker start web-interceptor

# Restart
docker restart web-interceptor

# View logs
docker logs -f web-interceptor

# Full stop and remove
docker-compose -f docker-compose.optimized.yml down
```

## Troubleshooting

### Docker daemon not running
```
ERROR: Cannot connect to the Docker daemon
```
**Solution:** Start Docker Desktop or OrbStack

### Port 5000 in use
```
Error starting userland proxy: listen tcp4 0.0.0.0:5000: bind: address already in use
```
**Solution:** Stop the process on port 5000 or change the port in docker-compose

### Tor not starting
View logs:
```bash
docker logs web-interceptor | grep -A 10 "ERROR"
docker exec web-interceptor cat /app/logs/tor.log
```

## Full documentation

- **DOCKER_OPTIMIZED_GUIDE.md** - Detailed guide
- **CHANGELOG_DOCKER.md** - List of changes
- **README.md** - Main documentation

---

**Done! 🎉**

Your Web Server Interceptor is now running in a Docker container with optimized security settings.
