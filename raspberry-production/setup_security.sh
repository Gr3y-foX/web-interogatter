#!/bin/bash

# Скрипт усиленной настройки безопасности для Raspberry Pi
# Для production сервера в открытом интернете
# Включает: fail2ban, усиленный firewall, автоматические обновления, мониторинг

set -e

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}"
    echo "🔒 =============================================="
    echo "   Усиленная настройка безопасности"
    echo "   Raspberry Pi Production Server"
    echo "=============================================="
    echo -e "${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Запустите скрипт с sudo: sudo ./setup_security.sh"
        exit 1
    fi
}

# Установка и настройка fail2ban
setup_fail2ban() {
    print_info "Установка и настройка fail2ban..."
    
    if ! command -v fail2ban-server &> /dev/null; then
        apt update
        apt install -y fail2ban
        print_success "fail2ban установлен"
    else
        print_success "fail2ban уже установлен"
    fi
    
    # Создание конфигурации для Flask приложения
    cat > /etc/fail2ban/jail.d/web-interceptor.conf << 'EOF'
[web-interceptor]
enabled = true
port = 5000
filter = web-interceptor
logpath = /var/log/web-interceptor/access.log
maxretry = 5
bantime = 3600
findtime = 600
action = iptables[name=WebInterceptor, port=5000, protocol=tcp]
EOF

    # Создание фильтра для Flask
    cat > /etc/fail2ban/filter.d/web-interceptor.conf << 'EOF'
[Definition]
failregex = ^.*"GET /admin.*HTTP/1\.[01]" 401.*$
            ^.*"POST /admin.*HTTP/1\.[01]" 401.*$
            ^.*"GET /admin.*HTTP/1\.[01]" 403.*$
            ^.*"POST /admin.*HTTP/1\.[01]" 403.*$
ignoreregex =
EOF

    # Создание директории для логов
    mkdir -p /var/log/web-interceptor
    touch /var/log/web-interceptor/access.log
    chmod 644 /var/log/web-interceptor/access.log
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    print_success "fail2ban настроен и запущен"
}

# Усиленная настройка firewall
setup_enhanced_firewall() {
    print_info "Настройка усиленного firewall..."
    
    # Установка UFW если не установлен
    if ! command -v ufw &> /dev/null; then
        apt update
        apt install -y ufw
    fi
    
    # Сброс правил
    ufw --force reset
    
    # Базовые правила
    ufw default deny incoming
    ufw default allow outgoing
    
    # Разрешить SSH (важно сделать до включения!)
    ufw allow 22/tcp comment 'SSH'
    
    # Разрешить HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Разрешить порт приложения (только для локальной сети)
    ufw allow from 192.168.0.0/16 to any port 5000 comment 'Web Interceptor - Local Network'
    ufw allow from 10.0.0.0/8 to any port 5000 comment 'Web Interceptor - Local Network'
    
    # Разрешить Tor порты только локально
    ufw allow from 127.0.0.1 to any port 9050 comment 'Tor SOCKS - Localhost only'
    ufw allow from 127.0.0.1 to any port 9051 comment 'Tor Control - Localhost only'
    
    # Включение firewall
    ufw --force enable
    
    print_success "Firewall настроен и включен"
    print_warning "Убедитесь, что SSH доступен перед отключением сессии!"
}

# Настройка автоматических обновлений безопасности
setup_auto_updates() {
    print_info "Настройка автоматических обновлений безопасности..."
    
    if ! command -v unattended-upgrades &> /dev/null; then
        apt update
        apt install -y unattended-upgrades apt-listchanges
    fi
    
    # Настройка автоматических обновлений
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

    # Включение автоматических обновлений
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    print_success "Автоматические обновления настроены"
}

# Настройка логирования безопасности
setup_security_logging() {
    print_info "Настройка логирования безопасности..."
    
    # Создание директории для логов безопасности
    mkdir -p /var/log/security-monitor
    
    # Создание скрипта мониторинга
    cat > /usr/local/bin/security-monitor.sh << 'EOF'
#!/bin/bash
# Мониторинг безопасности для Web Server Interceptor

LOG_FILE="/var/log/security-monitor/security.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Проверка неудачных попыток входа
FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log | wc -l)
if [ "$FAILED_LOGINS" -gt 10 ]; then
    echo "[$DATE] WARNING: $FAILED_LOGINS failed login attempts detected" >> "$LOG_FILE"
fi

# Проверка заблокированных IP от fail2ban
BANNED_IPS=$(fail2ban-client status web-interceptor 2>/dev/null | grep "Banned IP list" | awk -F: '{print $2}' | tr -d ' ')
if [ -n "$BANNED_IPS" ]; then
    echo "[$DATE] INFO: Banned IPs: $BANNED_IPS" >> "$LOG_FILE"
fi

# Проверка использования диска
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "[$DATE] WARNING: Disk usage is ${DISK_USAGE}%" >> "$LOG_FILE"
fi

# Проверка памяти
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
if [ "$MEM_USAGE" -gt 90 ]; then
    echo "[$DATE] WARNING: Memory usage is ${MEM_USAGE}%" >> "$LOG_FILE"
