#!/bin/bash

# Скрипт автоматической настройки Web Server Interceptor для Raspberry Pi 4
# Проверяет все зависимости и настраивает окружение

set -e

# Переход в корневую директорию проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Функции для красивого вывода
print_header() {
    echo -e "${PURPLE}"
    echo "🍓 =============================================="
    echo "   Web Server Interceptor - Raspberry Pi Setup"
    echo "   Автоматическая настройка для Raspberry Pi 4"
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

# Проверка архитектуры
check_architecture() {
    print_info "Проверка архитектуры системы..."
    
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
        print_warning "Обнаружена архитектура: $ARCH"
        print_warning "Этот скрипт оптимизирован для Raspberry Pi 4 (ARM64)"
        read -p "Продолжить установку? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Архитектура ARM64 обнаружена"
    fi
}

# Проверка операционной системы
check_os() {
    print_info "Проверка операционной системы..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_info "ОС: $NAME $VERSION"
        
        if [[ "$ID" != "raspbian" && "$ID" != "debian" ]]; then
            print_warning "Обнаружена ОС: $ID"
            print_warning "Рекомендуется Raspberry Pi OS (Debian-based)"
        fi
    else
        print_warning "Не удалось определить ОС"
    fi
}

# Проверка и установка Docker
check_docker() {
    print_info "Проверка Docker..."
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        print_success "Docker установлен: $DOCKER_VERSION"
    else
        print_warning "Docker не установлен"
        read -p "Установить Docker автоматически? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            print_info "Установка Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            rm get-docker.sh
            print_success "Docker установлен"
        else
            print_error "Docker необходим для работы приложения"
            exit 1
        fi
    fi
    
    # Проверка Docker Compose
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version)
        print_success "Docker Compose установлен: $COMPOSE_VERSION"
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version)
        print_success "Docker Compose установлен: $COMPOSE_VERSION"
        COMPOSE_CMD="docker-compose"
    else
        print_warning "Docker Compose не установлен"
        print_info "Установка Docker Compose..."
        sudo apt install -y docker-compose-plugin
        COMPOSE_CMD="docker compose"
        print_success "Docker Compose установлен"
    fi
}

# Проверка прав доступа к Docker
check_docker_permissions() {
    print_info "Проверка прав доступа к Docker..."
    
    if groups $USER | grep -q docker; then
        print_success "Пользователь $USER в группе docker"
    else
        print_warning "Пользователь $USER не в группе docker"
        print_info "Добавление пользователя в группу docker..."
        sudo usermod -aG docker $USER
        print_success "Пользователь добавлен в группу docker"
        print_warning "Необходимо перезайти в систему для применения изменений"
        print_info "Или выполните: newgrp docker"
    fi
}

# Проверка системных зависимостей
check_dependencies() {
    print_info "Проверка системных зависимостей..."
    
    local missing_deps=()
    
    command -v git &> /dev/null || missing_deps+=("git")
    command -v curl &> /dev/null || missing_deps+=("curl")
    command -v wget &> /dev/null || missing_deps+=("wget")
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_warning "Отсутствуют зависимости: ${missing_deps[*]}"
        print_info "Установка зависимостей..."
        sudo apt update
        sudo apt install -y "${missing_deps[@]}"
        print_success "Зависимости установлены"
    else
        print_success "Все зависимости установлены"
    fi
}

# Создание необходимых директорий
create_directories() {
    print_info "Создание необходимых директорий..."
    
    mkdir -p data reports logs
    mkdir -p docker/grafana/{dashboards,datasources} 2>/dev/null || true
    
    print_success "Директории созданы"
}

# Настройка прав доступа
setup_permissions() {
    print_info "Настройка прав доступа..."
    
    chmod +x *.sh 2>/dev/null || true
    chmod +x docker/entrypoint.sh 2>/dev/null || true
    
    # Права на директории данных
    chmod 755 data reports logs
    
    print_success "Права доступа настроены"
}

