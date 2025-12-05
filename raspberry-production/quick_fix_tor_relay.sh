#!/bin/bash

# Быстрое исправление проблемы с tor-relay на Raspberry Pi
# Удаляет старые контейнеры и обновляет конфигурацию

set -e

# Цвета
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

print_info "Исправление проблемы с tor-relay..."

# Переменные
PROJECT_DIR="$HOME/web-interogatter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Остановка и удаление старых контейнеров
print_info "Остановка старых контейнеров..."
docker compose -f docker-compose.raspberry.yml down 2>/dev/null || true

# Удаление контейнера tor-relay, если существует
print_info "Удаление контейнера tor-relay..."
docker rm -f tor-relay-raspberry 2>/dev/null || true

# Удаление образа, если был загружен
print_info "Удаление образа tor-socks-proxy..."
docker rmi peterdavehello/tor-socks-proxy:latest 2>/dev/null || print_warning "Образ не найден (это нормально)"

# Обновление из git (если есть изменения)
print_info "Проверка обновлений из git..."
if [ -d ".git" ]; then
    git pull origin master 2>/dev/null || print_warning "Не удалось обновить из git (продолжаем...)"
fi

print_success "Очистка завершена"
print_info "Теперь можно запустить: ./raspberry-production/raspberry-run.sh start"