fi
EOF

    chmod +x /usr/local/bin/security-monitor.sh
    
    # Добавление в crontab (каждые 5 минут)
    (crontab -l 2>/dev/null | grep -v security-monitor.sh; echo "*/5 * * * * /usr/local/bin/security-monitor.sh") | crontab -
    
    print_success "Логирование безопасности настроено"
}

# Настройка ограничения ресурсов
setup_resource_limits() {
    print_info "Настройка ограничений ресурсов..."
    
    # Настройка limits.conf
    cat >> /etc/security/limits.conf << 'EOF'
# Web Server Interceptor limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 4096
* hard nproc 4096
EOF

    # Настройка sysctl для безопасности
    cat >> /etc/sysctl.d/99-web-interceptor-security.conf << 'EOF'
# Network security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable IPv6 if not needed (uncomment if IPv6 not used)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
EOF

    sysctl -p /etc/sysctl.d/99-web-interceptor-security.conf
    
    print_success "Ограничения ресурсов настроены"
}

# Настройка мониторинга
setup_monitoring() {
    print_info "Настройка мониторинга..."
    
    # Создание скрипта мониторинга системы
    cat > /usr/local/bin/system-monitor.sh << 'EOF'
#!/bin/bash
# Мониторинг системы для Raspberry Pi

LOG_FILE="/var/log/security-monitor/system.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Температура CPU
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp | cut -d= -f2)
    echo "[$DATE] CPU Temperature: $TEMP" >> "$LOG_FILE"
fi

# Использование памяти
MEM_INFO=$(free -h | grep Mem | awk '{print "Used: " $3 " / " $2 " (" $3/$2*100 "%)"}')
echo "[$DATE] Memory: $MEM_INFO" >> "$LOG_FILE"

# Использование диска
DISK_INFO=$(df -h / | awk 'NR==2 {print "Used: " $3 " / " $2 " (" $5 ")"}')
echo "[$DATE] Disk: $DISK_INFO" >> "$LOG_FILE"

# Статус Docker контейнеров
if command -v docker &> /dev/null; then
    CONTAINERS=$(docker ps --format "{{.Names}}" | wc -l)
    echo "[$DATE] Docker containers running: $CONTAINERS" >> "$LOG_FILE"
fi
EOF

    chmod +x /usr/local/bin/system-monitor.sh
    
    # Добавление в crontab (каждый час)
    (crontab -l 2>/dev/null | grep -v system-monitor.sh; echo "0 * * * * /usr/local/bin/system-monitor.sh") | crontab -
    
    print_success "Мониторинг настроен"
}

# Настройка резервного копирования
setup_backup() {
    print_info "Настройка автоматического резервного копирования..."
    
    # Создание скрипта резервного копирования
    cat > /usr/local/bin/backup-interceptor.sh << 'EOF'
#!/bin/bash
# Автоматическое резервное копирование Web Server Interceptor

    BACKUP_DIR="/var/backups/web-interceptor"
    DATE=$(date +%Y%m%d_%H%M%S)
    PROJECT_DIR="$PROJECT_ROOT"

mkdir -p "$BACKUP_DIR"

# Резервное копирование данных
tar -czf "$BACKUP_DIR/data_$DATE.tar.gz" \
    -C "$PROJECT_DIR" \
    data/ reports/ logs/ 2>/dev/null || true

# Удаление старых резервных копий (старше 7 дней)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: data_$DATE.tar.gz"
EOF

    chmod +x /usr/local/bin/backup-interceptor.sh
    
    # Добавление в crontab (каждый день в 2:00)
    (crontab -l 2>/dev/null | grep -v backup-interceptor.sh; echo "0 2 * * * /usr/local/bin/backup-interceptor.sh") | crontab -
    
    print_success "Резервное копирование настроено"
}

# Основная функция
main() {
    print_header
    
    check_root
    
    print_warning "Этот скрипт настроит усиленную защиту для production сервера"
    print_warning "Убедитесь, что SSH доступен перед продолжением!"
    read -p "Продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    setup_fail2ban
    setup_enhanced_firewall
    setup_auto_updates
    setup_security_logging
    setup_resource_limits
    setup_monitoring
    setup_backup
    
    echo
    print_success "Усиленная настройка безопасности завершена!"
    echo
    print_info "Настроенные компоненты:"
    echo "  ✅ fail2ban - защита от брутфорса"
    echo "  ✅ Усиленный firewall - UFW с ограничениями"
    echo "  ✅ Автоматические обновления безопасности"
    echo "  ✅ Логирование безопасности"
    echo "  ✅ Ограничения ресурсов"
    echo "  ✅ Мониторинг системы"
    echo "  ✅ Автоматическое резервное копирование"
    echo
    print_warning "Рекомендуется перезагрузить систему для применения всех изменений"
    print_info "Логи безопасности: /var/log/security-monitor/"
    print_info "Резервные копии: /var/backups/web-interceptor/"
}

main "$@"

