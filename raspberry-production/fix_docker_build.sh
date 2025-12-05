#!/bin/bash

# Скрипт для исправления проблем со сборкой Docker на Raspberry Pi
# Помогает при зависании или медленной сборке

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}"
    echo "🔧 =============================================="
    echo "   Исправление проблем сборки Docker"
    echo "   Raspberry Pi Optimization"
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

print_header

# Переменные
PROJECT_DIR="$HOME/web-interogatter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Функция для остановки зависших процессов
stop_hung_builds() {
    print_info "Остановка зависших процессов Docker..."
    
    # Остановка всех контейнеров
    docker ps -q | xargs -r docker stop 2>/dev/null || true
    
    # Удаление зависших build процессов
    docker ps -a --filter "status=exited" -q | xargs -r docker rm 2>/dev/null || true
    
    # Очистка build cache (опционально)
    read -p "Очистить build cache? Это ускорит следующую сборку, но удалит кэш (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Очистка build cache..."
        docker builder prune -f
        print_success "Build cache очищен"
    fi
    
    print_success "Зависшие процессы остановлены"
}

# Функция для оптимизации Docker
optimize_docker() {
    print_info "Оптимизация настроек Docker..."
    
    # Создание/обновление daemon.json для оптимизации
    DOCKER_DAEMON="/etc/docker/daemon.json"
    
    if [ -f "$DOCKER_DAEMON" ]; then
        print_warning "Файл $DOCKER_DAEMON уже существует"
        read -p "Перезаписать? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    # Создание оптимизированной конфигурации
    sudo tee "$DOCKER_DAEMON" > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ],
  "max-concurrent-downloads": 2,
  "max-concurrent-uploads": 2
}
EOF
    
    print_success "Конфигурация Docker обновлена"
    print_warning "Может потребоваться перезапуск Docker: sudo systemctl restart docker"
}

# Функция для предварительной загрузки базового образа
preload_base_image() {
    print_info "Предварительная загрузка базового образа..."
    
    # Используем более легкий образ
    print_info "Загрузка python:3.9-slim-bullseye (легче чем 3.11)..."
    docker pull python:3.9-slim-bullseye || {
        print_warning "Не удалось загрузить образ, продолжаем..."
    }
    
    print_success "Базовый образ загружен"
}

# Функция для сборки с оптимизациями
build_with_optimizations() {
    print_info "Сборка с оптимизациями для Raspberry Pi..."
    
    # Включение BuildKit для ускорения
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    # Сборка с ограничением параллелизма
    print_info "Запуск сборки (это может занять время)..."
    
    cd "$PROJECT_ROOT"
    
    # Использование docker compose с оптимизациями
    docker compose -f docker-compose.raspberry.yml build \
        --progress=plain \
        --no-cache=false \
        interceptor
    
    print_success "Сборка завершена"
}

# Функция для сборки без кэша (если проблемы продолжаются)
build_without_cache() {
    print_warning "Сборка без кэша (медленнее, но может решить проблемы)..."
    
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    cd "$PROJECT_ROOT"
    
    docker compose -f docker-compose.raspberry.yml build \
        --progress=plain \
        --no-cache \
        interceptor
    
    print_success "Сборка без кэша завершена"
}

# Основное меню
main() {
    echo
    print_info "Выберите действие:"
    echo "  1) Остановить зависшие процессы и очистить"
    echo "  2) Оптимизировать настройки Docker"
    echo "  3) Предварительно загрузить базовый образ"
    echo "  4) Собрать с оптимизациями (рекомендуется)"
    echo "  5) Собрать без кэша (если проблемы продолжаются)"
    echo "  6) Выполнить все шаги по порядку"
    echo "  7) Выход"
    echo
    read -p "Ваш выбор (1-7): " CHOICE
    
    case $CHOICE in
        1)
            stop_hung_builds
            ;;
        2)
            if [ "$EUID" -ne 0 ]; then
                print_error "Требуются права root для изменения конфигурации Docker"
                print_info "Запустите: sudo $0"
                exit 1
            fi
            optimize_docker
            ;;
        3)
            preload_base_image
            ;;
        4)
            build_with_optimizations
            ;;
        5)
            read -p "Это займет больше времени. Продолжить? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                build_without_cache
            fi
            ;;
        6)
            stop_hung_builds
            if [ "$EUID" -eq 0 ]; then
                optimize_docker
            else
                print_warning "Пропуск оптимизации Docker (требуются права root)"
            fi
            preload_base_image
            sleep 2
            build_with_optimizations
            ;;
        7)
            exit 0
            ;;
        *)
            print_error "Неверный выбор"
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'print_warning "Прерывание скрипта"; exit 1' INT TERM

# Запуск
main
