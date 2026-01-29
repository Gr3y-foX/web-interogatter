# 🔍 Web Server Interceptor

Simple web server interceptor for collecting client information with anonymization through Tor. Created for educational purposes in cybersecurity.

## 🎯 Features

- **🎭 Mask Site** - Looks like a regular news site, automatically redirects to intercept
- **📊 Funny Intercept Report** - Shows user a "intercept report" in hacker style
- **🔄 Automatic Redirect** - Through Tor to intercept server with all data saved
- **📈 Extended Data Collection** - User-Agent, OS, device, language, cookies, fingerprint, session ID
- **🧅 Anonymization via Tor** - Traffic proxying through Tor network
- **🌐 Tor Hidden Service (.onion)** - Automatic creation and use of .onion address
- **📝 Extended Logging** - Multi-level logging system with rotation
- **💾 Report Database** - SQLite database for storing intercepted data and logs
- **🔧 Administrative Panel** - Web interface for viewing reports
- **🐳 Docker Support** - Full containerization for easy deployment
- **🌍 Multi-language** - English (default) and Russian support

## 🚀 Quick Start

### 1. Clone and Setup
```bash
cd web-server-intercepter
./run.sh start
```

### 2. Manual Installation
```bash
pip3 install -r requirements.txt
sudo apt update && sudo apt install tor
python3 tor_setup.py start
python3 app.py
```

## 🎮 Usage

### Service Management
```bash
./run.sh start    # Start all services
./run.sh stop     # Stop services
./run.sh restart  # Restart
./run.sh status   # Check status
./run.sh logs     # View logs
./run.sh cleanup  # Cleanup data
```

### Access Interfaces

#### 🎭 Mask Site (entrypoint)
- **Localhost**: http://localhost:5000/mask
- **Local Network**: http://[local-IP]:5000/mask
- **Tor Hidden Service**: http://[onion-address].onion/mask

#### 📊 Intercept Page (funny report)
- **Localhost**: http://localhost:5000/intercept
- **Tor**: http://[onion-address].onion/intercept

#### 🔧 Administrative Panel
- **Localhost**: http://localhost:5000/admin/reports
- **API**: http://localhost:5000/admin/api/reports

#### Language Selection
Add `?lang=en` or `?lang=ru` to any URL. Default is English.

## 📋 Requirements

- Linux (preferably Kali Linux) or macOS
- Python 3.7+
- Tor
- SQLite3

## 🔒 Security and Anonymity

- SOCKS proxy on port 9050, Control port 9051
- Automatic hidden service creation
- Exit relay disabled

### Recommendations
1. Use only in isolated environment (VM)
2. Regularly change Tor identity
3. Do not use on production servers
4. Comply with your country's laws

## ⚖️ Legal Information

### ⚠️ IMPORTANT WARNING
This project is for **educational purposes** in cybersecurity only.

### Permitted Use:
- ✅ Learning web security
- ✅ Testing your own systems
- ✅ Academic research
- ✅ Demonstrations in controlled environment

### Prohibited Use:
- ❌ Collecting data without user consent
- ❌ Violating third-party privacy
- ❌ Any illegal activity

## 📝 License

MIT license for educational purposes.

---

**🎓 Educational Cybersecurity Project**  
*Use responsibly and in accordance with laws*
