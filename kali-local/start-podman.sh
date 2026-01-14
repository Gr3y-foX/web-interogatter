#!/bin/bash

# Скрипт для запуска Podman service
# Используется когда система использует Podman вместо Docker

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

echo "🔧 Запуск Podman Service"
echo ""

# Проверка наличия Podman
if ! command -v podman &> /dev/null; then
    print_error "Podman не установлен"
    print_info "Установите Podman: sudo apt install -y podman"
    exit 1
fi

print_success "Podman найден"

# Попытка запустить через systemd user service
if systemctl --user is-active --quiet podman.socket 2>/dev/null; then
    print_success "Podman socket уже запущен"
    exit 0
fi

print_info "Попытка запустить Podman socket через systemd..."

# Запуск через systemd user service
if systemctl --user start podman.socket 2>/dev/null; then
    sleep 2
    if systemctl --user is-active --quiet podman.socket; then
        print_success "Podman socket запущен через systemd"
        print_info "Для автозапуска выполните: systemctl --user enable podman.socket"
        exit 0
    fi
fi

# Альтернативный способ - прямой запуск service
print_info "Попытка альтернативного способа запуска..."

PODMAN_SOCKET="/run/user/$(id -u)/podman/podman.sock"
mkdir -p "$(dirname "$PODMAN_SOCKET")"

# Проверка, не запущен ли уже
if [ -S "$PODMAN_SOCKET" ]; then
    print_success "Podman socket уже существует: $PODMAN_SOCKET"
    exit 0
fi

# Запуск Podman service в фоне
print_info "Запуск Podman service..."
podman system service --time=0 "unix://$PODMAN_SOCKET" > /tmp/podman-service.log 2>&1 &
PODMAN_PID=$!

sleep 3

# Проверка успешности запуска
if [ -S "$PODMAN_SOCKET" ]; then
    print_success "Podman service запущен (PID: $PODMAN_PID)"
    print_info "Socket: $PODMAN_SOCKET"
    print_info "Логи: /tmp/podman-service.log"
    print_warning "Для остановки: kill $PODMAN_PID"
    echo "$PODMAN_PID" > /tmp/podman-service.pid
    exit 0
else
    print_error "Не удалось запустить Podman service"
    print_info "Проверьте логи: cat /tmp/podman-service.log"
    exit 1
fi