# Оптимизация для Raspberry Pi
optimize_raspberry() {
    print_info "Оптимизация для Raspberry Pi..."
    
    # Проверка swap
    SWAP_SIZE=$(free -m | grep Swap | awk '{print $2}')
    if [ "$SWAP_SIZE" -lt 1024 ]; then
        print_warning "Swap меньше 1GB (текущий: ${SWAP_SIZE}MB)"
        print_info "Рекомендуется увеличить swap для стабильной работы"
        read -p "Увеличить swap до 2GB? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Увеличение swap..."
            sudo dphys-swapfile swapoff
            sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
            sudo dphys-swapfile setup
            sudo dphys-swapfile swapon
            print_success "Swap увеличен до 2GB"
        fi
    else
        print_success "Swap достаточен: ${SWAP_SIZE}MB"
    fi
    
    # Проверка температуры
    if command -v vcgencmd &> /dev/null; then
        TEMP=$(vcgencmd measure_temp | cut -d= -f2)
        print_info "Температура CPU: $TEMP"
        if [[ $(echo "$TEMP" | cut -d. -f1) -gt 70 ]]; then
            print_warning "Высокая температура CPU! Рекомендуется охлаждение"
        fi
    fi
}

# Проверка файлов проекта
check_project_files() {
    print_info "Проверка файлов проекта..."
    
    local missing_files=()
    
    [ ! -f "$PROJECT_ROOT/Dockerfile.raspberry" ] && missing_files+=("Dockerfile.raspberry")
    [ ! -f "$PROJECT_ROOT/docker-compose.raspberry.yml" ] && missing_files+=("docker-compose.raspberry.yml")
    [ ! -f "$PROJECT_ROOT/requirements.txt" ] && missing_files+=("requirements.txt")
    [ ! -f "$PROJECT_ROOT/app.py" ] && missing_files+=("app.py")
    [ ! -f "$SCRIPT_DIR/raspberry-run.sh" ] && missing_files+=("raspberry-run.sh")
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        print_error "Отсутствуют необходимые файлы:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        print_error "Убедитесь, что вы находитесь в корневой директории проекта"
        exit 1
    fi
    
    print_success "Все файлы проекта найдены"
}

# Проверка сетевого подключения
check_network() {
    print_info "Проверка сетевого подключения..."
    
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Интернет подключение работает"
    else
        print_warning "Нет подключения к интернету"
        print_warning "Некоторые функции могут не работать"
    fi
    
    # Получение IP адреса
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    if [ -n "$IP_ADDRESS" ]; then
        print_info "IP адрес: $IP_ADDRESS"
    fi
}

# Финальная информация
show_final_info() {
    echo
    print_success "Настройка завершена!"
    echo
    print_info "Следующие шаги:"
    echo "  1. Если вы были добавлены в группу docker, перезайдите в систему"
    echo "  2. Запустите приложение: ./raspberry-run.sh start"
    echo "  3. Откройте в браузере: http://$IP_ADDRESS:5000"
    echo
    print_info "Полезные команды:"
    echo "  ./raspberry-run.sh start      - Запуск сервисов"
    echo "  ./raspberry-run.sh status     - Статус сервисов"
    echo "  ./raspberry-run.sh logs       - Просмотр логов"
    echo "  ./raspberry-run.sh onion      - Получить .onion адрес"
    echo
    print_info "Документация:"
    echo "  См. RASPBERRY_PI_SETUP.md для подробной информации"
    echo
}

# Основная функция
main() {
    print_header
    
    # Проверки
    check_architecture
    check_os
    check_dependencies
    check_docker
    check_docker_permissions
    check_project_files
    check_network
    
    # Настройка
    create_directories
    setup_permissions
    optimize_raspberry
    
    # Финальная информация
    show_final_info
}

# Обработка сигналов
trap 'print_warning "Прерывание скрипта"; exit 1' INT TERM

# Запуск
main "$@"

