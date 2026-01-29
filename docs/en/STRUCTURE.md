# 📁 Project Structure

## Overview

The project is organized into two main versions for different use cases:

```
web-server-intercepter/
├── kali-local/              # Version for Kali Linux (local access)
└── raspberry-production/    # Version for Raspberry Pi (production)
```

## 🐧 kali-local/

Version for local use on Kali Linux.

### Files:
- `run.sh` - Main startup script (without Docker)
- `docker-run.sh` - Docker container management script
- `setup_tor_redirect.sh` - Tor redirect setup
- `README.md` - Documentation

### Usage:
```bash
cd kali-local
./run.sh start
```

## 🍓 raspberry-production/

Version for production server on Raspberry Pi with enhanced security.

### Files:
- `raspberry-run.sh` - Application management
- `setup_raspberry.sh` - Automatic system setup
- `setup_security.sh` - Full security configuration
- `setup_production_firewall.sh` - Enhanced firewall
- `monitor_security.sh` - Security monitoring
- `README.md` - Documentation

### Usage:
```bash
cd raspberry-production
./setup_raspberry.sh
sudo ./setup_security.sh
./raspberry-run.sh start
```

## 🔒 Security Components (raspberry-production)

### setup_security.sh
Configures:
- fail2ban (brute-force protection)
- Enhanced firewall
- Automatic security updates
- Security logging
- Resource limits
- System monitoring
- Automatic backups

### setup_production_firewall.sh
Configures:
- Strict UFW rules
- SSH rate limiting
- Application access restriction (local network only)
- Tor ports for localhost only

### monitor_security.sh
Monitors:
- Firewall status
- fail2ban status
- Failed login attempts
- Security logs
- System status
- Backups

## 📚 Documentation

- **QUICK_START_GUIDE.md** - Quick version selection
- **kali-local/README.md** - Kali Linux documentation
- **raspberry-production/README.md** - Raspberry Pi documentation
- **README.md** - Main project documentation
- **docs/en/** - English documentation (this folder)

## 🎯 Version Selection

### Use kali-local if:
- Testing on Kali Linux
- Need local access only
- Working in isolated environment

### Use raspberry-production if:
- Running on Raspberry Pi 4
- Need public access
- Require enhanced security

---

**🎓 Educational Cybersecurity Project**
