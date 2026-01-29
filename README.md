# 🔍 Web Server Interceptor

> **Full English documentation:** [docs/en/](docs/en/)

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
- **🌍 Multi-language** - English and Russian support

## 🚀 Quick Start

### 1. Clone and Setup
```bash
# Navigate to project directory
cd web-server-intercepter

# Install dependencies and start
./run.sh start
```

### 2. Manual Installation
```bash
# Install Python dependencies
pip3 install -r requirements.txt

# Install Tor (Debian/Ubuntu/Kali)
sudo apt update && sudo apt install tor

# Start Tor
python3 tor_setup.py start

# Start web server
python3 app.py
```

## 🎮 Usage

### Service Management
```bash
# Start all services
./run.sh start

# Stop services
./run.sh stop

# Restart
./run.sh restart

# Check status
./run.sh status

# View logs
./run.sh logs

# Cleanup data
./run.sh cleanup
```

### Access Interfaces

#### 🎭 Mask Site (entrypoint)
- **Localhost**: http://localhost:5000/mask
- **Local Network**: http://[local-IP]:5000/mask
- **Public IP**: http://[public-IP]:5000/mask
- **Tor Hidden Service**: http://[onion-address].onion/mask
  - Looks like a regular news site
  - Automatically redirects to intercept page

#### 📊 Intercept Page (funny report)
- **Localhost**: http://localhost:5000/intercept
- **Local Network**: http://[local-IP]:5000/intercept
- **Public IP**: http://[public-IP]:5000/intercept
- **Tor**: http://[onion-address].onion/intercept
  - Shows user "intercept report"
  - Displays all collected data in funny format

#### 🔧 Administrative Panel
- **Localhost**: http://localhost:5000/admin/reports
- **Local Network**: http://[local-IP]:5000/admin/reports
- **Public IP**: http://[public-IP]:5000/admin/reports
- **Tor**: http://[onion-address].onion/admin/reports
- **API**: http://localhost:5000/admin/api/reports
  - Returns JSON with reports and .onion address

#### Language Selection
Add `?lang=en` or `?lang=ru` to any URL:
- http://localhost:5000/mask?lang=en
- http://localhost:5000/intercept?lang=ru

## 📋 Requirements

### System
- Linux (preferably Kali Linux)
- Python 3.7+
- Tor
- SQLite3

### Python Packages
```
Flask==2.3.3
user-agents==2.2.0
requests==2.31.0
stem==1.8.1
PySocks==1.7.1
```

## 🔒 Security and Anonymity

### Tor Configuration
- SOCKS proxy on port 9050
- Control port 9051
- Automatic hidden service creation
- Exit relay disabled for security

### Recommendations
1. **Use only in isolated environment** (VM)
2. **Regularly change Tor identity**
3. **Do not use on production servers**
4. **Comply with your country's laws**

## ⚖️ Legal Information

### ⚠️ IMPORTANT WARNING
This project is created exclusively for **educational purposes** in cybersecurity.

### Permitted Use:
- ✅ Learning and studying web security
- ✅ Testing your own systems
- ✅ Academic research
- ✅ Demonstrations in controlled environment

### Prohibited Use:
- ❌ Collecting data without user consent
- ❌ Violating third-party privacy
- ❌ Any illegal activity
- ❌ Use against real users without permission

### Responsibility
Authors are not responsible for misuse of this software. User bears full responsibility for compliance with laws of their jurisdiction.

## 📝 License

This project is distributed under MIT license for educational purposes.

## 👨‍💻 Author

Created for cybersecurity education purposes.

---

**🎓 Educational Cybersecurity Project**  
*Use responsibly and in accordance with laws*
