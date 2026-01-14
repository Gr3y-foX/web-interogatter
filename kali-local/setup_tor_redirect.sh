#!/bin/bash

# Скрипт настройки перенаправления через Tor для маскировочного сайта
# Для образовательных целей

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

echo "🧅 Настройка перенаправления через Tor"
echo ""

# Проверка Tor
if ! command -v tor &> /dev/null; then
    print_error "Tor не установлен"
    print_info "Установите: sudo apt install tor"
    exit 1
fi

# Получение .onion адреса
ONION_FILE="/tmp/tor_interceptor/hidden_service/hostname"
if [ ! -f "$ONION_FILE" ]; then
    ONION_FILE="/var/lib/tor-interceptor/hidden_service/hostname"
fi

if [ -f "$ONION_FILE" ]; then
    ONION_ADDRESS=$(cat "$ONION_FILE")
    print_success "Найден .onion адрес: $ONION_ADDRESS"
else
    print_warning ".onion адрес еще не создан"
    print_info "Запустите: python3 tor_setup.py start"
    print_info "Или подождите ~60 секунд после запуска Tor"
    exit 1
fi

print_info "Настройка завершена!"
print_info ""
print_info "Маскировочный сайт доступен по адресам:"
print_info "  - HTTP: http://localhost:5000/mask"
print_info "  - HTTP: http://localhost:5000/ (с параметром ?mode=mask)"
print_info "  - Tor:  http://$ONION_ADDRESS/mask"
print_info ""
print_info "Страница перехвата:"
print_info "  - HTTP: http://localhost:5000/intercept"
print_info "  - Tor:  http://$ONION_ADDRESS/intercept"
print_info ""
print_warning "Для публикации маскировочного сайта используйте .onion адрес"

