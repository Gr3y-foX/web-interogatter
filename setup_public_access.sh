#!/bin/bash

# Скрипт настройки публичного доступа к Web Server Interceptor
# Для образовательных целей

set -e

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

print_header() {
    echo -e "${BLUE}"
    echo "🌐 =============================================="
    echo "   Настройка публичного доступа"
    echo "   Web Server Interceptor"
    echo "=============================================="
    echo -e "${NC}"
}

PORT=${1:-5000}

print_header

# Получение IP адресов
print_info "Определение сетевых адресов..."

LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me/ip 2>/dev/null || echo "Не удалось определить")

print_success "Локальный IP: $LOCAL_IP"
if [ "$PUBLIC_IP" != "Не удалось определить" ]; then
    print_success "Публичный IP: $PUBLIC_IP"
else
    print_warning "Не удалось определить публичный IP"
fi

echo ""
print_info "Доступные способы подключения:"
echo ""

# 1. Локальная сеть
echo "1️⃣  ЛОКАЛЬНАЯ СЕТЬ (WiFi/LAN):"
echo "   http://$LOCAL_IP:$PORT/mask"
echo "   http://$LOCAL_IP:$PORT/intercept"
echo "   http://$LOCAL_IP:$PORT/admin/reports"
echo ""

# 2. Публичный IP
if [ "$PUBLIC_IP" != "Не удалось определить" ]; then
    echo "2️⃣  ПУБЛИЧНЫЙ IP (через интернет):"
    echo "   http://$PUBLIC_IP:$PORT/mask"
    echo "   http://$PUBLIC_IP:$PORT/intercept"
    echo "   http://$PUBLIC_IP:$PORT/admin/reports"
    echo ""
    print_warning "⚠️  Для работы через публичный IP нужно:"
    echo "   - Настроить port forwarding в роутере"
    echo "   - Открыть порт $PORT в firewall"
    echo ""
fi

# 3. Tor
ONION_FILE="/tmp/tor_interceptor/hidden_service/hostname"
if [ ! -f "$ONION_FILE" ]; then
    ONION_FILE="/var/lib/tor-interceptor/hidden_service/hostname"
fi

if [ -f "$ONION_FILE" ]; then
    ONION_ADDRESS=$(cat "$ONION_FILE")
    echo "3️⃣  TOR HIDDEN SERVICE (.onion):"
    echo "   http://$ONION_ADDRESS/mask"
    echo "   http://$ONION_ADDRESS/intercept"
    echo "   http://$ONION_ADDRESS/admin/reports"
    echo ""
    print_success "✅ Tor уже настроен!"
else
    echo "3️⃣  TOR HIDDEN SERVICE (.onion):"
    print_warning "   Tor еще не настроен"
    echo "   Запустите: python3 tor_setup.py start"
    echo ""
fi

# Проверка firewall
echo "🔧 Проверка firewall..."
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "$PORT/tcp"; then
        print_success "Порт $PORT открыт в UFW"
    else
        print_warning "Порт $PORT не открыт в UFW"
        echo "   Откройте: sudo ufw allow $PORT/tcp"
    fi
elif command -v firewall-cmd &> /dev/null; then
    if sudo firewall-cmd --list-ports | grep -q "$PORT"; then
        print_success "Порт $PORT открыт в Firewalld"
    else
        print_warning "Порт $PORT не открыт в Firewalld"
        echo "   Откройте: sudo firewall-cmd --permanent --add-port=$PORT/tcp && sudo firewall-cmd --reload"
    fi
else
    print_warning "Firewall не обнаружен или не настроен"
fi

echo ""
print_info "📋 Следующие шаги:"
echo ""
echo "1. Убедитесь, что сервер запущен:"
echo "   ./run.sh start"
echo ""
echo "2. Откройте порт в firewall:"
echo "   sudo ./setup_firewall.sh $PORT"
echo ""
if [ "$PUBLIC_IP" != "Не удалось определить" ]; then
    echo "3. Настройте port forwarding в роутере:"
    echo "   Внешний порт: $PORT → Внутренний IP: $LOCAL_IP → Внутренний порт: $PORT"
    echo ""
fi
echo "4. Проверьте доступность:"
echo "   curl http://$LOCAL_IP:$PORT/"
echo ""

# Генерация QR кода для локального доступа
if command -v qrencode &> /dev/null; then
    echo "📱 QR код для локального доступа:"
    qrencode -t ANSI "http://$LOCAL_IP:$PORT/mask" 2>/dev/null || true
    echo ""
fi

print_success "Настройка завершена!"
print_warning "⚠️  Используйте только в образовательных целях!"

