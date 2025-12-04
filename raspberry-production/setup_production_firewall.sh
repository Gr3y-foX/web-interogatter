#!/bin/bash

# Усиленная настройка firewall для production Raspberry Pi сервера
# Строгие правила безопасности для открытого интернета

set -e

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

PORT=${1:-5000}

echo "🔒 Усиленная настройка firewall для production сервера"
echo "   Порт приложения: $PORT"
echo ""

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    print_error "Запустите скрипт с sudo: sudo ./setup_production_firewall.sh $PORT"
    exit 1
fi

# Установка UFW если не установлен
if ! command -v ufw &> /dev/null; then
    print_info "Установка UFW..."
    apt update
    apt install -y ufw
fi

print_warning "⚠️  ВНИМАНИЕ: Этот скрипт настроит строгий firewall"
print_warning "⚠️  Убедитесь, что SSH доступен перед продолжением!"
read -p "Продолжить? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Сброс правил
print_info "Сброс существующих правил UFW..."
ufw --force reset

# Базовые политики
print_info "Настройка базовых политик..."
ufw default deny incoming
ufw default allow outgoing

# SSH - КРИТИЧНО! Разрешить до включения firewall
print_info "Настройка правил SSH..."
ufw allow 22/tcp comment 'SSH - Critical!'

# HTTP/HTTPS
print_info "Настройка правил HTTP/HTTPS..."
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Приложение - только для локальной сети и Tor
print_info "Настройка правил для приложения..."
ufw allow from 192.168.0.0/16 to any port $PORT comment 'Web Interceptor - Local Network'
ufw allow from 10.0.0.0/8 to any port $PORT comment 'Web Interceptor - Local Network'
ufw allow from 172.16.0.0/12 to any port $PORT comment 'Web Interceptor - Local Network'

# Tor порты - только localhost
print_info "Настройка правил Tor..."
ufw allow from 127.0.0.1 to any port 9050 comment 'Tor SOCKS - Localhost only'
ufw allow from 127.0.0.1 to any port 9051 comment 'Tor Control - Localhost only'

# Rate limiting для SSH (защита от брутфорса)
print_info "Настройка rate limiting для SSH..."
ufw limit 22/tcp comment 'SSH rate limit'

# Логирование
print_info "Включение логирования UFW..."
ufw logging on

# Показ правил перед применением
echo ""
print_info "Правила, которые будут применены:"
ufw show added

echo ""
print_warning "⚠️  Убедитесь, что SSH доступен!"
read -p "Применить правила и включить firewall? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Отменено"
    exit 0
fi

# Включение firewall
print_info "Включение firewall..."
ufw --force enable

# Показ статуса
echo ""
print_success "Firewall настроен и включен!"
echo ""
print_info "Статус firewall:"
ufw status verbose

echo ""
print_info "Логи firewall: /var/log/ufw.log"
print_warning "⚠️  Рекомендуется протестировать SSH подключение в отдельной сессии!"
print_warning "⚠️  Если SSH недоступен, отключите firewall: sudo ufw disable"

